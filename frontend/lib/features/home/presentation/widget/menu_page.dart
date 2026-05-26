import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:frontend/core/themes/car_theme.dart';

class MenuPage extends StatefulWidget {
  const MenuPage({super.key});

  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {
  late Timer timer;

  DateTime now = DateTime.now();

  int selectedIndex = 0;

  @override
  void initState() {
    super.initState();

    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        now = DateTime.now();
      });
    });
  }

  @override
  void dispose() {
    timer.cancel();

    super.dispose();
  }

  /// ===============================
  /// ACCENT COLOR
  /// ===============================
  Color getAccentColor(CarThemeType type, CarThemeData theme) {
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
    final currentTheme = CarThemes.currentTheme.value;

    final theme = CarThemes.getTheme(currentTheme);

    final accent = getAccentColor(currentTheme, theme);

    final menus = [
      {
        "title": "Music",
        "subtitle": "Media Playback Hub",
        "icon": Icons.music_note,
      },

      {"title": "Radio", "subtitle": "Internet Streaming", "icon": Icons.radio},

      {
        "title": "USB Connect",
        "subtitle": "USB Audio & Media",
        "icon": Icons.usb,
      },

      {
        "title": "Bluetooth",
        "subtitle": "Wireless Audio",
        "icon": Icons.bluetooth,
      },

      {
        "title": "Screen Cast",
        "subtitle": "Android Mirroring",
        "icon": Icons.cast_connected,
      },

      {
        "title": "Navigation",
        "subtitle": "Smart Route System",
        "icon": Icons.map,
      },

      {
        "title": "Car Info",
        "subtitle": "Vehicle Analytics",
        "icon": Icons.directions_car,
      },

      {
        "title": "Settings",
        "subtitle": "OEM Configuration",
        "icon": Icons.settings,
      },

      {
        "title": "Tutorial",
        "subtitle": "User Guidance",
        "icon": Icons.play_circle_fill,
      },

      {
        "title": "System Monitor",
        "subtitle": "Linux Performance",
        "icon": Icons.memory,
      },
    ];

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
              top: 80.h,

              child: Container(
                width: 420.w,
                height: 420.w,

                decoration: BoxDecoration(
                  shape: BoxShape.circle,

                  color: accent.withValues(alpha: 0.16),
                ),
              ),
            ),

            Positioned(
              left: -80.w,
              bottom: -50.h,

              child: Container(
                width: 320.w,
                height: 320.w,

                decoration: BoxDecoration(
                  shape: BoxShape.circle,

                  color: accent.withValues(alpha: 0.08),
                ),
              ),
            ),

            /// =========================
            /// BLUR
            /// =========================
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),

              child: Container(color: Colors.black.withValues(alpha: 0.12)),
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

                      padding: EdgeInsets.symmetric(horizontal: 28.w),

                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30.r),

                        color: Colors.white.withValues(alpha: 0.05),

                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),

                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,

                        children: [
                          /// LEFT
                          Row(
                            children: [
                              GestureDetector(
                                onTap: () {
                                  Navigator.pop(context);
                                },

                                child: Container(
                                  width: 52.w,
                                  height: 52.w,

                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,

                                    color: Colors.white.withValues(alpha: 0.06),

                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.08,
                                      ),
                                    ),
                                  ),

                                  child: Icon(
                                    Icons.arrow_back_ios_new,

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
                                  shape: BoxShape.circle,

                                  color: accent,
                                ),

                                child: Icon(
                                  Icons.apps,

                                  color: Colors.white,

                                  size: 28.sp,
                                ),
                              ),

                              SizedBox(width: 16.w),

                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,

                                crossAxisAlignment: CrossAxisAlignment.start,

                                children: [
                                  Text(
                                    'Smart Launcher',

                                    style: TextStyle(
                                      color: Colors.white,

                                      fontSize: 24.sp,

                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),

                                  SizedBox(height: 4.h),

                                  Text(
                                    'OEM Infotainment Hub',

                                    style: TextStyle(
                                      color: Colors.white60,

                                      fontSize: 14.sp,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),

                          /// RIGHT
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,

                            mainAxisAlignment: MainAxisAlignment.center,

                            children: [
                              Text(
                                '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',

                                style: TextStyle(
                                  color: Colors.white,

                                  fontSize: 28.sp,

                                  fontWeight: FontWeight.bold,
                                ),
                              ),

                              SizedBox(height: 4.h),

                              Text(
                                '${now.day}/${now.month}/${now.year}',

                                style: TextStyle(
                                  color: Colors.white60,

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
                    /// HERO CARD
                    /// =====================
                    Container(
                      width: double.infinity,

                      padding: EdgeInsets.all(28.w),

                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(40.r),

                        color: Colors.white.withValues(alpha: 0.05),

                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),

                        boxShadow: [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.14),

                            blurRadius: 30,
                          ),
                        ],
                      ),

                      child: Row(
                        children: [
                          /// LEFT
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,

                              children: [
                                Text(
                                  'Good Evening, Febrian',

                                  style: TextStyle(
                                    color: Colors.white,

                                    fontSize: 36.sp,

                                    fontWeight: FontWeight.bold,
                                  ),
                                ),

                                SizedBox(height: 12.h),

                                Text(
                                  'Toyota Veloz Connected • Smart Vehicle Ready',

                                  style: TextStyle(
                                    color: Colors.white70,

                                    fontSize: 18.sp,
                                  ),
                                ),

                                SizedBox(height: 24.h),

                                Wrap(
                                  spacing: 14.w,

                                  runSpacing: 14.h,

                                  children: [
                                    _statusChip(
                                      Icons.music_note,

                                      'Spotify Playing',

                                      accent,
                                    ),

                                    _statusChip(
                                      Icons.gps_fixed,

                                      'GPS Synced',

                                      accent,
                                    ),

                                    _statusChip(
                                      Icons.bluetooth,

                                      'Bluetooth Ready',

                                      accent,
                                    ),

                                    _statusChip(
                                      Icons.shield,

                                      'Road Stable',

                                      accent,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          SizedBox(width: 24.w),

                          /// VEHICLE IMAGE
                          Container(
                            width: 320.w,
                            height: 180.h,

                            decoration: BoxDecoration(
                              boxShadow: [
                                BoxShadow(
                                  color: accent.withValues(alpha: 0.35),

                                  blurRadius: 50,
                                ),
                              ],
                            ),

                            child: Image.asset(
                              "assets/images/veloz.png",

                              fit: BoxFit.contain,
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 24.h),

                    /// =====================
                    /// STATUS STRIP
                    /// =====================
                    Row(
                      children: [
                        _quickStatus(
                          'Fuel',
                          '78%',
                          Icons.local_gas_station,
                          accent,
                        ),

                        SizedBox(width: 18.w),

                        _quickStatus(
                          'Battery',
                          'Healthy',
                          Icons.battery_charging_full,
                          accent,
                        ),

                        SizedBox(width: 18.w),

                        _quickStatus(
                          'Bluetooth',
                          'Connected',
                          Icons.bluetooth,
                          accent,
                        ),

                        SizedBox(width: 18.w),

                        _quickStatus(
                          'Temperature',
                          '24°C',
                          Icons.device_thermostat,
                          accent,
                        ),
                      ],
                    ),

                    SizedBox(height: 24.h),

                    /// =====================
                    /// MAIN GRID
                    /// =====================
                    Expanded(
                      child: GridView.builder(
                        physics: const BouncingScrollPhysics(),

                        itemCount: menus.length,

                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 5,

                          crossAxisSpacing: 24.w,

                          mainAxisSpacing: 24.h,

                          childAspectRatio: 1.15,
                        ),

                        itemBuilder: (context, index) {
                          final item = menus[index];

                          final active = selectedIndex == index;

                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                selectedIndex = index;
                              });

                              /// NAVIGATION HERE
                            },

                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 250),

                              padding: EdgeInsets.all(22.w),

                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(34.r),

                                color: active
                                    ? accent.withValues(alpha: 0.12)
                                    : Colors.white.withValues(alpha: 0.05),

                                border: Border.all(
                                  color: active
                                      ? accent.withValues(alpha: 0.35)
                                      : Colors.white.withValues(alpha: 0.08),
                                ),

                                boxShadow: active
                                    ? [
                                        BoxShadow(
                                          color: accent.withValues(alpha: 0.25),

                                          blurRadius: 24,
                                        ),
                                      ]
                                    : [],
                              ),

                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,

                                children: [
                                  /// ICON
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 250),

                                    width: 72.w,

                                    height: 72.w,

                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,

                                      color: active
                                          ? accent.withValues(alpha: 0.18)
                                          : Colors.white.withValues(
                                              alpha: 0.08,
                                            ),
                                    ),

                                    child: Icon(
                                      item["icon"] as IconData,

                                      color: active ? accent : Colors.white,

                                      size: 34.sp,
                                    ),
                                  ),

                                  const Spacer(),

                                  /// TITLE
                                  Text(
                                    item["title"] as String,

                                    style: TextStyle(
                                      color: Colors.white,

                                      fontSize: 22.sp,

                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),

                                  SizedBox(height: 8.h),

                                  /// SUBTITLE
                                  Text(
                                    item["subtitle"] as String,

                                    style: TextStyle(
                                      color: Colors.white60,

                                      fontSize: 14.sp,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    SizedBox(height: 24.h),

                    /// =====================
                    /// MINI PLAYER
                    /// =====================
                    Container(
                      height: 110.h,

                      padding: EdgeInsets.symmetric(horizontal: 24.w),

                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(34.r),

                        color: Colors.white.withValues(alpha: 0.05),

                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),

                      child: Row(
                        children: [
                          /// ALBUM
                          Container(
                            width: 70.w,
                            height: 70.w,

                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(22.r),

                              image: const DecorationImage(
                                image: AssetImage("assets/images/weekend.png"),

                                fit: BoxFit.cover,
                              ),
                            ),
                          ),

                          SizedBox(width: 18.w),

                          /// INFO
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,

                              crossAxisAlignment: CrossAxisAlignment.start,

                              children: [
                                Text(
                                  'Blinding Lights',

                                  style: TextStyle(
                                    color: Colors.white,

                                    fontSize: 22.sp,

                                    fontWeight: FontWeight.bold,
                                  ),
                                ),

                                SizedBox(height: 6.h),

                                Text(
                                  'The Weeknd',

                                  style: TextStyle(
                                    color: Colors.white60,

                                    fontSize: 15.sp,
                                  ),
                                ),

                                SizedBox(height: 14.h),

                                ClipRRect(
                                  borderRadius: BorderRadius.circular(30.r),

                                  child: LinearProgressIndicator(
                                    value: 0.62,

                                    minHeight: 6.h,

                                    backgroundColor: Colors.white12,

                                    valueColor: AlwaysStoppedAnimation(accent),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          SizedBox(width: 24.w),

                          /// BUTTONS
                          Row(
                            children: [
                              _playerButton(Icons.skip_previous, accent),

                              SizedBox(width: 14.w),

                              _playerButton(Icons.pause, accent, active: true),

                              SizedBox(width: 14.w),

                              _playerButton(Icons.skip_next, accent),
                            ],
                          ),
                        ],
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
  /// STATUS CHIP
  /// ===============================
  Widget _statusChip(IconData icon, String title, Color accent) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),

      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20.r),

        color: Colors.white.withValues(alpha: 0.06),
      ),

      child: Row(
        mainAxisSize: MainAxisSize.min,

        children: [
          Icon(icon, color: accent, size: 18.sp),

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
  /// QUICK STATUS
  /// ===============================
  Widget _quickStatus(String title, String value, IconData icon, Color accent) {
    return Expanded(
      child: Container(
        height: 88.h,

        padding: EdgeInsets.symmetric(horizontal: 20.w),

        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28.r),

          color: Colors.white.withValues(alpha: 0.05),

          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),

        child: Row(
          children: [
            Container(
              width: 52.w,
              height: 52.w,

              decoration: BoxDecoration(
                shape: BoxShape.circle,

                color: accent.withValues(alpha: 0.18),
              ),

              child: Icon(icon, color: accent, size: 24.sp),
            ),

            SizedBox(width: 14.w),

            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,

                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  Text(
                    title,

                    style: TextStyle(color: Colors.white60, fontSize: 13.sp),
                  ),

                  SizedBox(height: 4.h),

                  Text(
                    value,

                    overflow: TextOverflow.ellipsis,

                    style: TextStyle(
                      color: Colors.white,

                      fontSize: 18.sp,

                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ===============================
  /// PLAYER BUTTON
  /// ===============================
  Widget _playerButton(IconData icon, Color accent, {bool active = false}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),

      width: 58.w,
      height: 58.w,

      decoration: BoxDecoration(
        shape: BoxShape.circle,

        color: active ? accent : Colors.white.withValues(alpha: 0.08),

        boxShadow: active
            ? [BoxShadow(color: accent.withValues(alpha: 0.35), blurRadius: 18)]
            : [],
      ),

      child: Icon(
        icon,

        color: active ? Colors.black : Colors.white,

        size: 28.sp,
      ),
    );
  }
}
