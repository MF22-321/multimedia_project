import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/utils/map_navigation_engine.dart';
import 'package:latlong2/latlong.dart';

void main() {
  const origin = LatLng(-6.3, 107.2);
  const north = LatLng(-6.299, 107.2);
  const east = LatLng(-6.3, 107.201);

  test('calculates distance, route length, and short routes', () {
    final segment = MapNavigationEngine.distanceKm(origin, north);
    expect(segment, closeTo(0.111, 0.003));
    expect(MapNavigationEngine.routeLengthKm(const []), 0);
    expect(
      MapNavigationEngine.routeLengthKm(const [origin, north, east]),
      greaterThan(segment),
    );
  });

  test('interpolates angles through north and coordinates linearly', () {
    expect(MapNavigationEngine.angleLerp(350, 10, 0.5), 0);
    expect(MapNavigationEngine.angleLerp(10, 30, 0.5), 20);
    expect(
      MapNavigationEngine.lerpLatLng(origin, north, 0.5),
      const LatLng(-6.2995, 107.2),
    );
  });

  test('finds nearest route point and handles an empty route', () {
    expect(
      MapNavigationEngine.nearestRouteIndex(
        const LatLng(-6.2991, 107.2),
        const [origin, north, east],
      ),
      1,
    );
    expect(MapNavigationEngine.nearestRouteIndex(origin, const []), 0);
  });

  test('calculates cardinal bearings', () {
    expect(MapNavigationEngine.bearingBetween(origin, north), closeTo(0, 0.1));
    expect(MapNavigationEngine.bearingBetween(origin, east), closeTo(90, 0.1));
  });
}
