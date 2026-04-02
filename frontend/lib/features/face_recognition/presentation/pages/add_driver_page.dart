import 'dart:async';
import 'package:flutter/material.dart';
import 'package:frontend/core/services/faceid_api.dart';
import 'package:frontend/features/face_recognition/presentation/pages/face_recognition_page.dart';
import '../widgets/live_camera_webview.dart';
import '../widgets/camera_scan_frame.dart';

class AddDriverPage2 extends StatefulWidget {
  static const routeName = "/add-driver2";

  const AddDriverPage2({super.key});

  @override
  State<AddDriverPage2> createState() => _AddDriverPageState();
}

class _AddDriverPageState extends State<AddDriverPage2>
    with SingleTickerProviderStateMixin {
  final TextEditingController nameController = TextEditingController();

  bool isCapturing = false;
  bool isPreparing = false;
  bool _navigating = false;

  String? burstResultText;

  late final AnimationController _progressController;
  Timer? _countdownTimer;

  int prepSecondsLeft = 3;
  int captureSecondsLeft = 8;
  String phaseText = "Press scan to start";

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    );
  }

  Future<void> handleBurstEnroll() async {
    final name = nameController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Name is required")));
      return;
    }

    setState(() {
      burstResultText = null;
      isPreparing = true;
      isCapturing = false;
      prepSecondsLeft = 3;
      captureSecondsLeft = 8;
      phaseText = "Get ready";
    });

    // PREP COUNTDOWN: 3,2,1
    for (int i = 3; i >= 1; i--) {
      if (!mounted) return;
      setState(() {
        prepSecondsLeft = i;
        phaseText = "Get ready";
      });
      await Future.delayed(const Duration(seconds: 1));
    }

    if (!mounted) return;

    // START CAPTURE PHASE
    setState(() {
      isPreparing = false;
      isCapturing = true;
      captureSecondsLeft = 8;
      phaseText = "Hold still";
    });

    _progressController.reset();
    _progressController.forward();

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;

      setState(() {
        captureSecondsLeft = (8 - timer.tick).clamp(0, 8);
      });

      if (timer.tick >= 8) {
        timer.cancel();
      }
    });

    try {
      final result = await FaceIdApi.enrollLiveBurst(
        driverName: name,
        durationSec: 8.0,
        targetSamples: 60,
      );

      if (!mounted) return;

      final success = result["success"] == true;
      final message = result["message"]?.toString() ?? "Done";
      final savedCount = result["saved_count"]?.toString() ?? "0";

      setState(() {
        burstResultText = "$message\nSaved samples: $savedCount";
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("$message | saved: $savedCount")));

      if (success && !_navigating) {
        _navigating = true;

        await Future.delayed(const Duration(milliseconds: 800));
        if (!mounted) return;

        Navigator.pushReplacementNamed(
          context,
          FaceRecognition.routeName,
          arguments: {"driver_name": name},
        );
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        burstResultText = "Burst capture failed: $e";
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Burst capture failed: $e")));
    } finally {
      _countdownTimer?.cancel();
      _progressController.stop();

      if (!mounted) return;
      setState(() {
        isPreparing = false;
        isCapturing = false;
        phaseText = "Press scan to start";
        prepSecondsLeft = 3;
        captureSecondsLeft = 0;
      });
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _progressController.dispose();
    nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool overlayActive = isPreparing || isCapturing;
    final int shownNumber = isPreparing ? prepSecondsLeft : captureSecondsLeft;
    final double shownProgress = isCapturing ? _progressController.value : 0.0;

    return Scaffold(
      appBar: AppBar(title: const Text("Add New Driver")),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: "Name",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            AnimatedBuilder(
              animation: _progressController,
              builder: (context, _) {
                return CameraScanFrame(
                  progress: shownProgress,
                  isScanning: overlayActive,
                  secondsLeft: shownNumber,
                  width: 300,
                  height: 300,
                  child: LiveCameraWS(url: "ws://127.0.0.1:8000/ws/camera"),
                );
              },
            ),
            const SizedBox(height: 16),
            Text(
              phaseText,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              isPreparing
                  ? "Center your face inside the box."
                  : isCapturing
                  ? "Hold still and move your head slightly left and right."
                  : "Press scan to capture face samples for 8 seconds.",
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: (isPreparing || isCapturing || _navigating)
                  ? null
                  : handleBurstEnroll,
              child: Text(
                (isPreparing || isCapturing)
                    ? "Capturing & Training..."
                    : "Scan Face (8s)",
              ),
            ),
            const SizedBox(height: 20),
            if (burstResultText != null)
              Text(burstResultText!, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
