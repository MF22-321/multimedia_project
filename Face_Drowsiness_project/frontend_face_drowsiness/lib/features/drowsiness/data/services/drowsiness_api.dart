import 'dart:convert';
import 'package:http/http.dart' as http;

class DrowsinessApi {
  static const String baseUrl = "http://127.0.0.1:8000";

  static Future<Map<String, dynamic>> startDrowsiness({
    required String driverName,
  }) async {
    final response = await http.post(
      Uri.parse("$baseUrl/start_drowsiness"),
      headers: {
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "driver_name": driverName,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception("Failed to start drowsiness: ${response.body}");
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> stopDrowsiness() async {
    final response = await http.post(Uri.parse("$baseUrl/stop_drowsiness"));

    if (response.statusCode != 200) {
      throw Exception("Failed to stop drowsiness: ${response.body}");
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> getDrowsinessStatus() async {
    final response = await http.get(Uri.parse("$baseUrl/drowsiness_status"));

    if (response.statusCode != 200) {
      throw Exception("Failed to get drowsiness status: ${response.body}");
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}