import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:frontend/core/services/faceid_api.dart';
import 'package:frontend/features/face_recognition/presentation/widgets/live_camera_webview.dart';

class ScanFaceButton extends StatefulWidget {
  final String? driverName;
  final VoidCallback? onFaceStable;

  const ScanFaceButton({
    super.key,
    required this.driverName,
    required this.onFaceStable,
  });

  @override
  State<ScanFaceButton> createState() => _ScanFaceButtonState();
}

class _ScanFaceButtonState extends State<ScanFaceButton> {
  bool _isScanning = false;

  Timer? _timer;
  DateTime? _recognizedSince;

  final Duration _steadyDuration = const Duration(seconds: 2);

  bool _isLocked = false;

  String? detectedName;
  double? confidence;

  /// ================= START =================
  void _startScan() {
    if (widget.driverName == null || widget.driverName!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Isi nama dulu!")),
      );
      return;
    }

    setState(() {
      _isScanning = true;
      _recognizedSince = null;
      _isLocked = false;
      detectedName = null;
      confidence = null;
    });

    _startPolling();
  }

  /// ================= STOP =================
  void _stopScan() {
    _timer?.cancel();

    if (!mounted) return;

    setState(() {
      _isScanning = false;
      _recognizedSince = null;
      _isLocked = false;
      detectedName = null;
      confidence = null;
    });
  }

  /// ================= POLLING =================
  void _startPolling() {
    _timer?.cancel();

    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) async {
      try {
        final result = await FaceIdApi.getDriverStatus();

        final recognized = result["recognized"] == true;
        final name = result["driver"]?.toString();
        final conf = result["confidence"];

        if (recognized && name != null) {
          final now = DateTime.now();
          _recognizedSince ??= now;

          final elapsed = now.difference(_recognizedSince!);

          /// 🔥 tampilkan nama realtime
          setState(() {
            detectedName = name;
            confidence = conf is num ? conf.toDouble() : null;
          });

          if (elapsed >= _steadyDuration && !_isLocked) {
            _isLocked = true;

            debugPrint("✅ FACE LOCKED: $name");

            widget.onFaceStable?.call();
          }
        } else {
          _recognizedSince = null;
          _isLocked = false;

          setState(() {
            detectedName = null;
            confidence = null;
          });
        }
      } catch (e) {
        debugPrint("Polling error: $e");
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// ================= UI =================
  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 220.w,
      height: 220.w,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 12,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30.r),
        child: _isScanning
            ? Stack(
                children: [
                  /// 🎥 CAMERA
                  Positioned.fill(
                    child: LiveCameraWS(
                      url: FaceIdApi.cameraWs,
                    ),
                  ),

                  /// 🔥 NAMA DRIVER
                  if (detectedName != null)
                    Positioned(
                      bottom: 60,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.85),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            detectedName!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),

                  /// 🔥 CONFIDENCE
                  if (confidence != null)
                    Positioned(
                      bottom: 35,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Text(
                          "Confidence: ${confidence!.toStringAsFixed(2)}",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),

                  /// STATUS
                  Positioned(
                    bottom: 8,
                    left: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _isLocked
                            ? "Face Locked ✅"
                            : detectedName != null
                                ? "Recognized"
                                : "Scanning...",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),

                  /// CLOSE BUTTON
                  Positioned(
                    top: 6,
                    right: 6,
                    child: GestureDetector(
                      onTap: _stopScan,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),

                  /// LIVE LABEL
                  const Positioned(
                    top: 6,
                    left: 6,
                    child: Text(
                      "LIVE",
                      style: TextStyle(
                        color: Colors.greenAccent,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              )

            /// ================= BUTTON =================
            : GestureDetector(
                onTap: _startScan,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.face,
                      size: 60.sp,
                      color: Colors.deepPurple,
                    ),
                    SizedBox(height: 10.h),
                    Text(
                      "Scan Face",
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      "Start recognition",
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}