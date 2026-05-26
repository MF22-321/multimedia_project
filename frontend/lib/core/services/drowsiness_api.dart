import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:frontend/core/services/backend_config.dart';

class DrowsinessApi {
  /// ==============================
  /// 🚗 START DROWSINESS DETECTION
  /// ==============================
  static Future<Map<String, dynamic>> startDrowsiness({
    required String driverName,
  }) async {
    try {
      final response = await http.post(
        Uri.parse("${BackendConfig.httpBase}/start_drowsiness"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"driver_name": driverName}),
      );

      if (response.statusCode != 200) {
        throw Exception("Start failed: ${response.body}");
      }

      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      throw Exception("Start drowsiness error: $e");
    }
  }

  /// ==============================
  /// 🛑 STOP DROWSINESS DETECTION
  /// ==============================
  static Future<Map<String, dynamic>> stopDrowsiness() async {
    try {
      final response = await http.post(
        Uri.parse("${BackendConfig.httpBase}/stop_drowsiness"),
      );

      if (response.statusCode != 200) {
        throw Exception("Stop failed: ${response.body}");
      }

      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      throw Exception("Stop drowsiness error: $e");
    }
  }

  /// ==============================
  /// 📊 GET STATUS
  /// ==============================
  static Future<Map<String, dynamic>> getDrowsinessStatus() async {
    try {
      final response = await http.get(
        Uri.parse("${BackendConfig.httpBase}/drowsiness_status"),
      );

      if (response.statusCode != 200) {
        throw Exception("Status failed: ${response.body}");
      }

      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      throw Exception("Get status error: $e");
    }
  }
}
