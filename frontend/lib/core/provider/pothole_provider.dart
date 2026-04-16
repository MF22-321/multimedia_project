import 'package:flutter/material.dart';
import 'package:frontend/core/model/pothole.dart';
import 'package:frontend/core/services/pothole_service.dart';


class PotholeProvider extends ChangeNotifier {

  List<Pothole> potholes = [];

  final PotholeService _service = PotholeService();

  Future<void> loadPotholes() async {

    try {

      potholes = await _service.fetchPotholes();

      print("POTHOLE COUNT: ${potholes.length}");

      notifyListeners();

    } catch (e) {

      print("ERROR PROVIDER: $e");

    }
  }
}