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
  Timer? _countdownTimer;

  DateTime? _detectedSince;

  final Duration _steadyDuration = const Duration(milliseconds: 800);

  bool _isTriggered = false;
  bool _pollingBusy = false;

  String? _currentDriverName;
  double? _confidence;

  int _countdown = 0;

  /// ================= START =================
  void _startScan() {
    if (widget.driverName == null || widget.driverName!.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Isi nama dulu!")));
      return;
    }

    setState(() {
      _isScanning = true;
      _detectedSince = null;
      _isTriggered = false;
      _currentDriverName = null;
      _confidence = null;
      _countdown = 0;
    });

    _startPolling();
  }

  /// ================= STOP =================
  void _stopScan() {
    _timer?.cancel();
    _countdownTimer?.cancel();
    _pollingBusy = false;

    if (!mounted) return;

    setState(() {
      _isScanning = false;
      _detectedSince = null;
      _isTriggered = false;
      _currentDriverName = null;
      _confidence = null;
      _countdown = 0;
    });
  }

  /// ================= COUNTDOWN =================
  void _startCountdown() {
    _countdown = 3;

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown == 0) {
        timer.cancel();
        _timer?.cancel();
        _pollingBusy = false;

        debugPrint("🚀 START ENROLL");

        widget.onFaceStable?.call();
      } else {
        setState(() {
          _countdown--;
        });
      }
    });
  }

  /// ================= POLLING =================
  void _startPolling() {
    _timer?.cancel();

    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) async {
      if (_pollingBusy) return;
      _pollingBusy = true;

      try {
        final result = await FaceIdApi.getDriverStatus();
        if (!mounted) return;

        final bbox = result["bbox"];
        final detected = bbox is List && bbox.length == 4;

        final conf = result["confidence"];
        if (conf is num) {
          _confidence = conf.toDouble();
        }

        if (detected) {
          final now = DateTime.now();
          _detectedSince ??= now;

          final elapsed = now.difference(_detectedSince!);

          if (elapsed >= _steadyDuration && !_isTriggered) {
            _isTriggered = true;

            debugPrint("✅ FACE DETECTED → SHOW NAME");

            setState(() {
              _currentDriverName = widget.driverName;
            });

            /// 🔥 start countdown
            _startCountdown();
          }
        } else {
          _detectedSince = null;
          _isTriggered = false;

          _countdownTimer?.cancel();

          setState(() {
            _currentDriverName = null;
            _confidence = null;
            _countdown = 0;
          });
        }
      } catch (e) {
        debugPrint("❌ Polling error: $e");
      } finally {
        _pollingBusy = false;
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  /// ================= UI =================
  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 400.w,
      height: 300.h,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30.r),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 12),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30.r),
        child: _isScanning
            ? Stack(
                children: [
                  /// CAMERA
                  Positioned.fill(
                    child: LiveCameraWS(
                      url: FaceIdApi.cameraScanWs,
                      width: 400.w,
                      height: 300.h,
                      maxFps: 12,
                      fit: BoxFit.cover,
                    ),
                  ),

                  /// 🔥 COUNTDOWN BESAR
                  if (_countdown > 0)
                    Center(
                      child: Text(
                        "$_countdown",
                        style: const TextStyle(
                          fontSize: 80,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                  /// DRIVER NAME
                  if (_currentDriverName != null)
                    Positioned(
                      bottom: 80,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _currentDriverName!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),

                  /// CONFIDENCE
                  if (_confidence != null)
                    Positioned(
                      bottom: 50,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Text(
                          "Confidence: ${_confidence!.toStringAsFixed(2)}",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),

                  /// STATUS
                  Positioned(
                    bottom: 12,
                    left: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _countdown > 0
                            ? "Get ready..."
                            : _isTriggered
                            ? "Preparing..."
                            : "Scanning...",
                        style: const TextStyle(color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),

                  /// CLOSE BUTTON
                  Positioned(
                    top: 10,
                    right: 10,
                    child: GestureDetector(
                      onTap: _stopScan,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),

                  /// LIVE LABEL
                  const Positioned(
                    top: 10,
                    left: 10,
                    child: Text(
                      "LIVE",
                      style: TextStyle(
                        color: Colors.greenAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              )
            : GestureDetector(
                onTap: _startScan,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.face, size: 70.sp, color: Colors.deepPurple),
                    SizedBox(height: 12.h),
                    Text(
                      "Scan Face",
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      "Auto detect & enroll",
                      style: TextStyle(fontSize: 12.sp, color: Colors.grey),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
