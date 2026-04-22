import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:frontend/core/model/pothole.dart';
import 'package:frontend/core/provider/gps_provider.dart';
import 'package:frontend/core/provider/pothole_provider.dart';
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

  double _zoom = 20;
  bool firstLoad = true;

  DateTime lastAlertTime = DateTime.now();
  DateTime lastMoveTime = DateTime.now();

  bool isDialogShowing = false;
  bool alertEnabled = true;

  LatLng? lastCameraPosition;
  LatLng? smoothCarPosition;

  double currentHeading = 0;
  double smoothHeading = 0;
  double smoothMapRotation = 0;
  bool followCar = true;

  Timer? refreshTimer;

  @override
  void initState() {
    super.initState();

    Future.microtask(() {
      context.read<PotholeProvider>().loadPotholes();
    });

    refreshTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) {
        context.read<PotholeProvider>().loadPotholes();
      }
    });
  }

  @override
  void dispose() {
    refreshTimer?.cancel();
    super.dispose();
  }

  // ================= DISTANCE =================
  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295;

    final a =
        0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;

    return 12742 * asin(sqrt(a));
  }

  // ================= BEARING =================
  double calculateBearing(double lat1, double lon1, double lat2, double lon2) {
    final dLon = (lon2 - lon1) * pi / 180;

    final y = sin(dLon) * cos(lat2 * pi / 180);

    final x =
        cos(lat1 * pi / 180) * sin(lat2 * pi / 180) -
        sin(lat1 * pi / 180) * cos(lat2 * pi / 180) * cos(dLon);

    final bearing = atan2(y, x);

    return (bearing * 180 / pi + 360) % 360;
  }

  // ================= ANGLE =================
  double getAngleDiff(double a, double b) {
    double diff = (a - b).abs();
    return diff > 180 ? 360 - diff : diff;
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
    if (!mounted) return;

    if (!followCar) return; // kalau user sedang geser map, stop auto follow

    if (DateTime.now().difference(lastMoveTime).inMilliseconds < 80) return;
    lastMoveTime = DateTime.now();

    if (lastCameraPosition == null) {
      lastCameraPosition = position;
    }

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
  void triggerAlert(double distance) {
    if (!mounted || isDialogShowing || !alertEnabled) return;

    isDialogShowing = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      showGeneralDialog(
        context: context,
        barrierDismissible: false,
        barrierLabel: "Pothole Alert",
        barrierColor: Colors.black.withOpacity(0.45),
        transitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (_, __, ___) {
          return Center(
            child: Container(
              width: 420.w,
              padding: EdgeInsets.all(24.w),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24.r),
                color: const Color(0xFF111111),
                border: Border.all(
                  color: Colors.orangeAccent.withOpacity(0.8),
                  width: 2,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.orangeAccent,
                    size: 50.sp,
                  ),

                  SizedBox(height: 18.h),

                  Text(
                    "POTHOLE DETECTED",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  SizedBox(height: 12.h),

                  Text(
                    "${(distance * 1000).toStringAsFixed(0)} meters ahead",
                    style: TextStyle(color: Colors.white70, fontSize: 16.sp),
                  ),

                  SizedBox(height: 24.h),

                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            Navigator.pop(context);
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(vertical: 14.h),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14.r),
                              color: Colors.white.withOpacity(0.08),
                            ),
                            child: Center(
                              child: Text(
                                "Dismiss",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15.sp,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      SizedBox(width: 12.w),

                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              alertEnabled = false;
                            });

                            Navigator.pop(context);
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(vertical: 14.h),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14.r),
                              color: Colors.orangeAccent,
                            ),
                            child: Center(
                              child: Text(
                                "Mute Alert",
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 15.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ).then((_) {
        isDialogShowing = false;
      });
    });
  }

  // ================= CHECK ALERT =================
  void checkPotholeAlert(LatLng current, List<Pothole> potholes) {
    for (var p in potholes) {
      final distance = calculateDistance(
        current.latitude,
        current.longitude,
        p.lat,
        p.lng,
      );

      if (distance < 0.05) {
        final bearingToPothole = calculateBearing(
          current.latitude,
          current.longitude,
          p.lat,
          p.lng,
        );

        final diff = getAngleDiff(bearingToPothole, currentHeading);

        if (diff < 90) {
          if (DateTime.now().difference(lastAlertTime).inSeconds < 5) return;

          lastAlertTime = DateTime.now();
          triggerAlert(distance);
          break;
        }
      }
    }
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

  @override
  Widget build(BuildContext context) {
    return Consumer2<GPSProvider, PotholeProvider>(
      builder: (context, gps, potholeProvider, _) {
        final hasGPS = gps.current != null;

        final rawPosition = hasGPS
            ? LatLng(gps.current!.lat, gps.current!.lng)
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

          checkPotholeAlert(smoothCarPosition!, potholeProvider.potholes);
        }

        final position = smoothCarPosition ?? rawPosition;

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
                  color: theme.accentColor.withOpacity(0.6),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: theme.accentColor.withOpacity(0.25),
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
                      initialZoom: _zoom,

                      onPositionChanged: (mapPosition, hasGesture) {
                        if (hasGesture) {
                          followCar = false; // user geser map
                        }
                      },

                      onMapReady: () {
                        if (firstLoad) {
                          updateMapCamera(position);
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

                      MarkerLayer(
                        markers: potholeProvider.potholes
                            .where((p) => p.category != "normal")
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
                                        color: Colors.black.withOpacity(0.75),
                                        borderRadius: BorderRadius.circular(6),
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
                      top: 120.h,
                      left: 20.w,
                      right: 20.w,
                      child: Container(
                        padding: EdgeInsets.all(18.w),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.78),
                          borderRadius: BorderRadius.circular(18.r),
                          border: Border.all(
                            color: Colors.orangeAccent.withOpacity(0.8),
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.gps_not_fixed,
                              color: Colors.orangeAccent,
                              size: 42.sp,
                            ),
                            SizedBox(height: 12.h),
                            Text(
                              "GPS STATUS",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 14.h),
                            Text(
                              "Searching Signal",
                              style: TextStyle(
                                color: Colors.orangeAccent,
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 6.h),
                            Text(
                              "No Satellites",
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14.sp,
                              ),
                            ),
                            SizedBox(height: 14.h),
                            Text(
                              "Move vehicle to open sky area",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 12.sp,
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
                        color: Colors.black.withOpacity(0.6),
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
                            hasGPS ? "Navigation Active" : "Searching GPS...",
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
                        setState(() {
                          alertEnabled = !alertEnabled;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: alertEnabled ? Colors.green : Colors.red,
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          alertEnabled
                              ? Icons.notifications_active
                              : Icons.notifications_off,
                          color: alertEnabled ? Colors.green : Colors.red,
                          size: 22,
                        ),
                      ),
                    ),
                  ),

                  Positioned(
                    right: 15.w,
                    bottom: 60.h,
                    child: Column(
                      children: [
                        _zoomButton(Icons.add, () => _zoomIn(position), theme),
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
                          color: Colors.black.withOpacity(0.75),
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(
                            color: followCar ? Colors.green : theme.accentColor,
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          Icons.my_location,
                          color: followCar ? Colors.green : theme.accentColor,
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
  }

  Widget _zoomButton(IconData icon, VoidCallback onTap, CarThemeData theme) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 45.w,
        height: 45.w,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.75),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: theme.accentColor, width: 2),
        ),
        child: Icon(icon, color: theme.accentColor),
      ),
    );
  }
}
