import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/services/drowsiness_api.dart';

class HomePage extends StatefulWidget {
  static const routeName = "/home";

  final String driverName;

  const HomePage({
    super.key,
    required this.driverName,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
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
        SnackBar(content: Text("Gagal memulai drowsiness detection: $e")),
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
          "ear": null,
          "mar": null,
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
        SnackBar(content: Text("Gagal menghentikan drowsiness detection: $e")),
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
          title: const Text("Hati-hati Anda sedang mengantuk!"),
          content: const Text(
            "Mau mengaktifkan Smart Fragrance untuk mengurangi kantuk Anda?",
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text("YA"),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text("TIDAK"),
            ),
            TextButton(
              onPressed: () async {
                await _stopMonitoring();

                if (context.mounted) {
                  Navigator.pop(context);
                }
              },
              child: const Text("Nonaktifkan Drowsiness Detection"),
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

  String get _monitoringLabel => _isMonitoring ? "Aktif" : "Nonaktif";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Home Page"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Selamat berkendara, ${widget.driverName}",
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
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