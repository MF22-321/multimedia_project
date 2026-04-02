import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class FaceIdApi {
  /// 🔥 BASE URL DIPISAH
  static const String _httpBase = "http://127.0.0.1:8000";
  static const String _wsBase = "ws://127.0.0.1:8000";

  /// 🔥 WebSocket camera stream
  static String get cameraWs => "$_wsBase/ws/camera";

  /// ==============================
  /// 📊 DRIVER STATUS
  /// ==============================
  /// 
  ///   /// 🔥 GET LIST DRIVER
  static Future<List<String>> getDrivers() async {
    final res = await http.get(Uri.parse("$_httpBase/drivers"));

    if (res.statusCode != 200) {
      throw Exception("Failed to get drivers");
    }

    final data = jsonDecode(res.body);
    return List<String>.from(data["drivers"]);
  }

  static Future<Map<String, dynamic>> getDriverStatus() async {
    try {
      final res = await http.get(
        Uri.parse("$_httpBase/driver_status"),
      );

      if (res.statusCode != 200) {
        throw Exception("Failed: ${res.body}");
      }

      return jsonDecode(res.body);
    } catch (e) {
      throw Exception("Driver status error: $e");
    }
  }

  /// ==============================
  /// 📸 CAPTURE FACE (SINGLE FRAME)
  /// ==============================
  static Future<Uint8List> captureFace() async {
    try {
      final res = await http.get(
        Uri.parse("$_httpBase/capture_face"),
      );

      if (res.statusCode != 200) {
        throw Exception("Failed: ${res.body}");
      }

      return res.bodyBytes;
    } catch (e) {
      throw Exception("Capture face error: $e");
    }
  }

  /// ==============================
  /// 🧠 ENROLL DRIVER (UPLOAD IMAGE)
  /// ==============================
  static Future<Map<String, dynamic>> enrollDriver({
    required String driverName,
    required Uint8List imageBytes,
  }) async {
    try {
      final request = http.MultipartRequest(
        "POST",
        Uri.parse("$_httpBase/enroll"),
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

      return jsonDecode(body);
    } catch (e) {
      throw Exception("Enroll error: $e");
    }
  }

  

  /// ==============================
  /// 🚀 ENROLL LIVE BURST (AUTO CAPTURE)
  /// ==============================
  static Future<Map<String, dynamic>> enrollLiveBurst({
    required String driverName,
    double durationSec = 8.0,
    int targetSamples = 60,
  }) async {
    try {
      final request = http.MultipartRequest(
        "POST",
        Uri.parse("$_httpBase/enroll_live_burst"),
      );

      request.fields["driver_name"] = driverName;
      request.fields["duration_sec"] = durationSec.toString();
      request.fields["target_samples"] = targetSamples.toString();

      final response = await request.send();
      final body = await response.stream.bytesToString();

      if (response.statusCode != 200) {
        throw Exception("Burst failed: $body");
      }

      return jsonDecode(body);
    } catch (e) {
      throw Exception("Burst enroll error: $e");
    }
  }
}