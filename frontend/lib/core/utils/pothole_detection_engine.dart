import 'dart:math';

import 'package:frontend/core/model/gps_data.dart';
import 'package:frontend/core/model/pothole.dart';
import 'package:latlong2/latlong.dart';

class PotholeDetectionEngine {
  static const double livePotholeThreshold = 2.5;
  static const double liveBumperThreshold = 1.2;
  static const double minSpeedDetect = 2.0;
  static const double potholeMinSpeed = 8;
  static const double bumperMaxSpeed = 12;
  static const double alertRadiusKm = 0.05;
  static const double routeHazardRadiusKm = 0.02;
  static const double aheadBearingWindow = 75;
  static double _previousLiveMagnitude = 0;

  static List<Pothole> activeHazards(List<Pothole> hazards) {
    return hazards.where((hazard) => hazard.category != "normal").toList()
      ..sort((a, b) => b.severity.compareTo(a.severity));
  }

  static Pothole? liveHazardFromTelemetry(GPSData gps) {
    if (!gps.isValid) return null;

    final magnitude = gps.linearAccelMagnitude;
    final severity = (magnitude + _previousLiveMagnitude) / 2.0;
    _previousLiveMagnitude = magnitude;

    final speed = gps.speed;

    if (speed < minSpeedDetect) return null;

    final isPothole = speed > potholeMinSpeed &&
        severity >= livePotholeThreshold;

    final isBumper = speed <= bumperMaxSpeed &&
        severity >= liveBumperThreshold;

    if (!isPothole && !isBumper) return null;

    return Pothole(
      lat: gps.lat,
      lng: gps.lng,
      severity: severity,
      speed: speed,
      source: "esp32",
      detectedAt: DateTime.now(),
    );
  }

  static Pothole? findHazardAhead({
    required LatLng current,
    required double heading,
    required List<Pothole> hazards,
    double radiusKm = alertRadiusKm,
  }) {
    Pothole? closest;
    double? closestDistance;

    for (final hazard in hazards) {
      if (hazard.category == "normal") continue;

      final distance = distanceKm(
        current.latitude,
        current.longitude,
        hazard.lat,
        hazard.lng,
      );

      if (distance > radiusKm) continue;

      final bearingToHazard = bearing(
        current.latitude,
        current.longitude,
        hazard.lat,
        hazard.lng,
      );

      if (angleDiff(bearingToHazard, heading) > aheadBearingWindow) {
        continue;
      }

      if (closestDistance == null || distance < closestDistance) {
        closest = hazard;
        closestDistance = distance;
      }
    }

    return closest;
  }

  static List<LatLng> routeHazardPoints(
    List<LatLng> route,
    List<Pothole> hazards,
    String category,
  ) {
    final result = <LatLng>[];

    for (final routePoint in route) {
      final hasHazard = hazards.any((hazard) {
        if (hazard.category != category) return false;

        return distanceKm(
              routePoint.latitude,
              routePoint.longitude,
              hazard.lat,
              hazard.lng,
            ) <
            routeHazardRadiusKm;
      });

      if (hasHazard) {
        result.add(routePoint);
      }
    }

    return result;
  }

  static double distanceKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const p = 0.017453292519943295;

    final a =
        0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;

    return 12742 * asin(sqrt(a));
  }

  static double bearing(double lat1, double lon1, double lat2, double lon2) {
    final dLon = (lon2 - lon1) * pi / 180;
    final y = sin(dLon) * cos(lat2 * pi / 180);
    final x =
        cos(lat1 * pi / 180) * sin(lat2 * pi / 180) -
        sin(lat1 * pi / 180) * cos(lat2 * pi / 180) * cos(dLon);

    return (atan2(y, x) * 180 / pi + 360) % 360;
  }

  static double angleDiff(double a, double b) {
    final diff = (a - b).abs();
    return diff > 180 ? 360 - diff : diff;
  }
}
