class GPSData {

  final double lat;
  final double lng;
  final double speed;

  GPSData({
    required this.lat,
    required this.lng,
    required this.speed
  });

  factory GPSData.fromSerial(String line) {

    // GPS,-6.324234,107.213421,32.15

    final parts = line.split(",");

    return GPSData(
      lat: double.parse(parts[1]),
      lng: double.parse(parts[2]),
      speed: double.parse(parts[3]),
    );
  }
}