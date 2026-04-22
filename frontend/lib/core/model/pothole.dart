class Pothole {
  final double lat;
  final double lng;
  final double severity;
  final double speed;

  Pothole({
    required this.lat,
    required this.lng,
    required this.severity,
    required this.speed,
  });

  factory Pothole.fromJson(Map<String, dynamic> json) {
    return Pothole(
      lat: (json["gps"]["lat"] ?? 0).toDouble(),
      lng: (json["gps"]["lng"] ?? 0).toDouble(),
      severity: (json["severity"] ?? 0).toDouble(),
      speed: (json["gps"]["speed_kmh"] ?? 0).toDouble(),
    );
  }

  /// =========================
  /// AUTO CATEGORY
  /// =========================
  String get category {
    // pothole valid
    if (severity > 1.5 && speed > 8) {
      return "pothole";
    }

    // speed bump / polisi tidur
    if (severity > 0.8 && speed <= 10) {
      return "bumper";
    }

    return "normal";
  }

  bool get isDanger => category == "pothole";
}