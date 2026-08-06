import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:frontend/core/services/backend_config.dart';

class DrowsinessApi {
  /// ==============================
  /// 🚗 START DROWSINESS DETECTION
  /// ==============================
  static Future<Map<String, dynamic>> startDrowsiness({
    required String driverName,
    http.Client? client,
    String baseUrl = BackendConfig.httpBase,
  }) async {
    try {
      final uri = Uri.parse("$baseUrl/start_drowsiness");
      final response =
          await (client?.post(
                uri,
                headers: {"Content-Type": "application/json"},
                body: jsonEncode({"driver_name": driverName}),
              ) ??
              http.post(
                uri,
                headers: {"Content-Type": "application/json"},
                body: jsonEncode({"driver_name": driverName}),
              ));

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
  static Future<Map<String, dynamic>> stopDrowsiness({
    http.Client? client,
    String baseUrl = BackendConfig.httpBase,
  }) async {
    try {
      final uri = Uri.parse("$baseUrl/stop_drowsiness");
      final response = client == null
          ? await http.post(uri)
          : await client.post(uri);

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
  static Future<Map<String, dynamic>> getDrowsinessStatus({
    http.Client? client,
    String baseUrl = BackendConfig.httpBase,
  }) async {
    try {
      final uri = Uri.parse("$baseUrl/drowsiness_status");
      final response = client == null
          ? await http.get(uri)
          : await client.get(uri);

      if (response.statusCode != 200) {
        throw Exception("Status failed: ${response.body}");
      }

      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      throw Exception("Get status error: $e");
    }
  }
}
