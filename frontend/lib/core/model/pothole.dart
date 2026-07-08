class Pothole {
  final double lat;
  final double lng;
  final double severity;
  final double speed;
  final String source;
  final String? backendCategory;
  final DateTime? detectedAt;

  Pothole({
    required this.lat,
    required this.lng,
    required this.severity,
    required this.speed,
    this.source = "backend",
    this.backendCategory,
    this.detectedAt,
  });

  factory Pothole.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic value) {
      if (value == null) return 0;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString()) ?? 0;
    }

    String? normalizeCategory(dynamic value) {
      final raw = value?.toString().toLowerCase().trim();
      if (raw == null || raw.isEmpty) return null;

      if (raw.contains("bumper") || raw.contains("bump")) {
        return "bumper";
      }

      if (raw.contains("pothole") || raw.contains("lubang")) {
        return "pothole";
      }

      if (raw == "normal") {
        return "normal";
      }

      return raw;
    }

    return Pothole(
      lat: toDouble(json["gps_lat"] ?? json["gps"]?["lat"]),
      lng: toDouble(json["gps_lng"] ?? json["gps"]?["lng"]),
      severity: toDouble(
        json["severity"] ??
            json["impact"] ??
            json["linear_accel_z"] ??
            json["sensor"]?["linear_accel"]?["z"] ??
            0,
      ),
      speed: toDouble(
        json["gps_speed_kmh"] ??
            json["speed_kmh"] ??
            json["speed"] ??
            json["gps"]?["speed_kmh"],
      ),
      source: (json["source"] ?? "backend").toString(),
      backendCategory: normalizeCategory(
        json["category"] ?? json["type"] ?? json["event_type"],
      ),
    );
  }

  String get category {
    if (backendCategory == "pothole" || backendCategory == "bumper") {
      return backendCategory!;
    }

    if (backendCategory == "normal") {
      return "normal";
    }

    if (speed < 3) {
      return "normal";
    }

    if (speed >= 8 && severity >= 4) {
      return "pothole";
    }

    if (speed <= 25 && severity >= 2) {
      return "bumper";
    }

    return "normal";
  }

  bool get isDanger => category == "pothole";

  Pothole copyWith({
    double? lat,
    double? lng,
    double? severity,
    double? speed,
    String? source,
    String? backendCategory,
    DateTime? detectedAt,
  }) {
    return Pothole(
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      severity: severity ?? this.severity,
      speed: speed ?? this.speed,
      source: source ?? this.source,
      backendCategory: backendCategory ?? this.backendCategory,
      detectedAt: detectedAt ?? this.detectedAt,
    );
  }
}
