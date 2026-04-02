import 'dart:async';
import 'package:flutter/material.dart';
import 'package:frontend/core/services/faceid_api.dart';
import 'package:frontend/features/face_recognition/presentation/pages/face_recognition_page.dart';
import '../widgets/live_camera_webview.dart';
import 'add_driver_page.dart';

class FaceScanPage extends StatefulWidget {
  static const routeName = "/scan";

  const FaceScanPage({super.key});

  @override
  State<FaceScanPage> createState() => _FaceScanPageState();
}

class _FaceScanPageState extends State<FaceScanPage> {
  Timer? _timer;
  Map<String, dynamic>? status;
  bool loading = true;
  bool _navigating = false;

  DateTime? _recognizedSince;
  final Duration _steadyDuration = const Duration(seconds: 2);

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  void _startPolling() {
    _fetchStatus();

    _timer = Timer.periodic(const Duration(milliseconds: 700), (_) {
      _fetchStatus();
    });
  }

  Future<void> _fetchStatus() async {
    try {
      final result = await FaceIdApi.getDriverStatus();
      if (!mounted) return;

      setState(() {
        status = result;
        loading = false;
      });

      final recognized = result["recognized"] == true;
      final driverName = result["driver"]?.toString();

      if (recognized && driverName != null && !_navigating) {
        final now = DateTime.now();

        _recognizedSince ??= now;

        final elapsed = now.difference(_recognizedSince!);

        if (elapsed >= _steadyDuration) {
          _navigating = true;
          _timer?.cancel();

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;

            Navigator.pushReplacementNamed(
              context,
              FaceRecognition.routeName,
              arguments: {"driver_name": driverName},
            );
          });
        }
      } else {
        _recognizedSince = null;
      }
    } catch (_) {
      if (!mounted) return;

      setState(() {
        loading = false;
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _driverText() {
    if (status == null) return "-";
    return status!["driver"]?.toString() ?? "Unknown";
  }

  String _recognizedText() {
    if (status == null) return "-";
    final recognized = status!["recognized"] == true;
    return recognized ? "Recognized" : "Unknown";
  }

  String _confidenceText() {
    if (status == null) return "-";
    final c = status!["confidence"];
    return c == null ? "-" : c.toString();
  }

  String _steadyText() {
    if (_recognizedSince == null) return "-";

    final remain =
        _steadyDuration - DateTime.now().difference(_recognizedSince!);

    final seconds = remain.inMilliseconds <= 0
        ? 0.0
        : remain.inMilliseconds / 1000.0;

    return seconds.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final recognized = status?["recognized"] == true;

    return Scaffold(
      appBar: AppBar(title: const Text("Face Scan")),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            LiveCameraWS(url: "ws://127.0.0.1:8000/ws/camera"),
            const SizedBox(height: 24),
            if (loading)
              const CircularProgressIndicator()
            else
              Column(
                children: [
                  Text("Driver: ${_driverText()}"),
                  const SizedBox(height: 8),
                  Text("Status: ${_recognizedText()}"),
                  const SizedBox(height: 8),
                  Text("Confidence: ${_confidenceText()}"),
                  const SizedBox(height: 8),
                  if (recognized && !_navigating)
                    Text("Steady check: ${_steadyText()} s"),
                ],
              ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, AddDriverPage2.routeName);
              },
              child: const Text("Add New Driver"),
            ),
          ],
        ),
      ),
    );
  }
}
