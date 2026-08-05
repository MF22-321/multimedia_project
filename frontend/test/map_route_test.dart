import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/services/map_tile_config.dart';
import 'package:frontend/core/services/route_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';

void main() {
  group('CartoDB/OpenStreetMap configuration', () {
    test('uses Voyager HTTPS tiles and supported zoom', () {
      expect(
        MapTileConfig.urlTemplate,
        'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
      );
      expect(MapTileConfig.subdomains, ['a', 'b', 'c', 'd']);
      expect(MapTileConfig.maxZoom, 19);
      expect(MapTileConfig.userAgentPackageName, isNotEmpty);
      expect(MapTileConfig.attribution, contains('OpenStreetMap'));
      expect(MapTileConfig.attributionUri.host, 'www.openstreetmap.org');
    });
  });

  group('OSRM route parsing', () {
    test('converts GeoJSON longitude-latitude into LatLng', () async {
      late Uri requestedUri;
      final client = MockClient((request) async {
        requestedUri = request.url;
        return http.Response(
          jsonEncode({
            'routes': [
              {
                'geometry': {
                  'coordinates': [
                    [107.1, -6.3],
                    [107.2, -6.4],
                  ],
                },
              },
            ],
          }),
          200,
        );
      });

      final route = await RouteService(
        client: client,
      ).getRoute(const LatLng(-6.3, 107.1), const LatLng(-6.4, 107.2));

      expect(requestedUri.host, 'router.project-osrm.org');
      expect(requestedUri.queryParameters['geometries'], 'geojson');
      expect(route, [const LatLng(-6.3, 107.1), const LatLng(-6.4, 107.2)]);
    });

    test('rejects response without route geometry', () async {
      final client = MockClient(
        (_) async => http.Response('{"routes":[]}', 200),
      );

      expect(
        RouteService(
          client: client,
        ).getRoute(const LatLng(-6.3, 107.1), const LatLng(-6.4, 107.2)),
        throwsA(isA<Exception>()),
      );
    });

    test('rejects non-success response', () async {
      final client = MockClient((_) async => http.Response('error', 503));

      expect(
        RouteService(
          client: client,
        ).getRoute(const LatLng(-6.3, 107.1), const LatLng(-6.4, 107.2)),
        throwsA(isA<Exception>()),
      );
    });

    test('rejects route with fewer than two coordinates', () async {
      final client = MockClient(
        (_) async => http.Response(
          '{"routes":[{"geometry":{"coordinates":[[107.1,-6.3]]}}]}',
          200,
        ),
      );

      expect(
        RouteService(
          client: client,
        ).getRoute(const LatLng(-6.3, 107.1), const LatLng(-6.4, 107.2)),
        throwsA(isA<Exception>()),
      );
    });
  });
}
