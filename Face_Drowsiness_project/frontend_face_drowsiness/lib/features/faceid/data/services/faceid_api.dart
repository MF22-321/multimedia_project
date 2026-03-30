import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class FaceIdApi {
  static const String baseUrl = "http://127.0.0.1:8000";

  static String get cameraFeedUrl => "$baseUrl/camera_feed";

  static Future<Map<String, dynamic>> getDriverStatus() async {
    final res = await http.get(Uri.parse("$baseUrl/driver_status"));

    if (res.statusCode != 200) {
      throw Exception("Failed to get driver status");
    }

    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<Uint8List> captureFace() async {
    final res = await http.get(Uri.parse("$baseUrl/capture_face"));

    if (res.statusCode != 200) {
      throw Exception("Failed to capture face");
    }

    return res.bodyBytes;
  }

  static Future<Map<String, dynamic>> enrollDriver({
    required String driverName,
    required Uint8List imageBytes,
  }) async {
    final request = http.MultipartRequest(
      "POST",
      Uri.parse("$baseUrl/enroll"),
    );

    request.fields["driver_name"] = driverName;

    request.files.add(
      http.MultipartFile.fromBytes(
        "image",
        imageBytes,
        filename: "capture.jpg",
      ),
    );

    final response = await request.send();
    final body = await response.stream.bytesToString();

    if (response.statusCode != 200) {
      throw Exception("Enroll failed: $body");
    }

    return jsonDecode(body) as Map<String, dynamic>;
  }
  
  static Future<Map<String, dynamic>> enrollLiveBurst({
    required String driverName,
    double durationSec = 8.0,
    int targetSamples = 60,
  }) async {
    final request = http.MultipartRequest(
      "POST",
      Uri.parse("$baseUrl/enroll_live_burst"),
    );

    request.fields["driver_name"] = driverName;
    request.fields["duration_sec"] = durationSec.toString();
    request.fields["target_samples"] = targetSamples.toString();

    final response = await request.send();
    final body = await response.stream.bytesToString();

    if (response.statusCode != 200) {
      throw Exception("Burst enroll failed: $body");
    }

    return jsonDecode(body) as Map<String, dynamic>;
  }
  
}