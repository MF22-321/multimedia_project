import 'dart:async';
import 'package:flutter/material.dart';
import 'package:frontend/core/model/gps_data.dart';
import 'package:frontend/core/services/serial_service.dart';

class GPSProvider extends ChangeNotifier {
  GPSData? current;

  final SerialService serialService = SerialService();

  StreamSubscription? _subscription;
  StreamSubscription<String>? _statusSubscription;

  bool isConnected = false;
  bool hasFix = false;
  bool espWifiConnected = false;
  int satellites = 0;
  String wifiSsid = "";

  String status = "Searching device...";

  GPSProvider() {
    _init();
  }

  void _init() {
    _statusSubscription = serialService.statusStream.listen((serialStatus) {
      isConnected = serialService.isConnected;
      if (!isConnected) {
        current = null;
        hasFix = false;
        espWifiConnected = false;
        satellites = 0;
      }
      status = serialStatus;
      notifyListeners();
    });

    serialService.start();

    _subscription = serialService.stream.listen(
      (gps) {
        current = gps;

        isConnected = serialService.isConnected;
        hasFix = gps.isValid;
        espWifiConnected = gps.wifiConnected;
        satellites = gps.satellites;
        wifiSsid = gps.wifiSsid;
        status = hasFix
            ? "GPS Connected ($satellites sat)"
            : "USB Connected - Waiting GPS Fix ($satellites sat)";

        notifyListeners();
      },
      onError: (_) {
        isConnected = false;
        hasFix = false;
        espWifiConnected = false;
        status = "Connection Error";

        notifyListeners();
      },
      onDone: () {
        isConnected = false;
        hasFix = false;
        espWifiConnected = false;
        status = "Disconnected";

        notifyListeners();
      },
    );
  }

  void clearGPS() {
    current = null;
    hasFix = false;
    satellites = 0;
    status = "GPS Cleared";
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _statusSubscription?.cancel();
    serialService.dispose();
    super.dispose();
  }
}
