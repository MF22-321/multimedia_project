import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:frontend/core/model/pothole.dart';
import 'package:frontend/core/navigation/pothole_detection_control.dart';
import 'package:frontend/core/provider/gps_provider.dart';
import 'package:frontend/core/provider/pothole_provider.dart';
import 'package:frontend/core/utils/pothole_detection_engine.dart';
import 'package:frontend/features/home/presentation/page/map_detail_page.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:frontend/core/themes/car_theme.dart';

class MapCard extends StatefulWidget {
  const MapCard({super.key});

  @override
  State<MapCard> createState() => _MapCardState();
}

class _MapCardState extends State<MapCard> {
  final MapController _mapController = MapController();
  PotholeProvider? _potholeProvider;

  double _zoom = 20;
  bool firstLoad = true;
  bool _mapReady = false;
  bool _hasCenteredFallback = false;

  DateTime lastAlertTime = DateTime.now();
  DateTime lastMoveTime = DateTime.now();

  bool isDialogShowing = false;

  LatLng? lastCameraPosition;
  LatLng? smoothCarPosition;

  double currentHeading = 0;
  double smoothHeading = 0;
  double smoothMapRotation = 0;
  bool followCar = true;

  @override
  void initState() {
    super.initState();

    Future.microtask(() {
      if (!mounted) return;

      final potholeProvider = context.read<PotholeProvider>();
      _potholeProvider = potholeProvider;
      potholeProvider.bindGps(context.read<GPSProvider>());

      if (PotholeDetectionControl.enabled.value) {
        potholeProvider.attachRealtime();
      }
    });
  }

  @override
  void dispose() {
    _potholeProvider?.detachRealtime();
    super.dispose();
  }

  double angleLerp(double from, double to, double t) {
    double diff = (to - from + 540) % 360 - 180;
    return (from + diff * t + 360) % 360;
  }

  // ================= POSITION SMOOTH =================
  LatLng lerpLatLng(LatLng from, LatLng to, double t) {
    return LatLng(
      from.latitude + (to.latitude - from.latitude) * t,
      from.longitude + (to.longitude - from.longitude) * t,
    );
  }

