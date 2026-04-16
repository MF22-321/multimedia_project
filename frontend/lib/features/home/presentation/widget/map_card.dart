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
  bool isDialogShowing = false;

  LatLng? previousPosition;
  double currentHeading = 0;
  bool alertEnabled = true; // 🔔 toggle alert

  @override
  void initState() {
    super.initState();

    Future.microtask(() {
      context.read<PotholeProvider>().loadPotholes();
    });

    // auto refresh biar realtime
    Timer.periodic(const Duration(seconds: 3), (_) {
      context.read<PotholeProvider>().loadPotholes();
    });
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

  // 🔥 FIX ANGLE
  double getAngleDiff(double a, double b) {
    double diff = (a - b).abs();
    return diff > 180 ? 360 - diff : diff;
  }

  // ================= ALERT =================
  void triggerAlert(double distance) {
    if (!mounted || isDialogShowing || !alertEnabled) return;

    isDialogShowing = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("⚠️ Pothole Ahead"),
          content: Text(
            "Lubang di depan (${(distance * 1000).toStringAsFixed(0)} m)",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  alertEnabled = false; // 🔕 disable alert
                });
                Navigator.pop(context);
              },
              child: const Text("Mute"),
            ),
          ],
        ),
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
        // 50 meter

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

  void _zoomIn(LatLng pos) {
    _zoom += 1;
    _mapController.move(pos, _zoom);
  }

  void _zoomOut(LatLng pos) {
    _zoom -= 1;
    _mapController.move(pos, _zoom);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<GPSProvider, PotholeProvider>(
      builder: (context, gps, potholeProvider, _) {
        final hasGPS = gps.current != null;

        final position = hasGPS
            ? LatLng(gps.current!.lat, gps.current!.lng)
            : const LatLng(-6.3, 107.2); // fallback

        /// UPDATE HEADING
        if (hasGPS && previousPosition != null) {
          currentHeading = calculateBearing(
            previousPosition!.latitude,
            previousPosition!.longitude,
            position.latitude,
            position.longitude,
          );
        }
        previousPosition = position;

        if (hasGPS) {
          checkPotholeAlert(position, potholeProvider.potholes);
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
                  /// ================= MAP =================
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: position,
                      initialZoom: _zoom,
                      onMapReady: () {
                        if (firstLoad) {
                          _mapController.move(position, _zoom);
                          firstLoad = false;
                        }
                      },
                    ),

                    children: [
                      /// 🌞 TILE TERANG
                      TileLayer(
                        urlTemplate:
                            "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                        userAgentPackageName: "com.pothole.navigation.app",
                        maxZoom: 25,
                      ),

                      /// 🚗 CAR
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: position,
                            width: 40,
                            height: 40,
                            child: Icon(
                              Icons.navigation,
                              color: theme.accentColor,
                              size: 36,
                            ),
                          ),
                        ],
                      ),

                      /// 🔥 POTHOLE MARKER (IMPROVED)
                      MarkerLayer(
                        markers: potholeProvider.potholes.map((p) {
                          final isDanger = p.severity > 7;

                          return Marker(
                            point: LatLng(p.lat, p.lng),
                            width: 60,
                            height: 60,
                            child: Column(
                              children: [
                                Icon(
                                  Icons.warning_rounded,
                                  color: isDanger ? Colors.red : Colors.orange,
                                  size: 30,
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.7),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    p.severity.toStringAsFixed(1),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
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

                  /// 🔥 LOADING OVERLAY
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 400),
                    opacity: hasGPS ? 0 : 1,
                    child: Container(
                      color: Colors.black.withOpacity(0.6),
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                  ),

                  /// ================= UI =================
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

                  /// ZOOM
                  Positioned(
                    right: 15.w,
                    bottom: 90.h,
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
