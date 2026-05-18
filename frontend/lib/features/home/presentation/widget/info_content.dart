import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:frontend/core/themes/car_theme.dart';

class InfoContent extends StatefulWidget {
  const InfoContent({super.key});

  @override
  State<InfoContent> createState() => _InfoContentState();
}

class _InfoContentState extends State<InfoContent> {

  late Timer timer;

  DateTime now = DateTime.now();

  @override
  void initState() {
    super.initState();

    timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {

        setState(() {
          now = DateTime.now();
        });
      },
    );
  }

  @override
  void dispose() {

    timer.cancel();

    super.dispose();
  }

  /// ===============================
  /// ACCENT COLOR
  /// ===============================
  Color getAccentColor(
    CarThemeType type,
    CarThemeData theme,
  ) {

    switch (type) {

      case CarThemeType.comfort:
        return const Color(0xFF6CB4FF);

      case CarThemeType.sport:
        return Colors.redAccent;

      case CarThemeType.futuristic:
        return const Color(0xFF00E5FF);

      case CarThemeType.retro:
        return const Color(0xFFFF2BC2);

      case CarThemeType.playful:
        return const Color(0xFFC6A883);

      case CarThemeType.custom:
        return theme.buttonColor;
    }
  }

  @override
  Widget build(BuildContext context) {

    final currentTheme =
        CarThemes.currentTheme.value;

    final theme =
        CarThemes.getTheme(currentTheme);

    final accent =
        getAccentColor(
          currentTheme,
          theme,
        );

    return Scaffold(
      backgroundColor: Colors.black,

      body: Container(
        width: double.infinity,
        height: double.infinity,

        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,

            colors: theme.backgroundGradient,
          ),
        ),

        child: Stack(
          children: [

            /// =========================
            /// AMBIENT GLOW
            /// =========================
            Positioned(
              right: -120.w,
              top: 100.h,

              child: Container(
                width: 400.w,
                height: 400.w,

                decoration: BoxDecoration(
                  shape: BoxShape.circle,

                  color: accent.withOpacity(0.18),
                ),
              ),
            ),

            Positioned(
              left: -100.w,
              bottom: 0,

              child: Container(
                width: 320.w,
                height: 320.w,

                decoration: BoxDecoration(
                  shape: BoxShape.circle,

                  color: accent.withOpacity(0.08),
                ),
              ),
            ),

            /// =========================
            /// BLUR
            /// =========================
            BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: 30,
                sigmaY: 30,
              ),

              child: Container(
                color: Colors.black.withOpacity(
                  0.12,
                ),
              ),
            ),

            SafeArea(
              child: Padding(
                padding: EdgeInsets.all(24.w),

                child: Column(
                  children: [

                    /// =====================
                    /// TOP BAR
                    /// =====================
                    Container(
                      height: 90.h,

                      padding: EdgeInsets.symmetric(
                        horizontal: 28.w,
                      ),

                      decoration: BoxDecoration(
                        borderRadius:
                            BorderRadius.circular(
                              30.r,
                            ),

                        color: Colors.white
                            .withOpacity(0.05),

                        border: Border.all(
                          color: Colors.white
                              .withOpacity(0.08),
                        ),
                      ),

                      child: Row(
                        mainAxisAlignment:
                            MainAxisAlignment
                                .spaceBetween,

                        children: [

                          /// LEFT
                          Row(
                            children: [

                              GestureDetector(
                                onTap: () {
                                  Navigator.pop(
                                    context,
                                  );
                                },

                                child: Container(
                                  width: 52.w,
                                  height: 52.w,

                                  decoration: BoxDecoration(
                                    shape:
                                        BoxShape.circle,

                                    color: Colors.white
                                        .withOpacity(
                                          0.06,
                                        ),

                                    border: Border.all(
                                      color: Colors
                                          .white
                                          .withOpacity(
                                            0.08,
                                          ),
                                    ),
                                  ),

                                  child: Icon(
                                    Icons
                                        .arrow_back_ios_new,

                                    color: accent,

                                    size: 22.sp,
                                  ),
                                ),
                              ),

                              SizedBox(width: 18.w),

                              Container(
                                width: 52.w,
                                height: 52.w,

                                decoration: BoxDecoration(
                                  shape:
                                      BoxShape.circle,

                                  color: accent,
                                ),

                                child: Icon(
                                  Icons.info,

                                  color: Colors.white,

                                  size: 28.sp,
                                ),
                              ),

                              SizedBox(width: 16.w),

                              Column(
                                mainAxisAlignment:
                                    MainAxisAlignment
                                        .center,

                                crossAxisAlignment:
                                    CrossAxisAlignment
                                        .start,

                                children: [

                                  Text(
                                    'Vehicle Information',

                                    style: TextStyle(
                                      color:
                                          Colors.white,

                                      fontSize: 24.sp,

                                      fontWeight:
                                          FontWeight
                                              .bold,
                                    ),
                                  ),

                                  SizedBox(height: 4.h),

                                  Text(
                                    'Smart Vehicle Insight',

                                    style: TextStyle(
                                      color: Colors
                                          .white60,

                                      fontSize: 14.sp,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),

                          /// RIGHT
                          Column(
                            crossAxisAlignment:
                                CrossAxisAlignment
                                    .end,

                            mainAxisAlignment:
                                MainAxisAlignment
                                    .center,

                            children: [

                              Text(
                                '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',

                                style: TextStyle(
                                  color: Colors.white,

                                  fontSize: 28.sp,

                                  fontWeight:
                                      FontWeight.bold,
                                ),
                              ),

                              SizedBox(height: 4.h),

                              Text(
                                '${now.day}/${now.month}/${now.year}',

                                style: TextStyle(
                                  color:
                                      Colors.white60,

                                  fontSize: 13.sp,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 24.h),

                    /// =====================
                    /// MAIN CONTENT
                    /// =====================
                    Expanded(
                      child: SingleChildScrollView(
                        physics:
                            const BouncingScrollPhysics(),

                        child: Column(
                          children: [

                            /// =================
                            /// HERO CARD
                            /// =================
                            Container(
                              width: double.infinity,

                              padding: EdgeInsets.all(
                                28.w,
                              ),

                              decoration: BoxDecoration(
                                borderRadius:
                                    BorderRadius.circular(
                                      40.r,
                                    ),

                                color: Colors.white
                                    .withOpacity(0.05),

                                border: Border.all(
                                  color: Colors.white
                                      .withOpacity(
                                        0.08,
                                      ),
                                ),

                                boxShadow: [
                                  BoxShadow(
                                    color: accent
                                        .withOpacity(
                                          0.12,
                                        ),

                                    blurRadius: 30,
                                  ),
                                ],
                              ),

                              child: Row(
                                children: [

                                  /// VEHICLE IMAGE
                                  Container(
                                    width: 260.w,
                                    height: 160.h,

                                    decoration: BoxDecoration(
                                      boxShadow: [
                                        BoxShadow(
                                          color: accent
                                              .withOpacity(
                                                0.35,
                                              ),

                                          blurRadius: 40,
                                        ),
                                      ],
                                    ),

                                    child: Image.asset(
                                      "assets/images/veloz.png",

                                      fit: BoxFit.contain,
                                    ),
                                  ),

                                  SizedBox(width: 30.w),

                                  /// INFO
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment
                                              .start,

                                      children: [

                                        Text(
                                          'Toyota Veloz 2026',

                                          style: TextStyle(
                                            color:
                                                Colors.white,

                                            fontSize: 34.sp,

                                            fontWeight:
                                                FontWeight
                                                    .bold,
                                          ),
                                        ),

                                        SizedBox(
                                          height: 10.h,
                                        ),

                                        Text(
                                          'Connected Smart Vehicle',

                                          style: TextStyle(
                                            color:
                                                Colors.white70,

                                            fontSize: 18.sp,
                                          ),
                                        ),

                                        SizedBox(
                                          height: 20.h,
                                        ),

                                        Wrap(
                                          spacing: 12.w,
                                          runSpacing: 12.h,

                                          children: [

                                            _statusChip(
                                              Icons.bluetooth,
                                              'Bluetooth Connected',
                                              accent,
                                            ),

                                            _statusChip(
                                              Icons.gps_fixed,
                                              'GPS Synced',
                                              accent,
                                            ),

                                            _statusChip(
                                              Icons.wifi,
                                              'ADB Wireless',
                                              accent,
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            SizedBox(height: 24.h),

                            /// =================
                            /// GRID
                            /// =================
                            GridView(
                              shrinkWrap: true,

                              physics:
                                  const NeverScrollableScrollPhysics(),

                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,

                                    crossAxisSpacing:
                                        24.w,

                                    mainAxisSpacing:
                                        24.h,

                                    childAspectRatio:
                                        1.6,
                                  ),

                              children: [

                                /// DRIVING ANALYTICS
                                _glassCard(
                                  title:
                                      'Driving Analytics',

                                  accent: accent,

                                  child: Column(
                                    children: [

                                      _analyticsTile(
                                        'Driving Score',
                                        '92',
                                        Icons.speed,
                                        accent,
                                      ),

                                      SizedBox(
                                        height: 18.h,
                                      ),

                                      _analyticsTile(
                                        'Fuel Efficiency',
                                        '18.4 km/l',
                                        Icons.local_gas_station,
                                        accent,
                                      ),

                                      SizedBox(
                                        height: 18.h,
                                      ),

                                      _analyticsTile(
                                        'Distance Today',
                                        '42 km',
                                        Icons.route,
                                        accent,
                                      ),
                                    ],
                                  ),
                                ),

                                /// SMART DETECTION
                                _glassCard(
                                  title:
                                      'Smart Detection',

                                  accent: accent,

                                  child: Column(
                                    children: [

                                      _detectionTile(
                                        'Pothole Detection',
                                        'Active',
                                        true,
                                        accent,
                                      ),

                                      SizedBox(
                                        height: 18.h,
                                      ),

                                      _detectionTile(
                                        'Driver Monitoring',
                                        'Active',
                                        true,
                                        accent,
                                      ),

                                      SizedBox(
                                        height: 18.h,
                                      ),

                                      _detectionTile(
                                        'Fatigue Risk',
                                        'Low',
                                        true,
                                        accent,
                                      ),
                                    ],
                                  ),
                                ),

                                /// CONNECTIVITY
                                _glassCard(
                                  title:
                                      'Connectivity',

                                  accent: accent,

                                  child: Column(
                                    children: [

                                      _connectivityTile(
                                        Icons.bluetooth,
                                        'Bluetooth Connected',
                                        accent,
                                      ),

                                      SizedBox(
                                        height: 16.h,
                                      ),

                                      _connectivityTile(
                                        Icons.phone_android,
                                        'Android Cast Ready',
                                        accent,
                                      ),

                                      SizedBox(
                                        height: 16.h,
                                      ),

                                      _connectivityTile(
                                        Icons.usb,
                                        'ADB Wireless Connected',
                                        accent,
                                      ),
                                    ],
                                  ),
                                ),

                                /// SYSTEM INFO
                                _glassCard(
                                  title:
                                      'System Information',

                                  accent: accent,

                                  child: Column(
                                    children: [

                                      _systemTile(
                                        'Platform',
                                        'Flutter Linux',
                                      ),

                                      SizedBox(
                                        height: 14.h,
                                      ),

                                      _systemTile(
                                        'Device',
                                        'Jetson Orin Nano',
                                      ),

                                      SizedBox(
                                        height: 14.h,
                                      ),

                                      _systemTile(
                                        'Media Engine',
                                        'Ready',
                                      ),

                                      SizedBox(
                                        height: 14.h,
                                      ),

                                      _systemTile(
                                        'GPU Rendering',
                                        'Active',
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            SizedBox(height: 24.h),

                            /// =================
                            /// BOTTOM PANELS
                            /// =================
                            Row(
                              children: [

                                /// NOW PLAYING
                                Expanded(
                                  child: _glassCard(
                                    title:
                                        'Now Playing',

                                    accent: accent,

                                    child: Row(
                                      children: [

                                        Container(
                                          width: 90.w,
                                          height: 90.w,

                                          decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(
                                                  24.r,
                                                ),

                                            image:
                                                const DecorationImage(
                                                  image: AssetImage(
                                                    "assets/images/weekend.png",
                                                  ),

                                                  fit:
                                                      BoxFit.cover,
                                                ),
                                          ),
                                        ),

                                        SizedBox(
                                          width: 18.w,
                                        ),

                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment
                                                    .start,

                                            mainAxisAlignment:
                                                MainAxisAlignment
                                                    .center,

                                            children: [

                                              Text(
                                                'Blinding Lights',

                                                style: TextStyle(
                                                  color:
                                                      Colors.white,

                                                  fontSize:
                                                      22.sp,

                                                  fontWeight:
                                                      FontWeight.bold,
                                                ),
                                              ),

                                              SizedBox(
                                                height:
                                                    8.h,
                                              ),

                                              Text(
                                                'The Weeknd',

                                                style: TextStyle(
                                                  color:
                                                      Colors.white70,

                                                  fontSize:
                                                      16.sp,
                                                ),
                                              ),

                                              SizedBox(
                                                height:
                                                    12.h,
                                              ),

                                              Text(
                                                'Spotify Connect',

                                                style: TextStyle(
                                                  color:
                                                      accent,

                                                  fontSize:
                                                      14.sp,

                                                  fontWeight:
                                                      FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                SizedBox(width: 24.w),

                                /// NAVIGATION
                                Expanded(
                                  child: _glassCard(
                                    title:
                                        'Navigation Insight',

                                    accent: accent,

                                    child: Column(
                                      children: [

                                        _navigationTile(
                                          'Road Condition',
                                          'Moderate',
                                          accent,
                                        ),

                                        SizedBox(
                                          height: 16.h,
                                        ),

                                        _navigationTile(
                                          'Pothole Nearby',
                                          'Detected',
                                          accent,
                                        ),

                                        SizedBox(
                                          height: 16.h,
                                        ),

                                        _navigationTile(
                                          'ETA',
                                          '18 Minutes',
                                          accent,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            SizedBox(height: 30.h),
                          ],
                        ),
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
  }

  /// ===============================
  /// GLASS CARD
  /// ===============================
  Widget _glassCard({
  required String title,
  required Widget child,
  required Color accent,
}) {

  return Container(
    padding: EdgeInsets.all(24.w),

    decoration: BoxDecoration(
      borderRadius:
          BorderRadius.circular(34.r),

      color: Colors.white.withOpacity(
        0.05,
      ),

      border: Border.all(
        color: Colors.white.withOpacity(
          0.08,
        ),
      ),
    ),

    child: Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,

      mainAxisSize: MainAxisSize.min,

      children: [

        Row(
          children: [

            Container(
              width: 10.w,
              height: 10.w,

              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent,
              ),
            ),

            SizedBox(width: 10.w),

            Text(
              title,

              style: TextStyle(
                color: Colors.white,

                fontSize: 22.sp,

                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),

        SizedBox(height: 24.h),

        child,
      ],
    ),
  );
}
  /// ===============================
  /// STATUS CHIP
  /// ===============================
  Widget _statusChip(
    IconData icon,
    String title,
    Color accent,
  ) {

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 16.w,
        vertical: 12.h,
      ),

      decoration: BoxDecoration(
        borderRadius:
            BorderRadius.circular(20.r),

        color: Colors.white.withOpacity(
          0.06,
        ),
      ),

      child: Row(
        mainAxisSize: MainAxisSize.min,

        children: [

          Icon(
            icon,
            color: accent,
            size: 18.sp,
          ),

          SizedBox(width: 8.w),

          Text(
            title,

            style: TextStyle(
              color: Colors.white,

              fontSize: 14.sp,

              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// ===============================
  /// ANALYTICS TILE
  /// ===============================
  Widget _analyticsTile(
    String title,
    String value,
    IconData icon,
    Color accent,
  ) {

    return Row(
      children: [

        Container(
          width: 54.w,
          height: 54.w,

          decoration: BoxDecoration(
            shape: BoxShape.circle,

            color: accent.withOpacity(
              0.18,
            ),
          ),

          child: Icon(
            icon,
            color: accent,
            size: 26.sp,
          ),
        ),

        SizedBox(width: 16.w),

        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,

            children: [

              Text(
                title,

                style: TextStyle(
                  color: Colors.white70,

                  fontSize: 15.sp,
                ),
              ),

              SizedBox(height: 4.h),

              Text(
                value,

                style: TextStyle(
                  color: Colors.white,

                  fontSize: 22.sp,

                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// ===============================
  /// DETECTION TILE
  /// ===============================
  Widget _detectionTile(
    String title,
    String value,
    bool active,
    Color accent,
  ) {

    return Row(
      children: [

        Container(
          width: 14.w,
          height: 14.w,

          decoration: BoxDecoration(
            shape: BoxShape.circle,

            color: active
                ? Colors.greenAccent
                : Colors.redAccent,

            boxShadow: [
              BoxShadow(
                color: active
                    ? Colors.greenAccent
                    : Colors.redAccent,

                blurRadius: 12,
              ),
            ],
          ),
        ),

        SizedBox(width: 16.w),

        Expanded(
          child: Text(
            title,

            style: TextStyle(
              color: Colors.white,

              fontSize: 16.sp,

              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        Text(
          value,

          style: TextStyle(
            color: accent,

            fontSize: 16.sp,

            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  /// ===============================
  /// CONNECTIVITY TILE
  /// ===============================
  Widget _connectivityTile(
    IconData icon,
    String title,
    Color accent,
  ) {

    return Row(
      children: [

        Icon(
          icon,
          color: accent,
          size: 24.sp,
        ),

        SizedBox(width: 14.w),

        Expanded(
          child: Text(
            title,

            style: TextStyle(
              color: Colors.white,

              fontSize: 16.sp,

              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  /// ===============================
  /// SYSTEM TILE
  /// ===============================
  Widget _systemTile(
    String title,
    String value,
  ) {

    return Row(
      mainAxisAlignment:
          MainAxisAlignment.spaceBetween,

      children: [

        Text(
          title,

          style: TextStyle(
            color: Colors.white70,

            fontSize: 15.sp,
          ),
        ),

        Text(
          value,

          style: TextStyle(
            color: Colors.white,

            fontSize: 16.sp,

            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  /// ===============================
  /// NAVIGATION TILE
  /// ===============================
  Widget _navigationTile(
    String title,
    String value,
    Color accent,
  ) {

    return Row(
      mainAxisAlignment:
          MainAxisAlignment.spaceBetween,

      children: [

        Text(
          title,

          style: TextStyle(
            color: Colors.white70,

            fontSize: 15.sp,
          ),
        ),

        Text(
          value,

          style: TextStyle(
            color: accent,

            fontSize: 16.sp,

            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}