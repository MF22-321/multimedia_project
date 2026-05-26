import 'dart:math';

class GPSData {
  final double lat;
  final double lng;
  final double speed;
  final double heading;

  final double pitch;
  final double roll;

  final double accelX;
  final double accelY;
  final double accelZ;

  GPSData({
    required this.lat,
    required this.lng,
    required this.speed,
    required this.heading,
    required this.pitch,
    required this.roll,
    required this.accelX,
    required this.accelY,
    required this.accelZ,
  });

  factory GPSData.fromSerial(String raw) {
    final parts = raw.trim().split(',');

    if (parts.length < 5 || parts[0] != "GPS") {
      throw FormatException("Invalid GPS serial format: $raw");
    }

    double parse(int index) {
      if (index >= parts.length) return 0;
      return double.tryParse(parts[index]) ?? 0;
    }

    return GPSData(
      lat: parse(1),
      lng: parse(2),
      speed: parse(3),
      heading: parse(4),

      // Optional dari format baru ESP32
      pitch: parse(5),
      roll: parse(6),
      accelX: parse(7),
      accelY: parse(8),
      accelZ: parse(9),
    );
  }

  double get impact {
    return (accelX * accelX + accelY * accelY + accelZ * accelZ);
  }

  double get linearAccelMagnitude {
    return sqrt(impact);
  }

  bool get isValid {
    return lat != 0 && lng != 0;
  }
}
