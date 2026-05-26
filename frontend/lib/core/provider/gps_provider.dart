import 'dart:async';
import 'package:flutter/material.dart';
import 'package:frontend/core/model/gps_data.dart';
import 'package:frontend/core/services/serial_service.dart';

class GPSProvider extends ChangeNotifier {
  GPSData? current;

  final SerialService serialService = SerialService();

  StreamSubscription? _subscription;

  bool isConnected = false;
  bool hasFix = false;

  String status = "Searching device...";

  GPSProvider() {
    _init();
  }

  void _init() {
    serialService.start();

    _subscription = serialService.stream.listen(
      (gps) {
        current = gps;

        isConnected = serialService.isConnected;
        hasFix = gps.isValid;
        status = hasFix ? "GPS Connected" : "Waiting GPS Fix";

        notifyListeners();
      },
      onError: (_) {
        isConnected = false;
        hasFix = false;
        status = "Connection Error";

        notifyListeners();
      },
      onDone: () {
        isConnected = false;
        hasFix = false;
        status = "Disconnected";

        notifyListeners();
      },
    );
  }

  void clearGPS() {
    current = null;
    hasFix = false;
    status = "GPS Cleared";
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    serialService.dispose();
    super.dispose();
  }
}