class GPSData {
  final double lat;
  final double lng;
  final double speed;
  final double heading;

  GPSData({
    required this.lat,
    required this.lng,
    required this.speed,
    required this.heading,
  });

  factory GPSData.fromSerial(String raw) {
    final parts = raw.split(',');

    return GPSData(
      lat: double.parse(parts[1]),
      lng: double.parse(parts[2]),
      speed: double.parse(parts[3]),
      heading: double.parse(parts[4]),
    );
  }
}