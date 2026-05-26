import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:frontend/core/localization/app_strings.dart';
import 'package:frontend/core/utils/app_logger.dart';

import '../../../../core/themes/car_theme.dart';

class ScreenCastContent extends StatefulWidget {
  const ScreenCastContent({super.key});

  @override
  State<ScreenCastContent> createState() => _ScreenCastPageState();
}

class _ScreenCastPageState extends State<ScreenCastContent>
    with TickerProviderStateMixin {
  /// =========================
  /// PROCESS
  /// =========================
  Process? scrcpyProcess;

  bool isConnected = false;

  bool isLaunching = false;

  String status = AppStrings.noDeviceConnected;

  List<String> devices = [];

  late AnimationController pulseController;

  @override
  void initState() {
    super.initState();

    pulseController = AnimationController(
      vsync: this,

      duration: const Duration(seconds: 2),
    )..repeat();

    fetchDevices();
  }

  /// =========================
  /// GET ADB DEVICES
  /// =========================
  Future<void> fetchDevices() async {
    try {
      final result = await Process.run('/usr/bin/adb', ['devices']);

      final output = result.stdout.toString();

      AppLogger.info('\n========== ADB DEVICES ==========');

      AppLogger.info(output);

      final lines = output.split('\n');

      final List<String> found = [];

      for (final line in lines) {
        if (line.contains('\tdevice') && !line.startsWith('List')) {
          final serial = line.split('\t')[0];

          found.add(serial);

          AppLogger.info('DEVICE FOUND => $serial');
        }
      }

      setState(() {
        devices = found;
      });
    } catch (e) {
      AppLogger.error('ADB ERROR => $e');
    }
  }

  /// =========================
  /// START SCRCPY
  /// =========================
  Future<void> startScrcpy(String serial) async {
    try {
      setState(() {
        isLaunching = true;

        status = AppStrings.launchingScreenCast;
      });

      AppLogger.info('\n========== SCRCPY START ==========');

      AppLogger.info('DEVICE => $serial');

      scrcpyProcess = await Process.start(
        '/usr/local/bin/scrcpy',
        [
          '-s',
          serial,

          '--max-size',
          '1400',

          '--max-fps',
          '60',

          '--video-bit-rate',
          '8M',

          '--stay-awake',

          /// RIGHT PANEL POSITION
          '--window-x',
          '2550',

          '--window-y',
          '180',

          '--window-title',
          'M-Toyota ${AppStrings.screenCast}',
        ],

        environment: {'PATH': '/usr/local/bin:/usr/bin:/bin'},
      );
      AppLogger.info('SCRCPY STARTED');

      scrcpyProcess?.stdout.transform(SystemEncoding().decoder).listen((event) {
        AppLogger.info('SCRCPY => $event');
      });

      scrcpyProcess?.stderr.transform(SystemEncoding().decoder).listen((event) {
        AppLogger.error('SCRCPY ERROR => $event');
      });

      setState(() {
        isConnected = true;

        isLaunching = false;

        status = AppStrings.connectedTo(serial);
      });
    } catch (e) {
      AppLogger.error('SCRCPY ERROR => $e');

      setState(() {
        isLaunching = false;

        status = AppStrings.connectionFailed;
      });
    }
  }

  /// =========================
  /// STOP SCRCPY
  /// =========================
  Future<void> stopScrcpy() async {
    try {
      scrcpyProcess?.kill();

      setState(() {
        isConnected = false;

        status = AppStrings.disconnected;
      });

      AppLogger.info('SCRCPY STOPPED');
    } catch (e) {
      AppLogger.error('STOP ERROR => $e');
    }
  }

  @override
  void dispose() {
    pulseController.dispose();

    scrcpyProcess?.kill();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentTheme = CarThemes.currentTheme.value;

    final theme = CarThemes.getTheme(currentTheme);

    final accentColor = currentTheme == CarThemeType.comfort
        ? const Color(0xFF6CB4FF)
        : theme.accentColor;

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

        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(24.w),

            child: Row(
              children: [
                /// =========================
                /// LEFT PANEL
                /// =========================
                Expanded(
                  flex: 3,

                  child: Container(
                    padding: EdgeInsets.all(24.w),

                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(40.r),

                      color: Colors.white.withValues(alpha: 0.05),

                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),

                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [
                        /// =========================
                        /// HEADER
                        /// =========================
                        Row(
                          children: [
                            /// BACK
                            GestureDetector(
                              onTap: () {
                                Navigator.pop(context);
                              },

                              child: Container(
                                width: 58.w,

                                height: 58.w,

                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,

                                  color: Colors.white.withValues(alpha: 0.06),
                                ),

                                child: Icon(
                                  Icons.arrow_back_ios_new,

                                  color: accentColor,

                                  size: 24.sp,
                                ),
                              ),
                            ),

                            SizedBox(width: 16.w),

                            /// ICON
                            Container(
                              width: 60.w,
                              height: 60.w,

                              decoration: BoxDecoration(
                                shape: BoxShape.circle,

                                color: accentColor,

                                boxShadow: [
                                  BoxShadow(
                                    color: accentColor.withValues(alpha: 0.45),

                                    blurRadius: 20,
                                  ),
                                ],
                              ),

                              child: Icon(
                                Icons.cast,

                                color: Colors.white,

                                size: 30.sp,
                              ),
                            ),

                            SizedBox(width: 18.w),

                            Text(
                              AppStrings.screenCast,

                              style: TextStyle(
                                color: Colors.white,

                                fontSize: 36.sp,

                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: 30.h),

                        /// STATUS
                        Row(
                          children: [
                            ScaleTransition(
                              scale: Tween(begin: 0.8, end: 1.2).animate(
                                CurvedAnimation(
                                  parent: pulseController,

                                  curve: Curves.easeInOut,
                                ),
                              ),

                              child: Container(
                                width: 14.w,

                                height: 14.w,

                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,

                                  color: isConnected
                                      ? Colors.greenAccent
                                      : accentColor,
                                ),
                              ),
                            ),

                            SizedBox(width: 12.w),

                            Text(
                              status,

                              style: TextStyle(
                                color: Colors.white,

                                fontSize: 18.sp,

                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: 32.h),

                        /// DEVICE LIST
                        Expanded(
                          child: devices.isEmpty
                              ? Center(
                                  child: Text(
                                    AppStrings.noAndroidDeviceFound,

                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.5,
                                      ),

                                      fontSize: 18.sp,
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: devices.length,

                                  itemBuilder: (context, index) {
                                    final device = devices[index];

                                    return Container(
                                      margin: EdgeInsets.only(bottom: 18.h),

                                      padding: EdgeInsets.all(20.w),

                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(
                                          28.r,
                                        ),

                                        color: Colors.white.withValues(
                                          alpha: 0.04,
                                        ),

                                        border: Border.all(
                                          color: Colors.white.withValues(
                                            alpha: 0.06,
                                          ),
                                        ),
                                      ),

                                      child: Row(
                                        children: [
                                          /// PHONE ICON
                                          Container(
                                            width: 70.w,

                                            height: 70.w,

                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,

                                              color: accentColor.withValues(
                                                alpha: 0.15,
                                              ),
                                            ),

                                            child: Icon(
                                              Icons.smartphone,

                                              color: accentColor,

                                              size: 34.sp,
                                            ),
                                          ),

                                          SizedBox(width: 18.w),

                                          /// DEVICE INFO
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,

                                              children: [
                                                Text(
                                                  device,

                                                  style: TextStyle(
                                                    color: Colors.white,

                                                    fontSize: 22.sp,

                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),

                                                SizedBox(height: 6.h),

                                                Text(
                                                  AppStrings.androidDeviceReady,

                                                  style: TextStyle(
                                                    color: Colors.white
                                                        .withValues(alpha: 0.5),

                                                    fontSize: 15.sp,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),

                                          /// BUTTON
                                          GestureDetector(
                                            onTap: isConnected
                                                ? stopScrcpy
                                                : () {
                                                    startScrcpy(device);
                                                  },

                                            child: AnimatedContainer(
                                              duration: const Duration(
                                                milliseconds: 250,
                                              ),

                                              padding: EdgeInsets.symmetric(
                                                horizontal: 24.w,

                                                vertical: 12.h,
                                              ),

                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(16.r),

                                                color: isConnected
                                                    ? Colors.redAccent
                                                          .withValues(
                                                            alpha: 0.18,
                                                          )
                                                    : accentColor,

                                                boxShadow: [
                                                  BoxShadow(
                                                    color: isConnected
                                                        ? Colors.redAccent
                                                              .withValues(
                                                                alpha: 0.3,
                                                              )
                                                        : accentColor
                                                              .withValues(
                                                                alpha: 0.35,
                                                              ),

                                                    blurRadius: 18,
                                                  ),
                                                ],
                                              ),

                                              child: Text(
                                                isConnected
                                                    ? AppStrings.disconnect
                                                    : AppStrings.cast,
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 15.sp,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(width: 24.w),

                /// =========================
                /// RIGHT PANEL
                /// =========================
                Expanded(
                  flex: 4,

                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(40.r),

                      color: Colors.white.withValues(alpha: 0.05),

                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),

                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,

                        children: [
                          /// CAST ICON
                          AnimatedBuilder(
                            animation: pulseController,

                            builder: (context, child) {
                              return Transform.scale(
                                scale: 1 + (pulseController.value * 0.08),

                                child: Container(
                                  width: 240.w,

                                  height: 240.w,

                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,

                                    color: accentColor.withValues(alpha: 0.12),

                                    boxShadow: [
                                      BoxShadow(
                                        color: accentColor.withValues(
                                          alpha: 0.25,
                                        ),

                                        blurRadius: 45,
                                      ),
                                    ],
                                  ),

                                  child: Icon(
                                    Icons.cast,

                                    color: accentColor,

                                    size: 120.sp,
                                  ),
                                ),
                              );
                            },
                          ),

                          SizedBox(height: 36.h),

                          Text(
                            isConnected
                                ? AppStrings.screenCastingActive
                                : AppStrings.androidScreenCast,

                            style: TextStyle(
                              color: Colors.white,

                              fontSize: 36.sp,

                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          SizedBox(height: 14.h),

                          Text(
                            isConnected
                                ? AppStrings.smartphoneScreenMirroredLive
                                : AppStrings.connectAndroidDeviceWithAdb,

                            textAlign: TextAlign.center,

                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.55),

                              fontSize: 18.sp,

                              height: 1.7,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
