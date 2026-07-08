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
  final String roadCategory;
  final double? roadSeverity;
  final bool wifiConnected;
  final bool gpsFix;
  final int satellites;
  final String wifiSsid;

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
    this.roadCategory = 'normal',
    this.roadSeverity,
    this.wifiConnected = false,
    bool? gpsFix,
    this.satellites = 0,
    this.wifiSsid = '',
  }) : gpsFix = gpsFix ?? (lat != 0 && lng != 0);

  factory GPSData.fromSerial(String raw) {
    final parts = raw.trim().split(',');

    if (parts.length < 5 || parts[0] != "GPS") {
      throw FormatException("Invalid GPS serial format: $raw");
    }

    double parse(int index) {
      if (index >= parts.length) return 0;
      return double.tryParse(parts[index]) ?? 0;
    }

    final lat = parse(1);
    final lng = parse(2);

    bool parseFlag(int index, {required bool fallback}) {
      if (index >= parts.length) return fallback;
      final value = parts[index].trim().toLowerCase();
      return value == '1' || value == 'true' || value == 'connected';
    }

    return GPSData(
      lat: lat,
      lng: lng,
      speed: parse(3),
      heading: parse(4),

      // Optional dari format baru ESP32
      pitch: parse(5),
      roll: parse(6),
      accelX: parse(7),
      accelY: parse(8),
      accelZ: parse(9),
      roadCategory: _normalizeRoadCategory(
        parts.length > 10 ? parts[10] : null,
      ),
      roadSeverity: parts.length > 11 ? double.tryParse(parts[11]) : null,
      wifiConnected: parseFlag(12, fallback: false),
      gpsFix: parseFlag(13, fallback: lat != 0 && lng != 0),
      satellites: parse(14).toInt(),
      wifiSsid: parts.length > 15 ? parts.sublist(15).join(',').trim() : '',
    );
  }

  static String _normalizeRoadCategory(String? value) {
    final category = value?.trim().toLowerCase();
    if (category == 'pothole' || category == 'bumper') return category!;
    return 'normal';
  }

  double get impact {
    return (accelX * accelX + accelY * accelY + accelZ * accelZ);
  }

  double get linearAccelMagnitude {
    return sqrt(impact);
  }

  bool get isValid {
    return gpsFix && lat != 0 && lng != 0;
  }

  /// True ketika ada koordinat (lat/lng != 0) meskipun satelit < 4.
  /// Dipakai untuk tetap menampilkan marker navigasi walau sinyal lemah.
  bool get hasPosition => lat != 0 && lng != 0;
}
