import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:frontend/core/localization/app_strings.dart';
import 'package:frontend/core/model/pothole.dart';
import 'package:frontend/core/navigation/app_language_control.dart';
import 'package:frontend/core/provider/gps_provider.dart';
import 'package:frontend/core/provider/pothole_provider.dart';
import 'package:frontend/core/services/route_service.dart';
import 'package:frontend/core/services/map_tile_config.dart';
import 'package:frontend/core/themes/car_theme.dart';
import 'package:frontend/core/utils/pothole_detection_engine.dart';
import 'package:frontend/core/utils/map_navigation_engine.dart';
import 'package:frontend/core/widgets/in_app_keyboard.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class MapDetailPage extends StatefulWidget {
  const MapDetailPage({super.key});

  @override
  State<MapDetailPage> createState() => _MapDetailPageState();
}

class _MapDetailPageState extends State<MapDetailPage> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  final RouteService _routeService = RouteService();
  PotholeProvider? _potholeProvider;

  Pothole? _hazardAhead;
  double? _hazardAheadDistanceKm;
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
  String _navTitle = AppStrings.readyForNavigation;
  String _navSubtitle = AppStrings.searchDestinationToStart;
  double _remainingDistanceKm = 0;
  double _currentHeading = 0;
  double _smoothHeading = 0;
  double _smoothMapRotation = 0;
  double _routeDistanceKm = 0;
  List<LatLng> _routePoints = [];
  List<_PlaceSearchResult> _searchResults = [];
  Timer? _searchDebounce;
  IconData _navIcon = Icons.navigation;

  @override
  void initState() {
    super.initState();
    AppLanguageControl.languageCode.addListener(_onLanguageChanged);

    Future.microtask(() {
      if (mounted) {
        final potholeProvider = context.read<PotholeProvider>();
        _potholeProvider = potholeProvider;
        potholeProvider.bindGps(context.read<GPSProvider>());
        potholeProvider.attachRealtime();
      }
    });
  }

  @override
  void dispose() {
    AppLanguageControl.languageCode.removeListener(_onLanguageChanged);
    _searchDebounce?.cancel();
    _searchController.dispose();
    _potholeProvider?.detachRealtime();
    super.dispose();
  }

  void _onLanguageChanged() {
    if (!mounted) return;

    setState(() {
      if (_destinationPosition == null || _routePoints.length < 2) {
        _navTitle = AppStrings.readyForNavigation;
        _navSubtitle = AppStrings.searchDestinationToStart;
      } else if (_routeError != null) {
        _navTitle = AppStrings.routeUnavailable;
        _navSubtitle = AppStrings.pleaseTryAnotherDestination;
      }
    });
  }

  double _distanceKm(LatLng a, LatLng b) {
    return MapNavigationEngine.distanceKm(a, b);
  }

  double _angleLerp(double from, double to, double t) {
    return MapNavigationEngine.angleLerp(from, to, t);
  }

  LatLng _lerpLatLng(LatLng from, LatLng to, double t) {
    return MapNavigationEngine.lerpLatLng(from, to, t);
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
      _zoom = (_zoom + 1).clamp(5.0, MapTileConfig.maxZoom);
    });
    _mapController.move(position, _zoom);
  }

  void _zoomOut(LatLng position) {
    setState(() {
      _zoom = (_zoom - 1).clamp(5.0, MapTileConfig.maxZoom);
    });
    _mapController.move(position, _zoom);
  }

  double _routeLengthKm(List<LatLng> points) {
    return MapNavigationEngine.routeLengthKm(points);
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
      final results = decoded
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
        _routeError = AppStrings.destinationSearchUnavailable;
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
      _remainingDistanceKm = 0;
      _routeError = null;
      _navTitle = AppStrings.calculatingRoute;
      _navSubtitle = AppStrings.preparingNavigation;
      _navIcon = Icons.route;
      _searchController.text = result.name;
    });

    try {
      final route = await _routeService
          .getRoute(start, result.position)
          .timeout(const Duration(seconds: 12));

      if (!mounted) return;

      final distance = _routeLengthKm(route);

      setState(() {
        _routePoints = route;
        _routeDistanceKm = distance;
        _remainingDistanceKm = distance;
        _isRouting = false;
        _followCar = true;

        _navTitle = AppStrings.continueStraight;
        _navSubtitle = AppStrings.kmRemaining(distance);
        _navIcon = Icons.straight;
      });

      _updateNavigationInstruction(start);
      _updateCamera(start);
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isRouting = false;
        _routeError = AppStrings.routeCouldNotBeLoaded;
        _followCar = true;

        _navTitle = AppStrings.routeUnavailable;
        _navSubtitle = AppStrings.pleaseTryAnotherDestination;
        _navIcon = Icons.info_outline;
      });

      _updateCamera(start);
    }
  }

  int _nearestRouteIndex(LatLng current, List<LatLng> route) {
    return MapNavigationEngine.nearestRouteIndex(current, route);
  }

  double _bearingBetween(LatLng from, LatLng to) {
    return MapNavigationEngine.bearingBetween(from, to);
  }

  void _updateNavigationInstruction(LatLng current) {
    if (_destinationPosition == null || _routePoints.length < 2) {
      _navTitle = AppStrings.readyForNavigation;
      _navSubtitle = AppStrings.searchDestinationToStart;
      _navIcon = Icons.navigation;
      _remainingDistanceKm = 0;
      return;
    }

    final nearestIndex = _nearestRouteIndex(current, _routePoints);

    if (nearestIndex >= _routePoints.length - 2) {
      final distanceToDestination = _distanceKm(current, _routePoints.last);

      _remainingDistanceKm = distanceToDestination;

      if (distanceToDestination < 0.01) {
        _navTitle = AppStrings.destinationReached;
        _navSubtitle = AppStrings.youHaveArrived;
        _navIcon = Icons.flag;
      } else {
        _navTitle = AppStrings.arrivingSoon;
        _navSubtitle = AppStrings.metersRemaining(
          (distanceToDestination * 1000).round(),
        );
        _navIcon = Icons.flag;
      }

      return;
    }

    final nextIndex = (nearestIndex + 8).clamp(0, _routePoints.length - 1);
    final nextPoint = _routePoints[nextIndex];

    final routeBearing = _bearingBetween(current, nextPoint);
    final diff = ((routeBearing - _currentHeading + 540) % 360) - 180;

    double remaining = 0;
    for (int i = nearestIndex + 1; i < _routePoints.length; i++) {
      remaining += _distanceKm(_routePoints[i - 1], _routePoints[i]);
    }

    _remainingDistanceKm = remaining;

    if (diff.abs() < 25) {
      _navTitle = AppStrings.continueStraight;
      _navSubtitle = AppStrings.kmRemaining(remaining);
      _navIcon = Icons.straight;
    } else if (diff >= 25 && diff < 70) {
      _navTitle = AppStrings.slightRightAhead;
      _navSubtitle = AppStrings.kmRemaining(remaining);
      _navIcon = Icons.turn_slight_right;
    } else if (diff <= -25 && diff > -70) {
      _navTitle = AppStrings.slightLeftAhead;
      _navSubtitle = AppStrings.kmRemaining(remaining);
      _navIcon = Icons.turn_slight_left;
    } else if (diff >= 70 && diff < 140) {
      _navTitle = AppStrings.turnRightAhead;
      _navSubtitle = AppStrings.kmRemaining(remaining);
      _navIcon = Icons.turn_right;
    } else if (diff <= -70 && diff > -140) {
      _navTitle = AppStrings.turnLeftAhead;
      _navSubtitle = AppStrings.kmRemaining(remaining);
      _navIcon = Icons.turn_left;
    } else {
      _navTitle = AppStrings.makeUTurn;
      _navSubtitle = AppStrings.realignToRoute;
      _navIcon = Icons.u_turn_left;
    }
  }

  void _clearDestination() {
    setState(() {
      _destinationPosition = null;
      _destinationName = null;
      _searchResults = [];
      _routePoints = [];
      _routeDistanceKm = 0;
      _remainingDistanceKm = 0;
      _routeError = null;
      _navTitle = AppStrings.readyForNavigation;
      _navSubtitle = AppStrings.searchDestinationToStart;
      _navIcon = Icons.navigation;
      _searchController.clear();
    });
  }

  Pothole? _findHazardAhead(LatLng current, List<Pothole> hazards) {
    final closest = PotholeDetectionEngine.findHazardAhead(
      current: current,
      heading: _currentHeading,
      hazards: hazards,
      radiusKm: 0.08,
    );

    if (closest == null) {
      _hazardAheadDistanceKm = null;
      return null;
    }

    _hazardAheadDistanceKm = _distanceKm(
      current,
      LatLng(closest.lat, closest.lng),
    );
    return closest;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<GPSProvider, PotholeProvider>(
      builder: (context, gps, potholeProvider, _) {
        final hasGps = gps.current?.isValid == true;
        final rawPosition = hasGps
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
          _smoothCarPosition = _smoothCarPosition == null
              ? rawPosition
              : _lerpLatLng(_smoothCarPosition!, rawPosition, 0.22);
          _updateCamera(_smoothCarPosition!);
        }

        final position = _smoothCarPosition ?? rawPosition;
        if (hasGps) {
          _updateNavigationInstruction(position);
        }
        final hazards = potholeProvider.activeHazards;
        _hazardAhead = hasGps ? _findHazardAhead(position, hazards) : null;
        final potholeRouteSegments = PotholeDetectionEngine.routeHazardPoints(
          _routePoints,
          hazards,
          "pothole",
        );

        final bumperRouteSegments = PotholeDetectionEngine.routeHazardPoints(
          _routePoints,
          hazards,
          "bumper",
        );

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
                          urlTemplate: MapTileConfig.urlTemplate,
                          subdomains: MapTileConfig.subdomains,
                          userAgentPackageName:
                              MapTileConfig.userAgentPackageName,
                          maxZoom: MapTileConfig.maxZoom,
                        ),
                        RichAttributionWidget(
                          attributions: [
                            TextSourceAttribution(
                              MapTileConfig.attribution,
                              onTap: () =>
                                  launchUrl(MapTileConfig.attributionUri),
                            ),
                          ],
                        ),
                        if (_trafficLayer)
                          CircleLayer(
                            circles: hazards.map((hazard) {
                              final isPothole = hazard.category == "pothole";

                              return CircleMarker(
                                point: LatLng(hazard.lat, hazard.lng),
                                radius: isPothole ? 58 : 42,
                                useRadiusInMeter: true,
                                color: (isPothole ? Colors.red : Colors.amber)
                                    .withValues(alpha: 0.18),
                                borderStrokeWidth: 2,
                                borderColor:
                                    (isPothole ? Colors.red : Colors.amber)
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
                              // ================= POTHOLE ROUTE =================
                              if (potholeRouteSegments.length >= 2)
                                Polyline(
                                  points: potholeRouteSegments,
                                  strokeWidth: 8,
                                  color: Colors.redAccent,
                                ),

                              // ================= BUMPER ROUTE =================
                              if (bumperRouteSegments.length >= 2)
                                Polyline(
                                  points: bumperRouteSegments,
                                  strokeWidth: 8,
                                  color: Colors.yellowAccent,
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
                              final color = isPothole
                                  ? Colors.redAccent
                                  : Colors.amberAccent;
                              final icon = isPothole
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
                            wifiConnected: gps.espWifiConnected,
                            wifiSsid: gps.wifiSsid,
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
                                  navTitle: _navTitle,
                                  navSubtitle: _navSubtitle,
                                  navIcon: _navIcon,
                                  hazardAhead: _hazardAhead,
                                  hazardAheadDistance: _hazardAheadDistanceKm,
                                  remainingDistanceKm: _remainingDistanceKm,
                                  accent: accent,
                                  hasGps: hasGps,
                                  speed: gps.current?.speed ?? 0,
                                  heading: _currentHeading,
                                  destinationName: _destinationName,
                                  routeDistanceKm: _routeDistanceKm,
                                  isRouting: _isRouting,
                                ),
                                const Spacer(),
                                _HazardPanel(
                                  accent: accent,
                                  hazards: hazards,
                                  position: position,
                                  distanceBuilder: (hazard) => _distanceKm(
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
                            speed: gps.current?.speed ?? 0,
                            heading: _currentHeading,
                            remainingDistanceKm: _remainingDistanceKm,
                            hazardAhead: _hazardAhead,
                            hazardAheadDistance: _hazardAheadDistanceKm,
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
    required this.wifiConnected,
    required this.wifiSsid,
    required this.onBack,
  });

  final Color accent;
  final bool hasGps;
  final bool wifiConnected;
  final String wifiSsid;
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
            tooltip: AppStrings.back,
            onTap: onBack,
          ),
          SizedBox(width: 16.w),
          Icon(Icons.map, color: accent, size: 26.sp),
          SizedBox(width: 10.w),
          Text(
            AppStrings.smartNavigation,
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
            hasGps ? AppStrings.gpsLocked : AppStrings.searchingGps,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          _ChipStatus(
            icon: wifiConnected ? Icons.wifi : Icons.wifi_off,
            label: wifiConnected
                ? (wifiSsid.isEmpty ? "ESP WiFi" : wifiSsid)
                : "ESP WiFi Offline",
            accent: wifiConnected ? Colors.greenAccent : Colors.orangeAccent,
          ),
          SizedBox(width: 10.w),
          _ChipStatus(
            icon: Icons.route,
            label: AppStrings.adaptiveRoute,
            accent: accent,
          ),
          SizedBox(width: 10.w),
          _ChipStatus(
            icon: Icons.shield,
            label: AppStrings.roadGuard,
            accent: accent,
          ),
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
                      readOnly: true,
                      showCursor: true,
                      onTap: () {
                        showInAppKeyboard(
                          context: context,
                          controller: controller,
                          title: AppStrings.searchDestination,
                          accentColor: accent,
                          onChanged: onChanged,
                        );
                      },
                      onChanged: onChanged,
                      textInputAction: TextInputAction.search,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w700,
                      ),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: AppStrings.searchDestination,
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
                  separatorBuilder: (_, __) => Divider(
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
                text: routeDistanceKm > 0
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
    required this.destinationName,
    required this.routeDistanceKm,
    required this.isRouting,
    required this.navTitle,
    required this.navSubtitle,
    required this.navIcon,
    required this.remainingDistanceKm,
    required this.hazardAhead,
    required this.hazardAheadDistance,
  });

  final Color accent;
  final bool hasGps;
  final double speed;
  final double heading;
  final String? destinationName;
  final double routeDistanceKm;
  final bool isRouting;
  final String navTitle;
  final String navSubtitle;
  final IconData navIcon;
  final double remainingDistanceKm;
  final Pothole? hazardAhead;
  final double? hazardAheadDistance;

  @override
  Widget build(BuildContext context) {
    final hasHazardAhead = hazardAhead != null && hazardAheadDistance != null;

    final hazardAheadTitle = !hasHazardAhead
        ? AppStrings.routeClear
        : hazardAhead!.category == "pothole"
        ? AppStrings.potholeAhead
        : AppStrings.speedBumpAhead;

    final hazardAheadSubtitle = !hasHazardAhead
        ? AppStrings.noHazardInFront
        : AppStrings.metersAhead((hazardAheadDistance! * 1000).round());

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
              AppStrings.destination,
              style: TextStyle(
                color: Colors.white54,
                fontSize: 11.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              destinationName ?? AppStrings.searchADestination,
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
                  ? AppStrings.calculatingRoute
                  : routeDistanceKm > 0
                  ? AppStrings.routeLoaded(routeDistanceKm)
                  : AppStrings.readyForNavigation,
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
                    label: AppStrings.speed,
                    value: speed.toStringAsFixed(0),
                    unit: "km/h",
                    accent: accent,
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: _MetricTile(
                    label: AppStrings.heading,
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
                color: hasHazardAhead
                    ? Colors.redAccent.withValues(alpha: 0.14)
                    : Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(15.r),
                border: Border.all(
                  color: hasHazardAhead
                      ? Colors.redAccent.withValues(alpha: 0.5)
                      : Colors.transparent,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40.w,
                    height: 40.w,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: hasHazardAhead
                          ? Colors.redAccent.withValues(alpha: 0.18)
                          : Colors.greenAccent.withValues(alpha: 0.12),
                    ),
                    child: Icon(
                      hasHazardAhead
                          ? Icons.warning_rounded
                          : Icons.check_circle,
                      color: hasHazardAhead
                          ? Colors.redAccent
                          : Colors.greenAccent,
                      size: 23.sp,
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hazardAheadTitle,
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
                          hazardAheadSubtitle,
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
              icon: navIcon,
              title: navTitle,
              subtitle: hasGps ? navSubtitle : AppStrings.waitingGpsFix,
              active: true,
            ),
            _RouteStep(
              accent: accent,
              icon: Icons.route,
              title: AppStrings.routeTracking,
              subtitle: remainingDistanceKm > 0
                  ? AppStrings.kmRemaining(remainingDistanceKm)
                  : AppStrings.noActiveRoute,
              active: remainingDistanceKm > 0,
            ),
            SizedBox(height: 6.h),
            Text(
              AppStrings.navigationSurface,
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
                  icon: followCar
                      ? Icons.my_location
                      : Icons.location_searching,
                  accent: followCar ? Colors.greenAccent : accent,
                  tooltip: AppStrings.followVehicle,
                  onTap: onFollow,
                ),
                _IconAction(
                  icon: alertsEnabled
                      ? Icons.notifications_active
                      : Icons.notifications_off,
                  accent: alertsEnabled ? Colors.greenAccent : Colors.redAccent,
                  tooltip: AppStrings.toggleAlerts,
                  onTap: onAlertToggle,
                ),
                _IconAction(
                  icon: trafficLayer ? Icons.layers : Icons.layers_clear,
                  accent: trafficLayer ? accent : Colors.white54,
                  tooltip: AppStrings.toggleHazardLayer,
                  onTap: onTrafficToggle,
                ),
                _IconAction(
                  icon: Icons.add,
                  accent: accent,
                  tooltip: AppStrings.zoomIn,
                  onTap: onZoomIn,
                ),
                _IconAction(
                  icon: Icons.remove,
                  accent: accent,
                  tooltip: AppStrings.zoomOut,
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
                        AppStrings.roadAlerts,
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
                          AppStrings.noActiveHazard,
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
                          final color = isPothole
                              ? Colors.redAccent
                              : Colors.amberAccent;

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
    required this.speed,
    required this.heading,
    required this.remainingDistanceKm,
    required this.hazardAhead,
    required this.hazardAheadDistance,
  });

  final Color accent;
  final double zoom;
  final int hazardCount;
  final bool alertsEnabled;
  final double speed;
  final double heading;
  final double remainingDistanceKm;
  final Pothole? hazardAhead;
  final double? hazardAheadDistance;

  @override
  Widget build(BuildContext context) {
    final hazardAheadLabel = hazardAhead?.category == "pothole"
        ? AppStrings.pothole
        : AppStrings.speedBump;

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
          _StripMetric(
            label: AppStrings.speed,
            value: "${speed.toStringAsFixed(0)} km/h",
            accent: accent,
          ),
          _DividerLine(),
          _StripMetric(
            label: AppStrings.heading,
            value: "${heading.toStringAsFixed(0)}°",
            accent: accent,
          ),
          _DividerLine(),
          _StripMetric(
            label: AppStrings.remaining,
            value: remainingDistanceKm > 0
                ? "${remainingDistanceKm.toStringAsFixed(1)} km"
                : "--",
            accent: accent,
          ),
          _DividerLine(),
          _StripMetric(
            label: AppStrings.hazards,
            value: hazardCount.toString(),
            accent: hazardCount > 0 ? Colors.orangeAccent : Colors.greenAccent,
          ),
          _DividerLine(),
          _StripMetric(
            label: AppStrings.ahead,
            value: hazardAhead == null
                ? AppStrings.clear
                : "$hazardAheadLabel ${(hazardAheadDistance! * 1000).round()}m",
            accent: hazardAhead == null ? Colors.greenAccent : Colors.redAccent,
          ),
          _DividerLine(),
          _StripMetric(
            label: AppStrings.alerts,
            value: alertsEnabled ? AppStrings.armed : AppStrings.muted,
            accent: alertsEnabled ? Colors.greenAccent : Colors.redAccent,
          ),
          const Spacer(),
          Icon(Icons.directions_car, color: accent, size: 22.sp),
          SizedBox(width: 8.w),
          Text(
            AppStrings.smartPotholeNavigation,
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
    final categoryLabel = category == "pothole"
        ? AppStrings.pothole
        : AppStrings.speedBump;

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
                  categoryLabel.toUpperCase(),
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
                  AppStrings.severityValue(severity),
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
