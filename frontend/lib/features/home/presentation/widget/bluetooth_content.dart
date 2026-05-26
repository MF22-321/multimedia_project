import 'dart:async';

import 'package:dbus/dbus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:frontend/core/localization/app_strings.dart';
import 'package:frontend/core/utils/app_logger.dart';

import '../../../../core/themes/car_theme.dart';

class BluetoothContent extends StatefulWidget {
  const BluetoothContent({super.key});

  @override
  State<BluetoothContent> createState() => _BluetoothPageState();
}

class _BluetoothPageState extends State<BluetoothContent>
    with TickerProviderStateMixin {
  /// =========================
  /// DBUS
  /// =========================
  final DBusClient client = DBusClient.system();

  /// =========================
  /// DEVICE LIST
  /// =========================
  List<Map<String, dynamic>> devices = [];

  bool isScanning = false;

  Timer? scanTimer;

  late AnimationController pulseController;

  @override
  void initState() {
    super.initState();

    pulseController = AnimationController(
      vsync: this,

      duration: const Duration(seconds: 2),
    )..repeat();

    startScan();
  }

  /// =========================
  /// START SCAN
  /// =========================
  Future<void> startScan() async {
    setState(() {
      isScanning = true;
    });

    AppLogger.info('\n========== BLUETOOTH SCAN ==========');

    try {
      final adapter = DBusRemoteObject(
        client,

        name: 'org.bluez',

        path: DBusObjectPath('/org/bluez/hci0'),
      );

      AppLogger.info('ADAPTER READY');

      /// START DISCOVERY
      await adapter.callMethod('org.bluez.Adapter1', 'StartDiscovery', []);

      AppLogger.info('DISCOVERY STARTED');

      /// FETCH DEVICE
      await fetchDevices();

      /// AUTO REFRESH
      scanTimer?.cancel();

      scanTimer = Timer.periodic(const Duration(seconds: 4), (_) {
        AppLogger.info('REFRESH DEVICE...');

        fetchDevices();
      });
    } catch (e) {
      AppLogger.error('SCAN ERROR => $e');
    }
  }

  /// =========================
  /// FETCH DEVICES
  /// =========================
  Future<void> fetchDevices() async {
    try {
      final objectManager = DBusRemoteObject(
        client,

        name: 'org.bluez',

        path: DBusObjectPath('/'),
      );

      final response = await objectManager.callMethod(
        'org.freedesktop.DBus.ObjectManager',

        'GetManagedObjects',

        [],
      );

      final result = response.returnValues.first;

      final objects = result.toNative();

      final List<Map<String, dynamic>> foundDevices = [];

      (objects as Map).forEach((path, interfaces) {
        if (interfaces.containsKey('org.bluez.Device1')) {
          final props = interfaces['org.bluez.Device1'];

          final name = props['Name'] ?? AppStrings.unknownDevice;

          final connected = props['Connected'] ?? false;

          final paired = props['Paired'] ?? false;

          final rssi = props['RSSI'] ?? 0;

          foundDevices.add({
            'name': name,

            'connected': connected,

            'paired': paired,

            'rssi': rssi,

            'path': path.value,
          });
        }
      });

      setState(() {
        devices = foundDevices;
      });
    } catch (e) {
      debugPrint('FETCH ERROR => $e');
    }
  }

  /// =========================
  /// CONNECT DEVICE
  /// =========================
  Future<void> connectDevice(String path) async {
    try {
      final device = DBusRemoteObject(
        client,

        name: 'org.bluez',

        path: DBusObjectPath(path),
      );

      await device.callMethod('org.bluez.Device1', 'Connect', []);

      await fetchDevices();
    } catch (e) {
      debugPrint('CONNECT ERROR => $e');
    }
  }

  /// =========================
  /// DISCONNECT DEVICE
  /// =========================
  Future<void> disconnectDevice(String path) async {
    try {
      final device = DBusRemoteObject(
        client,

        name: 'org.bluez',

        path: DBusObjectPath(path),
      );

      await device.callMethod('org.bluez.Device1', 'Disconnect', []);

      await fetchDevices();
    } catch (e) {
      debugPrint('DISCONNECT ERROR => $e');
    }
  }

  @override
  void dispose() {
    pulseController.dispose();

    scanTimer?.cancel();

    client.close();

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
                                Icons.bluetooth,

                                color: Colors.white,

                                size: 30.sp,
                              ),
                            ),

                            SizedBox(width: 18.w),

                            Text(
                              'Bluetooth',

                              style: TextStyle(
                                color: Colors.white,

                                fontSize: 36.sp,

                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: 32.h),

                        /// =========================
                        /// SCAN STATUS
                        /// =========================
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

                                  color: accentColor,
                                ),
                              ),
                            ),

                            SizedBox(width: 12.w),

                            Text(
                              isScanning
                                  ? AppStrings.scanningDevices
                                  : AppStrings.bluetoothIdle,

                              style: TextStyle(
                                color: Colors.white,

                                fontSize: 18.sp,

                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: 28.h),

                        /// =========================
                        /// DEVICE LIST
                        /// =========================
                        Expanded(
                          child: ListView.builder(
                            physics: const BouncingScrollPhysics(),

                            itemCount: devices.length,

                            itemBuilder: (context, index) {
                              final device = devices[index];

                              final connected = device['connected'];

                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 250),

                                margin: EdgeInsets.only(bottom: 18.h),

                                padding: EdgeInsets.all(20.w),

                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(28.r),

                                  color: connected
                                      ? accentColor.withValues(alpha: 0.12)
                                      : Colors.white.withValues(alpha: 0.04),

                                  border: Border.all(
                                    color: connected
                                        ? accentColor.withValues(alpha: 0.3)
                                        : Colors.white.withValues(alpha: 0.05),
                                  ),
                                ),

                                child: Row(
                                  children: [
                                    /// ICON
                                    Container(
                                      width: 68.w,

                                      height: 68.w,

                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,

                                        color: accentColor.withValues(
                                          alpha: 0.15,
                                        ),
                                      ),

                                      child: Icon(
                                        Icons.bluetooth_audio,

                                        color: accentColor,

                                        size: 34.sp,
                                      ),
                                    ),

                                    SizedBox(width: 16.w),

                                    /// INFO
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,

                                        children: [
                                          Text(
                                            AppStrings.bluetooth,

                                            style: TextStyle(
                                              color: Colors.white,

                                              fontSize: 22.sp,

                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),

                                          SizedBox(height: 6.h),

                                          Row(
                                            children: [
                                              Text(
                                                connected
                                                    ? AppStrings.connected
                                                    : AppStrings.available,

                                                style: TextStyle(
                                                  color: connected
                                                      ? accentColor
                                                      : Colors.white.withValues(
                                                          alpha: 0.5,
                                                        ),

                                                  fontSize: 15.sp,
                                                ),
                                              ),

                                              SizedBox(width: 14.w),

                                              Text(
                                                'RSSI ${device['rssi']}',

                                                style: TextStyle(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.45),

                                                  fontSize: 14.sp,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),

                                    /// BUTTON
                                    GestureDetector(
                                      onTap: () {
                                        if (connected) {
                                          disconnectDevice(device['path']);
                                        } else {
                                          connectDevice(device['path']);
                                        }
                                      },

                                      child: AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 250,
                                        ),

                                        padding: EdgeInsets.symmetric(
                                          horizontal: 22.w,

                                          vertical: 12.h,
                                        ),

                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            16.r,
                                          ),

                                          color: connected
                                              ? Colors.redAccent.withValues(
                                                  alpha: 0.18,
                                                )
                                              : accentColor,

                                          boxShadow: [
                                            BoxShadow(
                                              color: connected
                                                  ? Colors.redAccent.withValues(
                                                      alpha: 0.25,
                                                    )
                                                  : accentColor.withValues(
                                                      alpha: 0.35,
                                                    ),

                                              blurRadius: 18,
                                            ),
                                          ],
                                        ),

                                        child: Text(
                                            connected
                                                ? AppStrings.disconnect
                                                : AppStrings.connect,
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
                          /// BLUETOOTH ICON
                          AnimatedBuilder(
                            animation: pulseController,

                            builder: (context, child) {
                              return Transform.scale(
                                scale: 1 + (pulseController.value * 0.08),

                                child: Container(
                                  width: 220.w,

                                  height: 220.w,

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
                                    Icons.bluetooth,

                                    color: accentColor,

                                    size: 120.sp,
                                  ),
                                ),
                              );
                            },
                          ),

                          SizedBox(height: 36.h),

                          Text(
                            AppStrings.bluetoothConnection,

                            style: TextStyle(
                              color: Colors.white,

                              fontSize: 36.sp,

                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          SizedBox(height: 14.h),

                          Text(
                            AppStrings.pairYourSmartphone,

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
