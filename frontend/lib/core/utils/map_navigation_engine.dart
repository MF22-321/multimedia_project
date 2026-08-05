import 'dart:math';

import 'package:latlong2/latlong.dart';

/// Pure map/navigation calculations shared by the UI and unit tests.
class MapNavigationEngine {
  static double distanceKm(LatLng a, LatLng b) {
    const p = 0.017453292519943295;
    final value =
        0.5 -
        cos((b.latitude - a.latitude) * p) / 2 +
        cos(a.latitude * p) *
            cos(b.latitude * p) *
            (1 - cos((b.longitude - a.longitude) * p)) /
            2;

    return 12742 * asin(sqrt(value));
  }

  static double angleLerp(double from, double to, double factor) {
    final diff = (to - from + 540) % 360 - 180;
    return (from + diff * factor + 360) % 360;
  }

  static LatLng lerpLatLng(LatLng from, LatLng to, double factor) {
    return LatLng(
      from.latitude + (to.latitude - from.latitude) * factor,
      from.longitude + (to.longitude - from.longitude) * factor,
    );
  }

  static double routeLengthKm(List<LatLng> points) {
    if (points.length < 2) return 0;

    double total = 0;
    for (var i = 1; i < points.length; i++) {
      total += distanceKm(points[i - 1], points[i]);
    }
    return total;
  }

  static int nearestRouteIndex(LatLng current, List<LatLng> route) {
    var nearestIndex = 0;
    var nearestDistance = double.infinity;

    for (var i = 0; i < route.length; i++) {
      final distance = distanceKm(current, route[i]);
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearestIndex = i;
      }
    }
    return nearestIndex;
  }

  static double bearingBetween(LatLng from, LatLng to) {
    final lat1 = from.latitude * pi / 180;
    final lat2 = to.latitude * pi / 180;
    final dLon = (to.longitude - from.longitude) * pi / 180;
    final y = sin(dLon) * cos(lat2);
    final x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon);

    return (atan2(y, x) * 180 / pi + 360) % 360;
  }
}
