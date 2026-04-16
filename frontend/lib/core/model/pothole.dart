class Pothole {
  final double lat;
  final double lng;
  final double severity;

  Pothole({
    required this.lat,
    required this.lng,
    required this.severity,
  });

  factory Pothole.fromJson(Map<String, dynamic> json) {
    return Pothole(
      lat: json["gps"]["lat"],
      lng: json["gps"]["lng"],
      severity: (json["severity"] ?? 0).toDouble(),
    );
  }
}