import 'dart:async';
import 'package:flutter/material.dart';
import 'package:frontend/core/localization/app_strings.dart';
import 'package:frontend/core/navigation/app_routes.dart';
import 'package:frontend/core/services/drowsiness_api.dart';

class FaceRecognition extends StatefulWidget {
  static const routeName = AppRoutes.home;

  final String driverName;

  const FaceRecognition({super.key, required this.driverName});

  @override
  State<FaceRecognition> createState() => _HomePageState();
}

class _HomePageState extends State<FaceRecognition> {
  Timer? _timer;
  Map<String, dynamic>? drowsinessStatus;
  bool _dialogShown = false;
  bool _isMonitoring = false;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _startMonitoring();
  }

  Future<void> _startMonitoring() async {
    if (_isBusy) return;

    setState(() {
      _isBusy = true;
    });

    try {
      final result = await DrowsinessApi.startDrowsiness(
        driverName: widget.driverName,
      );

      if (!mounted) return;

      setState(() {
        _isMonitoring = result["active"] == true;
      });

      _startPolling();
    } catch (e) {
      debugPrint("start drowsiness failed: $e");
      if (!mounted) return;

      setState(() {
        _isMonitoring = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.startDrowsinessFailed(e))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  void _startPolling() {
    _timer?.cancel();

    _timer = Timer.periodic(const Duration(milliseconds: 800), (_) async {
      if (!_isMonitoring) return;

      try {
        final result = await DrowsinessApi.getDrowsinessStatus();

        if (!mounted) return;

        final backendActive = result["active"] == true;
        final status = result["status"]?.toString() ?? "inactive";

        setState(() {
          drowsinessStatus = result;
          _isMonitoring = backendActive;
        });

        if (status == "drowsy" && !_dialogShown) {
          _dialogShown = true;
          _showDrowsyDialog();
        }

        if (status != "drowsy") {
          _dialogShown = false;
        }
      } catch (e) {
        debugPrint("poll drowsiness failed: $e");
      }
    });
  }

  Future<void> _stopMonitoring() async {
    if (_isBusy) return;

    setState(() {
      _isBusy = true;
    });

    try {
      final result = await DrowsinessApi.stopDrowsiness();

      if (!mounted) return;

      setState(() {
        _isMonitoring = result["active"] == true;
        drowsinessStatus = {
          "active": false,
          "driver_name": null,
          "recognized_driver": null,
          "driver_match": false,
          "ear": null,
          "mar": null,
          "mood": "unknown",
          "mood_confidence": 0.0,
          "raw_mood": "unknown",
          "mood_candidate": "unknown",
          "mood_candidate_elapsed": 0.0,
          "mood_required_sec": 7.0,
          "smile_score": 0.0,
          "sadness_score": 0.0,
          "yawn_status": "NO",
          "yawn_total": 0,
          "score": 0.0,
          "status": "inactive",
        };
      });
    } catch (e) {
      debugPrint("stop drowsiness failed: $e");
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.stopDrowsinessFailed(e))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  Future<void> _showDrowsyDialog() async {
    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: Text(AppStrings.drowsyWarning),
          content: Text(AppStrings.smartFragranceQuestion),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text(AppStrings.yes),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text(AppStrings.no),
            ),
            TextButton(
              onPressed: () async {
                await _stopMonitoring();

                if (context.mounted) {
                  Navigator.pop(context);
                }
              },
              child: Text(AppStrings.disableDrowsiness),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _value(String key) {
    if (drowsinessStatus == null) return "-";
    final v = drowsinessStatus![key];
    return v == null ? "-" : v.toString();
  }

  String get _monitoringLabel =>
      _isMonitoring ? AppStrings.active : AppStrings.inactive;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.home)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppStrings.safeDriveGreeting(widget.driverName),
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text("Drowsiness Detection: $_monitoringLabel"),
                const SizedBox(width: 12),
                if (_isBusy)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                const Spacer(),
                Switch(
                  value: _isMonitoring,
                  onChanged: _isBusy
                      ? null
                      : (value) async {
                          if (value) {
                            await _startMonitoring();
                          } else {
                            await _stopMonitoring();
                          }
                        },
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text("EAR: ${_value("ear")}"),
            Text("MAR: ${_value("mar")}"),
            Text("Recognized Driver: ${_value("recognized_driver")}"),
            Text("Driver Match: ${_value("driver_match")}"),
            Text("Mood: ${_value("mood")}"),
            Text("Raw Mood: ${_value("raw_mood")}"),
            Text("Mood Candidate: ${_value("mood_candidate")}"),
            Text("Mood Duration: ${_value("mood_candidate_elapsed")}s"),
            Text("Mood Required: ${_value("mood_required_sec")}s"),
            Text("Mood Confidence: ${_value("mood_confidence")}"),
            Text("Happy Score: ${_value("smile_score")}"),
            Text("Sad Score: ${_value("sadness_score")}"),
            Text("Yawn Status: ${_value("yawn_status")}"),
            Text("Yawn Total: ${_value("yawn_total")}"),
            Text("Score: ${_value("score")}"),
            Text("Status: ${_value("status")}"),
          ],
        ),
      ),
    );
  }
}
