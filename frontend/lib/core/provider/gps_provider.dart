import 'package:flutter/material.dart';
import 'package:frontend/core/model/gps_data.dart';
import 'package:frontend/core/services/serial_service.dart';


class GPSProvider extends ChangeNotifier {

  GPSData? current;

  final SerialService serialService = SerialService();

  GPSProvider() {
    serialService.start();

    serialService.stream.listen((gps) {

      current = gps;

      notifyListeners();
    });
  }
}