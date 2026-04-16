import 'dart:convert';
import 'package:frontend/core/model/pothole.dart';
import 'package:http/http.dart' as http;

class PotholeService {

  /// 🔥 BASE URL
  final String baseUrl = "http://203.100.57.59:3000/api/v1";

  /// 🔥 TOKEN (sementara hardcode)
  final String token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VybmFtZSI6Im11aGZlYnJpYW4iLCJmdWxsbmFtZSI6Ik11aGFtYWQgRmVicmlhbiIsImVtYWlsIjoiZmVicmlhbkBnbWFpbC5jb20iLCJjcmVhdGVkX2J5IjoiU1lTVEVNIiwiY3JlYXRlZF9kdCI6IjIwMjYtMDQtMTZUMTA6Mzk6MjUuMDAwWiIsImFkZHJlc3MiOiJLYXJhd2FuZywgSW5kb25lc2lhIiwiaWF0IjoxNzc2MzEwODE0LCJleHAiOjE3NzYzMTQ0MTR9.XccCGZIUUk3i2TN3l0fNo2TCrDTh3HcdY5yXyqrlq6E";

  /// ================= GET ALL =================
  Future<List<Pothole>> fetchPotholes() async {

    final url = Uri.parse("$baseUrl/pothole/getall");

    final response = await http.get(
      url,
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
    );

    print("STATUS: ${response.statusCode}");
    print("BODY: ${response.body}");

    if (response.statusCode == 200) {

      final decoded = jsonDecode(response.body);

      final List data = decoded["data"];

      return data.map((e) => Pothole.fromJson(e)).toList();

    } else {

      throw Exception("Failed load potholes");

    }
  }
}