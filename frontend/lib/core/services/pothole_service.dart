import 'dart:convert';
import 'package:frontend/core/model/pothole.dart';
import 'package:frontend/core/utils/app_logger.dart';
import 'package:http/http.dart' as http;

class PotholeService {
  final String baseUrl = "http://203.100.57.59:3000/api/v1";
  final String token =
      "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VybmFtZSI6Im11aGZlYnJpYW4iLCJmdWxsbmFtZSI6Ik11aGFtYWQgRmVicmlhbiIsImVtYWlsIjoiZmVicmlhbkBnbWFpbC5jb20iLCJjcmVhdGVkX2J5IjoiU1lTVEVNIiwiY3JlYXRlZF9kdCI6IjIwMjYtMDQtMTZUMTA6Mzk6MjUuMDAwWiIsImFkZHJlc3MiOiJLYXJhd2FuZywgSW5kb25lc2lhIiwiaWF0IjoxNzc2MzEwODE0LCJleHAiOjE3NzYzMTQ0MTR9.XccCGZIUUk3i2TN3l0fNo2TCrDTh3HcdY5yXyqrlq6E";

  Future<List<Pothole>> fetchPotholes() async {
    final url = Uri.parse("$baseUrl/pothole/getall");

    final response = await http
        .get(
          url,
          headers: {
            "Authorization": "Bearer $token",
            "Content-Type": "application/json",
          },
        )
        .timeout(const Duration(seconds: 8));

    AppLogger.info("POTHOLE STATUS: ${response.statusCode}");

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final data = decoded["data"];

      if (data is! List) {
        throw Exception("Invalid pothole payload");
      }

      return data
          .whereType<Map>()
          .map((e) => Pothole.fromJson(Map<String, dynamic>.from(e)))
          .where((e) => e.lat != 0 && e.lng != 0)
          .toList();
    } else {
      throw Exception("Failed load potholes");
    }
  }
}
