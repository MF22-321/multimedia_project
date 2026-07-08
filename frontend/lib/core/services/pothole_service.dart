import 'dart:convert';
import 'package:frontend/core/model/pothole.dart';
import 'package:frontend/core/utils/app_logger.dart';
import 'package:http/http.dart' as http;

class PotholeService {
  PotholeService({String? baseUrl, String? token, http.Client? client})
    : baseUrl = baseUrl ?? _configuredBaseUrl,
      token = token ?? _configuredToken,
      _client = client ?? http.Client();

  static const _configuredBaseUrl = String.fromEnvironment(
    'POTHOLE_API_BASE_URL',
    defaultValue: 'http://203.100.57.59:3000/api/v1',
  );
  static const _configuredToken = String.fromEnvironment('POTHOLE_API_TOKEN');

  final String baseUrl;
  final String token;
  final http.Client _client;

  Future<List<Pothole>> fetchPotholes() async {
    final url = Uri.parse("$baseUrl/pothole/getall");
    final headers = <String, String>{"Content-Type": "application/json"};
    if (token.trim().isNotEmpty) {
      headers["Authorization"] = "Bearer $token";
    }

    final response = await _client
        .get(url, headers: headers)
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