  // ================= CAMERA =================
  void updateMapCamera(LatLng position) {
    if (!mounted || !_mapReady) return;

    if (!followCar) return; // kalau user sedang geser map, stop auto follow

    if (DateTime.now().difference(lastMoveTime).inMilliseconds < 80) return;
    lastMoveTime = DateTime.now();

    lastCameraPosition ??= position;

    final smoothLat =
        lastCameraPosition!.latitude +
        ((position.latitude - lastCameraPosition!.latitude) * 0.18);

    final smoothLng =
        lastCameraPosition!.longitude +
        ((position.longitude - lastCameraPosition!.longitude) * 0.18);

    final newPos = LatLng(smoothLat, smoothLng);

    lastCameraPosition = newPos;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      _mapController.move(newPos, _zoom, offset: const Offset(0, 140));

      _mapController.rotate(-smoothMapRotation);
    });
  }

  // ================= ALERT =================
  // ================= ALERT =================
  // ================= ALERT MODERN =================
  void triggerAlert(String category, double distance, double severity) {
    if (!mounted || isDialogShowing || !PotholeDetectionControl.enabled.value) {
      return;
    }

    isDialogShowing = true;

    final bool isPothole = category == "pothole";

    final Color alertColor = isPothole ? Colors.red : Colors.orange;

    final String title = isPothole
        ? "POTHOLE IN ${(distance * 1000).toInt()} M !"
        : "SPEED BUMP";

    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: "Alert",
      barrierColor: Colors.black.withValues(alpha: 0.55),
      transitionDuration: const Duration(milliseconds: 400),

      pageBuilder: (_, __, ___) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Center(
              child: Container(
                width: 500.w,
                height: 390.h,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28.r),
                  color: Colors.black,
                  boxShadow: [
                    BoxShadow(
                      color: alertColor.withValues(alpha: 0.5),
                      blurRadius: 30,
                      spreadRadius: 4,
                    ),
                  ],
                ),

                child: Stack(
                  children: [
                    // MAP BACKGROUND
                    ClipRRect(
                      borderRadius: BorderRadius.circular(28.r),
                      child: Opacity(
                        opacity: 0.45,
                        child: FlutterMap(
                          options: MapOptions(
                            initialCenter: smoothCarPosition!,
                            initialZoom: 16,
                          ),
                          children: [
                            TileLayer(
                              urlTemplate:
                                  "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                            ),
                          ],
                        ),
                      ),
                    ),

                    // TOP BAR
                    Positioned(
                      top: 15.h,
                      left: 15.w,
                      right: 15.w,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 18.w,
                          vertical: 10.h,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.shade900,
                          borderRadius: BorderRadius.circular(14.r),
                        ),
                        child: Text(
                          "Navigation Ready",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                    // WARNING TITLE
                    Positioned(
                      top: 70.h,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Text(
                          "WARNING !",
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 42.sp,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),

                    // CENTER ICON
                    Center(
                      child: TweenAnimationBuilder(
                        tween: Tween(begin: 0.9, end: 1.05),
                        duration: const Duration(milliseconds: 700),
                        curve: Curves.easeInOut,
                        builder: (_, value, child) {
                          return Transform.scale(
                            scale: value.toDouble(),
                            child: child,
                          );
                        },
                        child: Container(
                          width: 150.w,
                          height: 150.w,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [Colors.redAccent, Colors.red.shade900],
                            ),
                          ),
                          child: Center(
                            child: Icon(
                              Icons.priority_high,
                              color: Colors.white,
                              size: 100.sp,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // DISTANCE TEXT
                    Positioned(
                      bottom: 75.h,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Text(
                          title,
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 28.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                    // BOTTOM INFO BAR
                    Positioned(
                      bottom: 15.h,
                      left: 15.w,
                      right: 15.w,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 18.w,
                          vertical: 14.h,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.shade900,
                          borderRadius: BorderRadius.circular(14.r),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.location_pin, color: Colors.white),
                                SizedBox(width: 8.w),
                                Text(
                                  "Karawang",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16.sp,
                                  ),
                                ),
                              ],
                            ),

                            Text(
                              "ETA 12 min",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16.sp,
                              ),
                            ),

                            Text(
                              "4.6 km",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16.sp,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).then((_) {
      isDialogShowing = false;
    });

    Future.delayed(const Duration(seconds: 4), () {
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    });
  }

  // ================= CHECK ALERT =================
  void checkHazardAheadAlert(LatLng current, List<Pothole> potholes) {
    final hazard = PotholeDetectionEngine.findHazardAhead(
      current: current,
      heading: currentHeading,
      hazards: potholes,
    );

    if (hazard == null) return;

    final distance = PotholeDetectionEngine.distanceKm(
      current.latitude,
      current.longitude,
      hazard.lat,
      hazard.lng,
    );

    if (DateTime.now().difference(lastAlertTime).inSeconds < 5) return;

    lastAlertTime = DateTime.now();

    triggerAlert(
      hazard.category,
      distance,
      hazard.severity,
    );
  }

  // ================= ZOOM =================
  void _zoomIn(LatLng pos) {
    _zoom = (_zoom + 1).clamp(5.0, 23.0);
    _mapController.move(pos, _zoom);
  }

  void _zoomOut(LatLng pos) {
    _zoom = (_zoom - 1).clamp(5.0, 23.0);
    _mapController.move(pos, _zoom);
  }

  void _openMapDetail() {
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 420),
        reverseTransitionDuration: const Duration(milliseconds: 280),
        pageBuilder: (_, __, ___) => const MapDetailPage(),
        transitionsBuilder: (_, animation, __, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );

          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: PotholeDetectionControl.enabled,
      builder: (context, potholeDetectionEnabled, _) {
        return Consumer2<GPSProvider, PotholeProvider>(
          builder: (context, gps, potholeProvider, _) {
            final hasGPS = gps.current != null;
            final hazards = potholeDetectionEnabled
                ? potholeProvider.activeHazards
                : <Pothole>[];

            final rawPosition = hasGPS
                ? LatLng(gps.current!.lat, gps.current!.lng)
                : hazards.isNotEmpty
                ? LatLng(hazards.first.lat, hazards.first.lng)
                : const LatLng(-6.3, 107.2);

            if (hasGPS) {
              currentHeading = gps.current!.heading;

              smoothHeading = angleLerp(smoothHeading, currentHeading, 0.12);

              smoothMapRotation = angleLerp(
                smoothMapRotation,
                currentHeading,
                0.08,
              );

              if (smoothCarPosition == null) {
                smoothCarPosition = rawPosition;
              } else {
                smoothCarPosition = lerpLatLng(
                  smoothCarPosition!,
                  rawPosition,
                  0.18,
                );
              }

              updateMapCamera(smoothCarPosition!);

              if (potholeDetectionEnabled) {
                checkHazardAheadAlert(
                  smoothCarPosition!,
                  potholeProvider.activeHazards,
                );
              }
            }

            final position = smoothCarPosition ?? rawPosition;
            final mapZoom = hasGPS ? _zoom : hazards.isNotEmpty ? 15.5 : 13.0;

            if (!hasGPS && hazards.isNotEmpty && !_hasCenteredFallback) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted || !_mapReady) return;
                _mapController.move(position, mapZoom);
                _hasCenteredFallback = true;
              });
            }

            return ValueListenableBuilder(
              valueListenable: CarThemes.currentTheme,
              builder: (context, themeType, _) {
                final theme = CarThemes.getTheme(themeType);

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  height: 400.h,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(25.r),
                    border: Border.all(
                      color: theme.accentColor.withValues(alpha: 0.6),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: theme.accentColor.withValues(alpha: 0.25),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.hardEdge,
                  child: Stack(
                    children: [
                      FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: position,
                          initialZoom: mapZoom,

                          onPositionChanged: (mapPosition, hasGesture) {
                            if (hasGesture) {
                              followCar = false; // user geser map
                            }
                          },

                          onTap: (_, __) => _openMapDetail(),

                          onMapReady: () {
                            _mapReady = true;
                            if (firstLoad) {
                              _mapController.move(position, mapZoom);
                              firstLoad = false;
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

                          if (hasGPS && smoothCarPosition != null)
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: smoothCarPosition!,
                                  width: 60,
                                  height: 60,
                                  child: Transform.rotate(
                                    angle: smoothHeading * pi / 180,
                                    child: Icon(
                                      Icons.navigation,
                                      color: theme.accentColor,
                                      size: 42,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                          if (potholeDetectionEnabled)
                            MarkerLayer(
                              markers: hazards
                                  .map((p) {
                                    Color color = Colors.orange;
                                    IconData icon = Icons.warning_rounded;

                                    if (p.category == "pothole") {
                                      color = Colors.red;
                                      icon = Icons.report_problem;
                                    } else if (p.category == "bumper") {
                                      color = Colors.yellow;
                                      icon = Icons.speed;
                                    }

                                    return Marker(
                                      point: LatLng(p.lat, p.lng),
                                      width: 65,
                                      height: 65,
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(icon, color: color, size: 28),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withValues(
                                                alpha: 0.75,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              "${p.category.toUpperCase()} ${p.severity.toStringAsFixed(1)}",
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 9,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  })
                                  .toList(),
                            ),
                        ],
                      ),

                      if (!hasGPS)
                        Positioned(
                          left: 15.w,
                          bottom: 15.h,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12.w,
                              vertical: 8.h,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.72),
                              borderRadius: BorderRadius.circular(12.r),
                              border: Border.all(
                                color: Colors.orangeAccent.withValues(
                                  alpha: 0.58,
                                ),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.gps_not_fixed,
                                  color: Colors.orangeAccent,
                                  size: 18.sp,
                                ),
                                SizedBox(width: 8.w),
                                Text(
                                  "Waiting for ESP32 GPS",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      Positioned(
                        top: 15.h,
                        left: 15.w,
                        right: 15.w,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 20.w,
                            vertical: 10.h,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(15.r),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.navigation,
                                color: theme.accentColor,
                                size: 20.sp,
                              ),
                              SizedBox(width: 10.w),
                              Text(
                                hasGPS
                                    ? "Speed ${gps.current!.speed.toStringAsFixed(0)} km/h  •  Heading ${gps.current!.heading.toStringAsFixed(0)}°"
                                    : gps.status,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16.sp,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      Positioned(
                        top: 70.h,
                        right: 15.w,
                        child: GestureDetector(
                          onTap: () {
                            final enabled = !potholeDetectionEnabled;
                            PotholeDetectionControl.enabled.value = enabled;

                            if (enabled) {
                              context.read<PotholeProvider>().attachRealtime();
                            } else {
                              context.read<PotholeProvider>().detachRealtime();
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: potholeDetectionEnabled
                                    ? Colors.green
                                    : Colors.red,
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              potholeDetectionEnabled
                                  ? Icons.notifications_active
                                  : Icons.notifications_off,
                              color: potholeDetectionEnabled
                                  ? Colors.green
                                  : Colors.red,
                              size: 22,
                            ),
                          ),
                        ),
                      ),

                      Positioned(
                        top: 70.h,
                        left: 15.w,
                        child: Tooltip(
                          message: "Open detailed map",
                          child: GestureDetector(
                            onTap: _openMapDetail,
                            child: Container(
                              width: 45.w,
                              height: 45.w,
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.75),
                                borderRadius: BorderRadius.circular(12.r),
                                border: Border.all(
                                  color: theme.accentColor,
                                  width: 2,
                                ),
                              ),
                              child: Icon(
                                Icons.open_in_full,
                                color: theme.accentColor,
                                size: 20.sp,
                              ),
                            ),
                          ),
                        ),
                      ),

                      Positioned(
                        right: 15.w,
                        bottom: 60.h,
                        child: Column(
                          children: [
                            _zoomButton(
                              Icons.add,
                              () => _zoomIn(position),
                              theme,
                            ),
                            SizedBox(height: 10.h),
                            _zoomButton(
                              Icons.remove,
                              () => _zoomOut(position),
                              theme,
                            ),
                          ],
                        ),
                      ),

                      Positioned(
                        right: 15.w,
                        bottom: 170.h,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              followCar = true;
                            });

                            updateMapCamera(position);
                          },
                          child: Container(
                            width: 45.w,
                            height: 45.w,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.75),
                              borderRadius: BorderRadius.circular(12.r),
                              border: Border.all(
                                color: followCar
                                    ? Colors.green
                                    : theme.accentColor,
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              Icons.my_location,
                              color: followCar
                                  ? Colors.green
                                  : theme.accentColor,
                            ),
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
      },
    );
  }

  Widget _zoomButton(IconData icon, VoidCallback onTap, CarThemeData theme) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 45.w,
        height: 45.w,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: theme.accentColor, width: 2),
        ),
        child: Icon(icon, color: theme.accentColor),
      ),
    );
  }
}
