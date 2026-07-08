import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:frontend/core/model/pothole.dart';
import 'package:frontend/core/navigation/pothole_detection_control.dart';
import 'package:frontend/core/provider/gps_provider.dart';
import 'package:frontend/core/provider/pothole_provider.dart';
import 'package:frontend/core/services/map_tile_config.dart';
import 'package:frontend/core/utils/pothole_detection_engine.dart';
import 'package:frontend/features/home/presentation/page/map_detail_page.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:frontend/core/themes/car_theme.dart';
import 'package:url_launcher/url_launcher.dart';

class _RoadAlertData {
  const _RoadAlertData({
    required this.category,
    required this.distance,
    required this.severity,
  });

  final String category;
  final double distance;
  final double severity;
}

class MapCard extends StatefulWidget {
  const MapCard({super.key});

  @override
  State<MapCard> createState() => _MapCardState();
}

class _MapCardState extends State<MapCard> {
  final MapController _mapController = MapController();
  PotholeProvider? _potholeProvider;
  GPSProvider? _gpsProviderRef;
  bool _prevEspWifi = false;

  double _zoom = 18;
  bool firstLoad = true;
  bool _mapReady = false;
  LatLng? _fallbackCenter;

  DateTime lastMoveTime = DateTime.now();

  bool isDialogShowing = false;
  Timer? _safeClearTimer;
  BuildContext? _alertDialogContext;
  final ValueNotifier<_RoadAlertData> _alertData = ValueNotifier(
    const _RoadAlertData(category: 'normal', distance: 0, severity: 0),
  );

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

      final gpsProvider = context.read<GPSProvider>();
      potholeProvider.bindGps(gpsProvider);

      _gpsProviderRef = gpsProvider;
      _prevEspWifi = gpsProvider.espWifiConnected;
      gpsProvider.addListener(_onGpsChanged);

