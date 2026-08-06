import 'dart:convert';
import 'dart:typed_data';
import 'package:frontend/core/services/backend_config.dart';
import 'package:http/http.dart' as http;

class FaceIdApi {
  /// 🔥 WebSocket camera stream
  static String get cameraWs => "${BackendConfig.wsBase}/ws/camera";

  static String cameraWsWith({int? width, int? fps, int? quality}) {
    final params = <String, String>{};

    if (width != null) params["width"] = width.toString();
    if (fps != null) params["fps"] = fps.toString();
    if (quality != null) params["quality"] = quality.toString();

    if (params.isEmpty) {
      return cameraWs;
    }

    final query = Uri(queryParameters: params).query;
    return "$cameraWs?$query";
  }

  static String get cameraPreviewWs =>
      cameraWsWith(width: 480, fps: 12, quality: 65);

  static String get cameraScanWs =>
      cameraWsWith(width: 640, fps: 12, quality: 78);

  /// ==============================
  /// 📊 DRIVER STATUS
  /// ==============================
  ///
  ///   /// 🔥 GET LIST DRIVER
  static Future<List<String>> getDrivers({
    http.Client? client,
    String baseUrl = BackendConfig.httpBase,
  }) async {
    final uri = Uri.parse("$baseUrl/drivers");
    final res = client == null ? await http.get(uri) : await client.get(uri);

    if (res.statusCode != 200) {
      throw Exception("Failed to get drivers");
    }

    final data = jsonDecode(res.body);
    return List<String>.from(data["drivers"]);
  }

  static Future<Map<String, dynamic>> getDriverStatus({
    http.Client? client,
    String baseUrl = BackendConfig.httpBase,
  }) async {
    try {
      final uri = Uri.parse("$baseUrl/driver_status");
      final res = client == null ? await http.get(uri) : await client.get(uri);

      if (res.statusCode != 200) {
        throw Exception("Failed: ${res.body}");
      }

      return jsonDecode(res.body);
    } catch (e) {
      throw Exception("Driver status error: $e");
    }
  }

  static Future<Map<String, dynamic>> getEnrollmentStatus({
    http.Client? client,
    String baseUrl = BackendConfig.httpBase,
  }) async {
    final uri = Uri.parse("$baseUrl/enrollment_status");
    final res = client == null ? await http.get(uri) : await client.get(uri);
    if (res.statusCode != 200) {
      throw Exception("Enrollment status failed: ${res.body}");
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> getAdaptiveCandidate({
    http.Client? client,
    String baseUrl = BackendConfig.httpBase,
  }) async {
    final uri = Uri.parse("$baseUrl/faceid/adaptive_candidate");
    final res = client == null ? await http.get(uri) : await client.get(uri);
    if (res.statusCode != 200) {
      throw Exception("Adaptive candidate failed: ${res.body}");
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> approveAdaptiveCandidate({
    http.Client? client,
    String baseUrl = BackendConfig.httpBase,
  }) async {
    final uri = Uri.parse("$baseUrl/faceid/adaptive_candidate/approve");
    final res = client == null ? await http.post(uri) : await client.post(uri);
    if (res.statusCode != 200) {
      throw Exception("Adaptive approve failed: ${res.body}");
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> rejectAdaptiveCandidate({
    http.Client? client,
    String baseUrl = BackendConfig.httpBase,
  }) async {
    final uri = Uri.parse("$baseUrl/faceid/adaptive_candidate/reject");
    final res = client == null ? await http.post(uri) : await client.post(uri);
    if (res.statusCode != 200) {
      throw Exception("Adaptive reject failed: ${res.body}");
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// ==============================
  /// 📸 CAPTURE FACE (SINGLE FRAME)
  /// ==============================
  static Future<Uint8List> captureFace({
    http.Client? client,
    String baseUrl = BackendConfig.httpBase,
  }) async {
    try {
      final uri = Uri.parse("$baseUrl/capture_face");
      final res = client == null ? await http.get(uri) : await client.get(uri);

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
    http.Client? client,
    String baseUrl = BackendConfig.httpBase,
  }) async {
    try {
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

      final response = client == null
          ? await request.send()
          : await client.send(request);
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
    http.Client? client,
    String baseUrl = BackendConfig.httpBase,
  }) async {
    try {
      final request = http.MultipartRequest(
        "POST",
        Uri.parse("$baseUrl/enroll_live_burst"),
      );

      request.fields["driver_name"] = driverName;
      request.fields["duration_sec"] = durationSec.toString();
      request.fields["target_samples"] = targetSamples.toString();

      final response = client == null
          ? await request.send()
          : await client.send(request);
      final body = await response.stream.bytesToString();

      if (response.statusCode != 200) {
        throw Exception("Burst failed: $body");
      }

      return jsonDecode(body);
    } catch (e) {
      throw Exception("Burst enroll error: $e");
    }
  }

  /// ==============================
  /// 🗑 DELETE DRIVER (FULL CLEAN)
  /// ==============================
  static Future<Map<String, dynamic>> deleteDriver(
    String name, {
    http.Client? client,
    String baseUrl = BackendConfig.httpBase,
  }) async {
    try {
      final driverName = Uri.encodeComponent(name.trim());

      final uri = Uri.parse("$baseUrl/driver/$driverName");
      final res = client == null
          ? await http.delete(uri)
          : await client.delete(uri);

      if (res.statusCode != 200) {
        throw Exception("Delete failed: ${res.body}");
      }

      final data = jsonDecode(res.body);
      if (data is Map<String, dynamic> && data["success"] == false) {
        throw Exception(data["message"] ?? "Delete failed");
      }

      return data;
    } catch (e) {
      throw Exception("Delete driver error: $e");
    }
  }
}
