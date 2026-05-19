import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:frontend/core/model/pothole.dart';
import 'package:frontend/core/provider/gps_provider.dart';
import 'package:frontend/core/provider/pothole_provider.dart';
import 'package:frontend/core/services/route_service.dart';
import 'package:frontend/core/themes/car_theme.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

class MapDetailPage extends StatefulWidget {
  const MapDetailPage({super.key});

  @override
  State<MapDetailPage> createState() => _MapDetailPageState();
}

class _MapDetailPageState extends State<MapDetailPage> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  final RouteService _routeService = RouteService();

  double _zoom = 18;
  bool _followCar = true;
  bool _alertsEnabled = true;
  bool _trafficLayer = true;
  bool _mapReady = false;
  bool _isSearching = false;
  bool _isRouting = false;
  LatLng? _smoothCarPosition;
  LatLng? _lastCameraPosition;
  LatLng? _destinationPosition;
  String? _destinationName;
  String? _routeError;
  double _currentHeading = 0;
  double _smoothHeading = 0;
  double _smoothMapRotation = 0;
  double _routeDistanceKm = 0;
  List<LatLng> _routePoints = [];
  List<_PlaceSearchResult> _searchResults = [];
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();

    Future.microtask(() {
      if (mounted) {
        context.read<PotholeProvider>().loadPotholes();
      }
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  double _distanceKm(LatLng a, LatLng b) {
    const p = 0.017453292519943295;
    final lat1 = a.latitude;
    final lon1 = a.longitude;
    final lat2 = b.latitude;
    final lon2 = b.longitude;

    final value =
        0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;

    return 12742 * asin(sqrt(value));
  }

  double _angleLerp(double from, double to, double t) {
    final diff = (to - from + 540) % 360 - 180;
    return (from + diff * t + 360) % 360;
  }

  LatLng _lerpLatLng(LatLng from, LatLng to, double t) {
    return LatLng(
      from.latitude + (to.latitude - from.latitude) * t,
      from.longitude + (to.longitude - from.longitude) * t,
    );
  }

  void _updateCamera(LatLng position) {
    if (!_mapReady || !_followCar) return;

    _lastCameraPosition ??= position;

    final next = _lerpLatLng(_lastCameraPosition!, position, 0.22);
    _lastCameraPosition = next;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      _mapController.move(next, _zoom, offset: Offset(170.w, 0));
      _mapController.rotate(-_smoothMapRotation);
    });
  }

  void _zoomIn(LatLng position) {
    setState(() {
      _zoom = (_zoom + 1).clamp(5.0, 23.0);
    });
    _mapController.move(position, _zoom);
  }

  void _zoomOut(LatLng position) {
    setState(() {
      _zoom = (_zoom - 1).clamp(5.0, 23.0);
    });
    _mapController.move(position, _zoom);
  }

  List<Pothole> _activeHazards(List<Pothole> potholes) {
    return potholes.where((p) => p.category != "normal").toList()
      ..sort((a, b) => b.severity.compareTo(a.severity));
  }

  Pothole? _nearestHazard(LatLng position, List<Pothole> hazards) {
    if (hazards.isEmpty) return null;

    Pothole? nearest;
    double? nearestDistance;

    for (final hazard in hazards) {
      final distance = _distanceKm(position, LatLng(hazard.lat, hazard.lng));

      if (nearestDistance == null || distance < nearestDistance) {
        nearest = hazard;
        nearestDistance = distance;
      }
    }

    return nearest;
  }

  double _routeLengthKm(List<LatLng> points) {
    if (points.length < 2) return 0;

    double total = 0;
    for (var i = 1; i < points.length; i++) {
      total += _distanceKm(points[i - 1], points[i]);
    }

    return total;
  }

  Future<void> _searchPlaces(String query) async {
    final trimmed = query.trim();

    if (trimmed.length < 3) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _routeError = null;
    });

    try {
      final uri = Uri.https("nominatim.openstreetmap.org", "/search", {
        "format": "jsonv2",
        "q": trimmed,
        "limit": "5",
        "countrycodes": "id",
      });

      final response = await http
          .get(
            uri,
            headers: const {
              "User-Agent": "com.pothole.navigation.app",
              "Accept": "application/json",
            },
          )
          .timeout(const Duration(seconds: 8));

      if (!mounted) return;

      if (response.statusCode != 200) {
        throw Exception("Search failed");
      }

      final decoded = jsonDecode(response.body) as List;
      final results =
          decoded
              .map((item) {
                final json = item as Map<String, dynamic>;
                return _PlaceSearchResult.fromJson(json);
              })
              .where((item) => item.name.isNotEmpty)
              .toList();

      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _searchResults = [];
        _isSearching = false;
        _routeError = "Destination search unavailable";
      });
    }
  }

  void _onSearchChanged(String value) {
    setState(() {
      _routeError = null;
    });

    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 450), () {
      _searchPlaces(value);
    });
  }

  Future<void> _selectDestination(
    _PlaceSearchResult result,
    LatLng start,
  ) async {
    FocusScope.of(context).unfocus();

    setState(() {
      _isRouting = true;
      _followCar = false;
      _destinationPosition = result.position;
      _destinationName = result.name;
      _searchResults = [];
      _routePoints = [];
      _routeDistanceKm = 0;
      _routeError = null;
      _searchController.text = result.name;
    });

    try {
      final route = await _routeService
          .getRoute(start, result.position)
          .timeout(const Duration(seconds: 12));

      if (!mounted) return;

      setState(() {
        _routePoints = route;
        _routeDistanceKm = _routeLengthKm(route);
        _isRouting = false;
      });

      _mapController.move(result.position, 15);
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isRouting = false;
        _routeError = "Route could not be loaded";
      });

      _mapController.move(result.position, 15);
    }
  }

  void _clearDestination() {
    setState(() {
      _destinationPosition = null;
      _destinationName = null;
      _searchResults = [];
      _routePoints = [];
      _routeDistanceKm = 0;
      _routeError = null;
      _searchController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<GPSProvider, PotholeProvider>(
      builder: (context, gps, potholeProvider, _) {
        final hasGps = gps.current != null;
        final rawPosition =
            hasGps
                ? LatLng(gps.current!.lat, gps.current!.lng)
                : const LatLng(-6.3, 107.2);

        if (hasGps) {
          _currentHeading = gps.current!.heading;
          _smoothHeading = _angleLerp(_smoothHeading, _currentHeading, 0.16);
          _smoothMapRotation = _angleLerp(
            _smoothMapRotation,
            _currentHeading,
            0.11,
          );
          _smoothCarPosition =
              _smoothCarPosition == null
                  ? rawPosition
                  : _lerpLatLng(_smoothCarPosition!, rawPosition, 0.22);
          _updateCamera(_smoothCarPosition!);
        }

        final position = _smoothCarPosition ?? rawPosition;
        final hazards = _activeHazards(potholeProvider.potholes);
        final nearestHazard = _nearestHazard(position, hazards);

        return ValueListenableBuilder(
          valueListenable: CarThemes.currentTheme,
          builder: (context, themeType, _) {
            final theme = CarThemes.getTheme(themeType);
            final accent = getMusicAccentColor(themeType, theme);

            return Scaffold(
              backgroundColor: Colors.black,
              body: Stack(
                children: [
                  Positioned.fill(
                    child: FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: position,
                        initialZoom: _zoom,
                        onMapReady: () {
                          _mapReady = true;
                          _updateCamera(position);
                        },
                        onPositionChanged: (_, hasGesture) {
                          if (hasGesture && _followCar) {
                            setState(() {
                              _followCar = false;
                            });
                          }
                        },
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                          userAgentPackageName: "com.pothole.navigation.app",
                          maxZoom: 25,
                        ),
                        if (_trafficLayer)
                          CircleLayer(
                            circles:
                                hazards.map((hazard) {
                                  final isPothole =
                                      hazard.category == "pothole";

                                  return CircleMarker(
                                    point: LatLng(hazard.lat, hazard.lng),
                                    radius: isPothole ? 58 : 42,
                                    useRadiusInMeter: true,
                                    color: (isPothole
                                            ? Colors.red
                                            : Colors.amber)
                                        .withValues(alpha: 0.18),
                                    borderStrokeWidth: 2,
                                    borderColor: (isPothole
                                            ? Colors.red
                                            : Colors.amber)
                                        .withValues(alpha: 0.5),
                                  );
                                }).toList(),
                          ),
                        if (_routePoints.isNotEmpty)
                          PolylineLayer(
                            polylines: [
                              Polyline(
                                points: _routePoints,
                                strokeWidth: 7.w,
                                color: accent.withValues(alpha: 0.28),
                              ),
                              Polyline(
                                points: _routePoints,
                                strokeWidth: 4.w,
                                color: accent,
                              ),
                            ],
                          ),
                        MarkerLayer(
                          markers: [
                            if (hasGps)
                              Marker(
                                point: position,
                                width: 76.w,
                                height: 76.w,
                                child: Transform.rotate(
                                  angle: _smoothHeading * pi / 180,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.black.withValues(
                                        alpha: 0.62,
                                      ),
                                      border: Border.all(
                                        color: accent,
                                        width: 2.4,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: accent.withValues(alpha: 0.35),
                                          blurRadius: 24,
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      Icons.navigation,
                                      color: accent,
                                      size: 42.sp,
                                    ),
                                  ),
                                ),
                              ),
                            if (_destinationPosition != null)
                              Marker(
                                point: _destinationPosition!,
                                width: 86.w,
                                height: 86.w,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 44.w,
                                      height: 44.w,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.black.withValues(
                                          alpha: 0.78,
                                        ),
                                        border: Border.all(
                                          color: Colors.greenAccent,
                                          width: 2,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.greenAccent
                                                .withValues(alpha: 0.28),
                                            blurRadius: 18,
                                          ),
                                        ],
                                      ),
                                      child: Icon(
                                        Icons.flag,
                                        color: Colors.greenAccent,
                                        size: 24.sp,
                                      ),
                                    ),
                                    SizedBox(height: 5.h),
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 7.w,
                                        vertical: 3.h,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(
                                          alpha: 0.72,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          6.r,
                                        ),
                                      ),
                                      child: Text(
                                        "DEST",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 9.sp,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ...hazards.map((hazard) {
                              final isPothole = hazard.category == "pothole";
                              final color =
                                  isPothole
                                      ? Colors.redAccent
                                      : Colors.amberAccent;
                              final icon =
                                  isPothole
                                      ? Icons.report_problem
                                      : Icons.speed;

                              return Marker(
                                point: LatLng(hazard.lat, hazard.lng),
                                width: 92.w,
                                height: 80.h,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 42.w,
                                      height: 42.w,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.black.withValues(
                                          alpha: 0.78,
                                        ),
                                        border: Border.all(
                                          color: color,
                                          width: 2,
                                        ),
                                      ),
                                      child: Icon(
                                        icon,
                                        color: color,
                                        size: 22.sp,
                                      ),
                                    ),
                                    SizedBox(height: 5.h),
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 7.w,
                                        vertical: 3.h,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(
                                          alpha: 0.72,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          6.r,
                                        ),
                                      ),
                                      child: Text(
                                        hazard.category.toUpperCase(),
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 9.sp,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              Colors.black.withValues(alpha: 0.72),
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.42),
                            ],
                            stops: const [0, 0.46, 1],
                          ),
                        ),
                      ),
                    ),
                  ),
                  SafeArea(
                    child: Padding(
                      padding: EdgeInsets.all(22.w),
                      child: Column(
                        children: [
                          _TopCommandBar(
                            accent: accent,
                            hasGps: hasGps,
                            onBack: () => Navigator.pop(context),
                          ),
                          SizedBox(height: 12.h),
                          _DestinationSearchBar(
                            accent: accent,
                            controller: _searchController,
                            results: _searchResults,
                            isSearching: _isSearching,
                            isRouting: _isRouting,
                            routeError: _routeError,
                            destinationName: _destinationName,
                            routeDistanceKm: _routeDistanceKm,
                            onChanged: _onSearchChanged,
                            onClear: _clearDestination,
                            onSelected: (result) {
                              _selectDestination(result, position);
                            },
                          ),
                          SizedBox(height: 12.h),
                          Expanded(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _RoutePanel(
                                  accent: accent,
                                  hasGps: hasGps,
                                  speed: gps.current?.speed ?? 0,
                                  heading: _currentHeading,
                                  nearestHazard: nearestHazard,
                                  nearestDistance:
                                      nearestHazard == null
                                          ? null
                                          : _distanceKm(
                                            position,
                                            LatLng(
                                              nearestHazard.lat,
                                              nearestHazard.lng,
                                            ),
                                          ),
                                  destinationName: _destinationName,
                                  routeDistanceKm: _routeDistanceKm,
                                  isRouting: _isRouting,
                                ),
                                const Spacer(),
                                _HazardPanel(
                                  accent: accent,
                                  hazards: hazards,
                                  position: position,
                                  distanceBuilder:
                                      (hazard) => _distanceKm(
                                        position,
                                        LatLng(hazard.lat, hazard.lng),
                                      ),
                                  alertsEnabled: _alertsEnabled,
                                  trafficLayer: _trafficLayer,
                                  followCar: _followCar,
                                  onAlertToggle: () {
                                    setState(() {
                                      _alertsEnabled = !_alertsEnabled;
                                    });
                                  },
                                  onTrafficToggle: () {
                                    setState(() {
                                      _trafficLayer = !_trafficLayer;
                                    });
                                  },
                                  onFollow: () {
                                    setState(() {
                                      _followCar = true;
                                    });
                                    _updateCamera(position);
                                  },
                                  onZoomIn: () => _zoomIn(position),
                                  onZoomOut: () => _zoomOut(position),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 16.h),
                          _TelemetryStrip(
                            accent: accent,
                            zoom: _zoom,
                            hazardCount: hazards.length,
                            alertsEnabled: _alertsEnabled,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _TopCommandBar extends StatelessWidget {
  const _TopCommandBar({
    required this.accent,
    required this.hasGps,
    required this.onBack,
  });

  final Color accent;
  final bool hasGps;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64.h,
      padding: EdgeInsets.symmetric(horizontal: 14.w),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.64),
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          _IconAction(
            icon: Icons.arrow_back,
            accent: accent,
            tooltip: "Back",
            onTap: onBack,
          ),
          SizedBox(width: 16.w),
          Icon(Icons.map, color: accent, size: 26.sp),
          SizedBox(width: 10.w),
          Text(
            "Smart Navigation",
            style: TextStyle(
              color: Colors.white,
              fontSize: 20.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(width: 12.w),
          Container(
            width: 8.w,
            height: 8.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: hasGps ? Colors.greenAccent : Colors.orangeAccent,
            ),
          ),
          SizedBox(width: 7.w),
          Text(
            hasGps ? "GPS locked" : "Searching GPS",
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          _ChipStatus(
            icon: Icons.route,
            label: "Adaptive route",
            accent: accent,
          ),
          SizedBox(width: 10.w),
          _ChipStatus(icon: Icons.shield, label: "Road guard", accent: accent),
        ],
      ),
    );
  }
}

class _DestinationSearchBar extends StatelessWidget {
  const _DestinationSearchBar({
    required this.accent,
    required this.controller,
    required this.results,
    required this.isSearching,
    required this.isRouting,
    required this.routeError,
    required this.destinationName,
    required this.routeDistanceKm,
    required this.onChanged,
    required this.onClear,
    required this.onSelected,
  });

  final Color accent;
  final TextEditingController controller;
  final List<_PlaceSearchResult> results;
  final bool isSearching;
  final bool isRouting;
  final String? routeError;
  final String? destinationName;
  final double routeDistanceKm;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final ValueChanged<_PlaceSearchResult> onSelected;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: SizedBox(
        width: 310.w,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 52.h,
              padding: EdgeInsets.symmetric(horizontal: 12.w),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.68),
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(color: accent.withValues(alpha: 0.28)),
              ),
              child: Row(
                children: [
                  Icon(Icons.search, color: accent, size: 21.sp),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      onChanged: onChanged,
                      textInputAction: TextInputAction.search,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w700,
                      ),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: "Search destination",
                        hintStyle: TextStyle(
                          color: Colors.white38,
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  if (isSearching || isRouting)
                    SizedBox(
                      width: 20.w,
                      height: 20.w,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        valueColor: AlwaysStoppedAnimation<Color>(accent),
                      ),
                    )
                  else if (controller.text.isNotEmpty)
                    InkWell(
                      borderRadius: BorderRadius.circular(12.r),
                      onTap: onClear,
                      child: SizedBox(
                        width: 34.w,
                        height: 34.w,
                        child: Icon(
                          Icons.close,
                          color: Colors.white70,
                          size: 20.sp,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (results.isNotEmpty ||
                routeError != null ||
                destinationName != null)
              SizedBox(height: 8.h),
            if (results.isNotEmpty)
              Container(
                constraints: BoxConstraints(maxHeight: 142.h),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.78),
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.symmetric(vertical: 8.h),
                  itemBuilder: (context, index) {
                    final result = results[index];

                    return InkWell(
                      onTap: () => onSelected(result),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12.w,
                          vertical: 8.h,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 30.w,
                              height: 30.w,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: accent.withValues(alpha: 0.14),
                              ),
                              child: Icon(
                                Icons.place,
                                color: accent,
                                size: 18.sp,
                              ),
                            ),
                            SizedBox(width: 10.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    result.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 13.sp,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  SizedBox(height: 2.h),
                                  Text(
                                    result.address,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.white54,
                                      fontSize: 10.sp,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  separatorBuilder:
                      (_, __) => Divider(
                        height: 1,
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                  itemCount: results.length,
                ),
              )
            else if (routeError != null)
              _SearchStatusCard(
                accent: Colors.orangeAccent,
                icon: Icons.info_outline,
                text: routeError!,
              )
            else if (destinationName != null)
              _SearchStatusCard(
                accent: Colors.greenAccent,
                icon: Icons.flag,
                text:
                    routeDistanceKm > 0
                        ? "$destinationName - ${routeDistanceKm.toStringAsFixed(1)} km"
                        : destinationName!,
              ),
          ],
        ),
      ),
    );
  }
}

class _SearchStatusCard extends StatelessWidget {
  const _SearchStatusCard({
    required this.accent,
    required this.icon,
    required this.text,
  });

  final Color accent;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Icon(icon, color: accent, size: 18.sp),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoutePanel extends StatelessWidget {
  const _RoutePanel({
    required this.accent,
    required this.hasGps,
    required this.speed,
    required this.heading,
    required this.nearestHazard,
    required this.nearestDistance,
    required this.destinationName,
    required this.routeDistanceKm,
    required this.isRouting,
  });

  final Color accent;
  final bool hasGps;
  final double speed;
  final double heading;
  final Pothole? nearestHazard;
  final double? nearestDistance;
  final String? destinationName;
  final double routeDistanceKm;
  final bool isRouting;

  @override
  Widget build(BuildContext context) {
    final hazardTitle =
        nearestHazard == null
            ? "Clear road"
            : nearestHazard!.category == "pothole"
            ? "Pothole ahead"
            : "Speed bump ahead";
    final hazardDistance =
        nearestDistance == null
            ? "No hazard nearby"
            : "${(nearestDistance! * 1000).round()} m";

    return Container(
      width: 310.w,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: accent.withValues(alpha: 0.32)),
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Destination",
              style: TextStyle(
                color: Colors.white54,
                fontSize: 11.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              destinationName ?? "Search a destination",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: 19.sp,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 5.h),
            Text(
              isRouting
                  ? "Calculating route..."
                  : routeDistanceKm > 0
                  ? "${routeDistanceKm.toStringAsFixed(1)} km route loaded"
                  : "Ready for navigation",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white54,
                fontSize: 11.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 14.h),
            Row(
              children: [
                Expanded(
                  child: _MetricTile(
                    label: "Speed",
                    value: speed.toStringAsFixed(0),
                    unit: "km/h",
                    accent: accent,
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: _MetricTile(
                    label: "Heading",
                    value: heading.toStringAsFixed(0),
                    unit: "deg",
                    accent: accent,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            Container(
              padding: EdgeInsets.all(13.w),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(15.r),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40.w,
                    height: 40.w,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accent.withValues(alpha: 0.14),
                    ),
                    child: Icon(
                      nearestHazard == null
                          ? Icons.check_circle
                          : Icons.warning_rounded,
                      color:
                          nearestHazard == null ? Colors.greenAccent : accent,
                      size: 23.sp,
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hazardTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 3.h),
                        Text(
                          hazardDistance,
                          style: TextStyle(
                            color: Colors.white60,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 13.h),
            _RouteStep(
              accent: accent,
              icon: Icons.straight,
              title: "Continue ahead",
              subtitle: hasGps ? "Keep current lane" : "Waiting for GPS fix",
              active: true,
            ),
            _RouteStep(
              accent: accent,
              icon: Icons.turn_right,
              title: "Next maneuver",
              subtitle: "Route guidance standby",
              active: false,
            ),
            SizedBox(height: 6.h),
            Text(
              "Navigation surface",
              style: TextStyle(
                color: Colors.white38,
                fontSize: 10.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 7.h),
            LinearProgressIndicator(
              value: hasGps ? 0.82 : 0.28,
              minHeight: 5.h,
              borderRadius: BorderRadius.circular(10.r),
              backgroundColor: Colors.white.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(accent),
            ),
          ],
        ),
      ),
    );
  }
}

class _HazardPanel extends StatelessWidget {
  const _HazardPanel({
    required this.accent,
    required this.hazards,
    required this.position,
    required this.distanceBuilder,
    required this.alertsEnabled,
    required this.trafficLayer,
    required this.followCar,
    required this.onAlertToggle,
    required this.onTrafficToggle,
    required this.onFollow,
    required this.onZoomIn,
    required this.onZoomOut,
  });

  final Color accent;
  final List<Pothole> hazards;
  final LatLng position;
  final double Function(Pothole hazard) distanceBuilder;
  final bool alertsEnabled;
  final bool trafficLayer;
  final bool followCar;
  final VoidCallback onAlertToggle;
  final VoidCallback onTrafficToggle;
  final VoidCallback onFollow;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  @override
  Widget build(BuildContext context) {
    final closest = hazards.take(4).toList();

    return SizedBox(
      width: 282.w,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: EdgeInsets.all(14.w),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.66),
              borderRadius: BorderRadius.circular(18.r),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _IconAction(
                  icon:
                      followCar ? Icons.my_location : Icons.location_searching,
                  accent: followCar ? Colors.greenAccent : accent,
                  tooltip: "Follow vehicle",
                  onTap: onFollow,
                ),
                _IconAction(
                  icon:
                      alertsEnabled
                          ? Icons.notifications_active
                          : Icons.notifications_off,
                  accent: alertsEnabled ? Colors.greenAccent : Colors.redAccent,
                  tooltip: "Toggle alerts",
                  onTap: onAlertToggle,
                ),
                _IconAction(
                  icon: trafficLayer ? Icons.layers : Icons.layers_clear,
                  accent: trafficLayer ? accent : Colors.white54,
                  tooltip: "Toggle hazard layer",
                  onTap: onTrafficToggle,
                ),
                _IconAction(
                  icon: Icons.add,
                  accent: accent,
                  tooltip: "Zoom in",
                  onTap: onZoomIn,
                ),
                _IconAction(
                  icon: Icons.remove,
                  accent: accent,
                  tooltip: "Zoom out",
                  onTap: onZoomOut,
                ),
              ],
            ),
          ),
          SizedBox(height: 14.h),
          Expanded(
            child: Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.66),
                borderRadius: BorderRadius.circular(18.r),
                border: Border.all(color: accent.withValues(alpha: 0.24)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: accent,
                        size: 22.sp,
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        "Road Alerts",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        hazards.length.toString(),
                        style: TextStyle(
                          color: accent,
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12.h),
                  if (closest.isEmpty)
                    Expanded(
                      child: Center(
                        child: Text(
                          "No active hazard",
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.separated(
                        physics: const BouncingScrollPhysics(),
                        itemBuilder: (context, index) {
                          final hazard = closest[index];
                          final isPothole = hazard.category == "pothole";
                          final color =
                              isPothole ? Colors.redAccent : Colors.amberAccent;

                          return _HazardTile(
                            color: color,
                            category: hazard.category,
                            severity: hazard.severity,
                            distance: distanceBuilder(hazard),
                          );
                        },
                        separatorBuilder: (_, __) => SizedBox(height: 10.h),
                        itemCount: closest.length,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TelemetryStrip extends StatelessWidget {
  const _TelemetryStrip({
    required this.accent,
    required this.zoom,
    required this.hazardCount,
    required this.alertsEnabled,
  });

  final Color accent;
  final double zoom;
  final int hazardCount;
  final bool alertsEnabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64.h,
      padding: EdgeInsets.symmetric(horizontal: 18.w),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.64),
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          _StripMetric(label: "Mode", value: "Drive", accent: accent),
          _DividerLine(),
          _StripMetric(
            label: "Map Zoom",
            value: zoom.toStringAsFixed(0),
            accent: accent,
          ),
          _DividerLine(),
          _StripMetric(
            label: "Hazards",
            value: hazardCount.toString(),
            accent: accent,
          ),
          _DividerLine(),
          _StripMetric(
            label: "Alerts",
            value: alertsEnabled ? "Armed" : "Muted",
            accent: alertsEnabled ? Colors.greenAccent : Colors.redAccent,
          ),
          const Spacer(),
          Icon(Icons.explore, color: accent, size: 22.sp),
          SizedBox(width: 8.w),
          Text(
            "Toyota In Car Connectivity",
            style: TextStyle(
              color: Colors.white54,
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.unit,
    required this.accent,
  });

  final String label;
  final String value;
  final String unit;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white54,
              fontSize: 11.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 7.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: accent,
                  fontSize: 24.sp,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(width: 4.w),
              Padding(
                padding: EdgeInsets.only(bottom: 4.h),
                child: Text(
                  unit,
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RouteStep extends StatelessWidget {
  const _RouteStep({
    required this.accent,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.active,
  });

  final Color accent;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Row(
        children: [
          Container(
            width: 40.w,
            height: 40.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active ? accent.withValues(alpha: 0.16) : Colors.white10,
            ),
            child: Icon(
              icon,
              color: active ? accent : Colors.white54,
              size: 21.sp,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 3.h),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HazardTile extends StatelessWidget {
  const _HazardTile({
    required this.color,
    required this.category,
    required this.severity,
    required this.distance,
  });

  final Color color;
  final String category;
  final double severity;
  final double distance;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Row(
        children: [
          Icon(
            category == "pothole" ? Icons.report_problem : Icons.speed,
            color: color,
            size: 22.sp,
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 3.h),
                Text(
                  "Severity ${severity.toStringAsFixed(1)}",
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Text(
            "${(distance * 1000).round()} m",
            style: TextStyle(
              color: color,
              fontSize: 12.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.icon,
    required this.accent,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final Color accent;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(12.r),
        onTap: onTap,
        child: Container(
          width: 42.w,
          height: 42.w,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: accent.withValues(alpha: 0.34)),
          ),
          child: Icon(icon, color: accent, size: 21.sp),
        ),
      ),
    );
  }
}

class _ChipStatus extends StatelessWidget {
  const _ChipStatus({
    required this.icon,
    required this.label,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18.r),
      ),
      child: Row(
        children: [
          Icon(icon, color: accent, size: 16.sp),
          SizedBox(width: 6.w),
          Text(
            label,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _StripMetric extends StatelessWidget {
  const _StripMetric({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white38,
            fontSize: 11.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(width: 7.w),
        Text(
          value,
          style: TextStyle(
            color: accent,
            fontSize: 13.sp,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _DividerLine extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 22.h,
      margin: EdgeInsets.symmetric(horizontal: 18.w),
      color: Colors.white.withValues(alpha: 0.14),
    );
  }
}

class _PlaceSearchResult {
  const _PlaceSearchResult({
    required this.name,
    required this.address,
    required this.position,
  });

  final String name;
  final String address;
  final LatLng position;

  factory _PlaceSearchResult.fromJson(Map<String, dynamic> json) {
    final displayName = (json["display_name"] ?? "").toString();
    final parts = displayName.split(",").map((part) => part.trim()).toList();
    final name = (json["name"] ?? "").toString().trim();

    return _PlaceSearchResult(
      name: name.isNotEmpty ? name : (parts.isNotEmpty ? parts.first : ""),
      address: displayName,
      position: LatLng(
        double.tryParse((json["lat"] ?? "0").toString()) ?? 0,
        double.tryParse((json["lon"] ?? "0").toString()) ?? 0,
      ),
    );
  }
}