      if (PotholeDetectionControl.enabled.value) {
        potholeProvider.attachRealtime();
      }
    });
  }

  // Saat ESP32 baru dapat WiFi, langsung refresh pothole dari backend.
  void _onGpsChanged() {
    final espWifi = _gpsProviderRef?.espWifiConnected ?? false;
    if (espWifi && !_prevEspWifi) {
      _potholeProvider?.loadPotholes();
    }
    _prevEspWifi = espWifi;
  }

  @override
  void dispose() {
    _safeClearTimer?.cancel();
    _alertData.dispose();
    _gpsProviderRef?.removeListener(_onGpsChanged);
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

  void triggerAlert(String category, double distance, double severity) {
    if (!mounted || !PotholeDetectionControl.enabled.value) {
      return;
    }

    _safeClearTimer?.cancel();
    _safeClearTimer = null;
    _alertData.value = _RoadAlertData(
      category: category,
      distance: distance,
      severity: severity,
    );

    if (isDialogShowing) return;
    isDialogShowing = true;

    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: "Alert",
      barrierColor: Colors.black.withValues(alpha: 0.55),
      transitionDuration: const Duration(milliseconds: 400),

      pageBuilder: (dialogContext, __, ___) {
        _alertDialogContext = dialogContext;
        return ValueListenableBuilder<_RoadAlertData>(
          valueListenable: _alertData,
          builder: (context, alert, _) {
            final isPothole = alert.category == "pothole";
            final alertColor = isPothole ? Colors.red : Colors.orange;
            final title = isPothole
                ? "POTHOLE IN ${(alert.distance * 1000).round()} M"
                : "SPEED BUMP IN ${(alert.distance * 1000).round()} M";

            return Center(
              child: Container(
                width: 500.w,
                height: 390.h,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28.r),
                  color: Colors.white,
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
                          color: alertColor.shade900,
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
                            color: alertColor,
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
                              colors: [
                                alertColor.shade400,
                                alertColor.shade900,
                              ],
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
                            color: alertColor,
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
                          color: alertColor.shade900,
                          borderRadius: BorderRadius.circular(14.r),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.analytics, color: Colors.white),
                                SizedBox(width: 8.w),
                                Text(
                                  "Severity ${alert.severity.toStringAsFixed(1)}",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16.sp,
                                  ),
                                ),
                              ],
                            ),

                            Text(
                              isPothole ? "POTHOLE" : "SPEED BUMP",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16.sp,
                              ),
                            ),

                            Text(
                              "DRIVE CAREFULLY",
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
      _alertDialogContext = null;
      _safeClearTimer?.cancel();
      _safeClearTimer = null;
    });
  }

  void _markRoadSafe() {
    if (!isDialogShowing || _safeClearTimer != null) return;

    _safeClearTimer = Timer(const Duration(seconds: 2), () {
      final dialogContext = _alertDialogContext;
      if (!mounted || !isDialogShowing || dialogContext == null) return;
      Navigator.of(dialogContext).pop();
    });
  }

  // ================= CHECK ALERT =================
  void checkHazardAheadAlert(LatLng current, List<Pothole> potholes) {
    final hazard = PotholeDetectionEngine.findHazardAhead(
      current: current,
      heading: currentHeading,
      hazards: potholes,
    );

    if (hazard == null) {
      _markRoadSafe();
      return;
    }

    final distance = PotholeDetectionEngine.distanceKm(
      current.latitude,
      current.longitude,
      hazard.lat,
      hazard.lng,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      triggerAlert(hazard.category, distance, hazard.severity);
    });
  }

  // ================= ZOOM =================
  void _zoomIn(LatLng pos) {
    _zoom = (_zoom + 1).clamp(5.0, MapTileConfig.maxZoom);
    _mapController.move(pos, _zoom);
  }

  void _zoomOut(LatLng pos) {
    _zoom = (_zoom - 1).clamp(5.0, MapTileConfig.maxZoom);
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
            // hasPosition: ada koordinat walau satelit < 4 → tetap tampilkan marker
            final hasPosition = gps.current?.hasPosition == true;
            // hasGPS: fix penuh (≥4 satelit) → untuk pothole alert
            final hasGPS = gps.current?.isValid == true;
            final hazards = potholeDetectionEnabled
                ? potholeProvider.activeHazards
                : <Pothole>[];

            final rawPosition = hasPosition
                ? LatLng(gps.current!.lat, gps.current!.lng)
                : hazards.isNotEmpty
                ? LatLng(hazards.first.lat, hazards.first.lng)
                : const LatLng(-6.3, 107.2);

            if (hasPosition) {
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
              } else {
                _markRoadSafe();
              }
            } else {
              _markRoadSafe();
            }

            final position = smoothCarPosition ?? rawPosition;
            final mapZoom = hasPosition
                ? _zoom
                : hazards.isNotEmpty
                ? 15.5
                : 13.0;

            // Saat belum ada GPS tapi ada hazards, center ke hazard pertama.
            // Reset saat GPS datang supaya bisa re-center ke hazard lagi jika GPS hilang.
            if (!hasPosition && hazards.isNotEmpty) {
              final targetCenter = LatLng(hazards.first.lat, hazards.first.lng);
              if (_fallbackCenter?.latitude != targetCenter.latitude ||
                  _fallbackCenter?.longitude != targetCenter.longitude) {
                _fallbackCenter = targetCenter;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted || !_mapReady) return;
                  _mapController.move(targetCenter, 15.5);
                });
              }
            } else if (hasPosition) {
              _fallbackCenter = null;
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

                          if (hasPosition && smoothCarPosition != null)
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
                              markers: hazards.map((p) {
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
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
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
                              }).toList(),
                            ),
                        ],
                      ),

                      // Tampilkan overlay hanya saat benar-benar belum ada posisi sama sekali
                      if (!hasPosition)
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
                                hasPosition
                                    ? "Speed ${gps.current!.speed.toStringAsFixed(0)} km/h  •  Heading ${gps.current!.heading.toStringAsFixed(0)}°${!hasGPS ? '  •  Weak GPS (${gps.satellites} sat)' : ''}  •  ESP WiFi ${gps.espWifiConnected ? (gps.wifiSsid.isEmpty ? 'Connected' : gps.wifiSsid) : 'Offline'}"
                                    : "${gps.status}  •  ESP WiFi ${gps.espWifiConnected ? (gps.wifiSsid.isEmpty ? 'Connected' : gps.wifiSsid) : 'Offline'}",
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
