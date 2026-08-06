import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:frontend/core/navigation/app_routes.dart';
import 'package:frontend/core/navigation/driver_session.dart';
import 'package:frontend/core/services/faceid_api.dart';
import 'package:frontend/features/auth/presentation/widget/driver_avatar_card.dart';
import 'package:frontend/features/auth/presentation/widget/guest_button.dart';

import '../../../boot/presentation/widget/dotted_background.dart';

class DriverSelectPage extends StatefulWidget {
  const DriverSelectPage({
    super.key,
    this.loadDrivers = FaceIdApi.getDrivers,
    this.loadDriverStatus = FaceIdApi.getDriverStatus,
    this.detectionInterval = const Duration(milliseconds: 500),
  });

  final Future<List<String>> Function() loadDrivers;
  final Future<Map<String, dynamic>> Function() loadDriverStatus;
  final Duration detectionInterval;

  @override
  State<DriverSelectPage> createState() => _DriverSelectPageState();
}

class _DriverSelectPageState extends State<DriverSelectPage> {
  Timer? _timer;

  bool isNavigated = false;
  bool isLoading = true;
  bool _isDetecting = false;

  List<String> drivers = [];

  @override
  void initState() {
    super.initState();
    _loadDrivers();
    _startFaceDetection();
  }

  @override
  void dispose() {
    _stopFaceDetection();
    super.dispose();
  }

  /// ================= LOAD DRIVER =================
  Future<void> _loadDrivers() async {
    try {
      final result = await widget.loadDrivers();

      setState(() {
        drivers = result;
        isLoading = false;
      });

      debugPrint("🔥 Drivers: $drivers");
    } catch (e) {
      debugPrint("Load driver error: $e");
      setState(() => isLoading = false);
    }
  }

  /// ================= START DETECTION =================
  void _startFaceDetection() {
    if (_isDetecting) return;

    _isDetecting = true;

    _timer = Timer.periodic(widget.detectionInterval, (_) async {
      try {
        final result = await widget.loadDriverStatus();

        final recognized = result["recognized"] == true;
        final name = result["driver"];

        if (recognized && name != null && !isNavigated) {
          final driverName = name.toString().trim();
          final existsInBackend = drivers.any(
            (driver) => driver.trim().toLowerCase() == driverName.toLowerCase(),
          );

          if (!existsInBackend) {
            debugPrint("⚠️ Ignoring stale recognized driver: $driverName");
            return;
          }

          isNavigated = true;

          debugPrint("🔥 AUTO LOGIN: $driverName");

          DriverSession.setDriver(driverName);

          _stopFaceDetection();

          if (mounted) {
            Navigator.pushReplacementNamed(context, AppRoutes.home);
          }
        }
      } catch (e) {
        debugPrint("DriverSelect error: $e");
      }
    });
  }

  /// ================= STOP DETECTION =================
  void _stopFaceDetection() {
    _timer?.cancel();
    _timer = null;
    _isDetecting = false;
  }

  /// ================= MANUAL SELECT =================
  void _selectDriver(String name) {
    _stopFaceDetection();

    DriverSession.setDriver(name.trim());
    Navigator.pushReplacementNamed(context, AppRoutes.home);
  }

  /// ================= GUEST =================
  void _selectGuest() {
    _stopFaceDetection();

    DriverSession.clear();
    Navigator.pushReplacementNamed(context, AppRoutes.home);
  }

  /// ================= ADD DRIVER =================
  void _goToAddDriver() {
    _stopFaceDetection();

    Navigator.pushNamed(context, AppRoutes.addDriver).then((_) {
      _loadDrivers();
      _startFaceDetection();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          /// BACKGROUND
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                colors: [Color(0xFF111111), Colors.black],
                radius: 0.9,
              ),
            ),
          ),

          const Positioned.fill(child: DottedBackground()),

          /// CONTENT
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Siapa yang mengemudi hari ini?",
                  style: TextStyle(
                    fontSize: 40.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),

                SizedBox(height: 20.h),

                Text(
                  "Detecting driver...",
                  style: TextStyle(color: Colors.white54, fontSize: 14.sp),
                ),

                SizedBox(height: 40.h),

                /// DRIVER LIST
                isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Wrap(
                        spacing: 60.w,
                        runSpacing: 20.h,
                        alignment: WrapAlignment.center,
                        children: [
                          ...drivers.map(
                            (name) => DriverAvatarCard(
                              name: name,
                              onTap: () => _selectDriver(name),
                            ),
                          ),

                          /// ADD DRIVER
                          DriverAvatarCard(
                            name: "Tambah Akun",
                            isAddButton: true,
                            onTap: _goToAddDriver,
                          ),
                        ],
                      ),

                SizedBox(height: 80.h),

                /// GUEST
                GuestButton(onTap: _selectGuest),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
