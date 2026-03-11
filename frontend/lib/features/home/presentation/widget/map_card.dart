import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:frontend/core/themes/car_theme.dart';

class MapCard extends StatefulWidget {
  const MapCard({super.key});

  @override
  State<MapCard> createState() => _MapCardState();
}

class _MapCardState extends State<MapCard> {

  final MapController _mapController = MapController();

  final LatLng _carPosition = const LatLng(-6.402484, 107.470673);

  double _zoom = 14;

  void _zoomIn() {
    setState(() {
      _zoom += 1;
      _mapController.move(_carPosition, _zoom);
    });
  }

  void _zoomOut() {
    setState(() {
      _zoom -= 1;
      _mapController.move(_carPosition, _zoom);
    });
  }

  @override
  Widget build(BuildContext context) {

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
              )
            ],
          ),

          clipBehavior: Clip.hardEdge,

          child: Stack(
            children: [

              /// MAP
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _carPosition,
                  initialZoom: _zoom,
                ),

                children: [

                  TileLayer(
                    urlTemplate:
                        "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                    userAgentPackageName: "multimedia_project",
                  ),

                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _carPosition,
                        width: 40,
                        height: 40,
                        child: Icon(
                          Icons.navigation,
                          color: theme.accentColor,
                          size: 36,
                        ),
                      )
                    ],
                  )
                ],
              ),

              /// TOP NAV BAR
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
                      Icon(Icons.navigation,
                          color: theme.accentColor, size: 20.sp),

                      SizedBox(width: 10.w),

                      Text(
                        "Navigation Ready",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      )
                    ],
                  ),
                ),
              ),

              /// CENTER CROSSHAIR
              Center(
                child: Icon(
                  Icons.add,
                  size: 30.sp,
                  color: Colors.white.withOpacity(0.7),
                ),
              ),

              /// BOTTOM NAV PANEL
              Positioned(
                bottom: 15.h,
                left: 15.w,
                right: 15.w,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 20.w,
                    vertical: 14.h,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.75),
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [

                      Row(
                        children: [
                          Icon(Icons.place,
                              color: theme.accentColor,
                              size: 24.sp),

                          SizedBox(width: 8.w),

                          Text(
                            "Karawang",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15.sp,
                            ),
                          ),
                        ],
                      ),

                      Row(
                        children: [
                          Text(
                            "ETA 12 min",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15.sp,
                            ),
                          ),
                          SizedBox(width: 20.w),
                          Text(
                            "4.6 km",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15.sp,
                            ),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              ),

              /// ZOOM CONTROL
              Positioned(
                right: 15.w,
                bottom: 90.h,
                child: Column(
                  children: [
                    _zoomButton(Icons.add, _zoomIn, theme),
                    SizedBox(height: 10.h),
                    _zoomButton(Icons.remove, _zoomOut, theme),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _zoomButton(
      IconData icon,
      VoidCallback onTap,
      CarThemeData theme,
      ) {

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 45.w,
        height: 45.w,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.75),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: theme.accentColor,
            width: 2,
          ),
        ),
        child: Icon(icon, color: theme.accentColor),
      ),
    );
  }
}