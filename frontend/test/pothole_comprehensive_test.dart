import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/model/gps_data.dart';
import 'package:frontend/core/model/pothole.dart';
import 'package:frontend/core/services/pothole_service.dart';
import 'package:frontend/core/utils/pothole_detection_engine.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';

GPSData telemetry({
  double lat = -6.3,
  double lng = 107.2,
  double speed = 10,
  double acceleration = 0,
  String category = 'normal',
  double? severity,
  bool? gpsFix = true,
}) {
  return GPSData(
    lat: lat,
    lng: lng,
    speed: speed,
    heading: 0,
    pitch: 0,
    roll: 0,
    accelX: acceleration,
    accelY: 0,
    accelZ: 0,
    roadCategory: category,
    roadSeverity: severity,
    gpsFix: gpsFix,
  );
}

void main() {
  setUp(PotholeDetectionEngine.resetLiveDetectionState);

  group('GPS telemetry model', () {
    test('constructor derives fix and exposes position and impact', () {
      final gps = telemetry(gpsFix: null, acceleration: 3);
      expect(gps.gpsFix, isTrue);
      expect(gps.hasPosition, isTrue);
      expect(gps.impact, 9);
      expect(gps.linearAccelMagnitude, 3);
    });

    test('short and invalid numeric frames use protocol fallbacks', () {
      final gps = GPSData.fromSerial('GPS,bad,107.2,bad,90');
      expect(gps.lat, 0);
      expect(gps.pitch, 0);
      expect(gps.wifiConnected, isFalse);
      expect(gps.gpsFix, isFalse);
      expect(gps.hasPosition, isFalse);
    });

    test('normalizes flags, category, and SSID containing commas', () {
      final connected = GPSData.fromSerial(
        'GPS,1,2,3,4,0,0,0,0,0,BUMPER,bad,connected,true,6,my,wifi',
      );
      expect(connected.roadCategory, 'bumper');
      expect(connected.roadSeverity, isNull);
      expect(connected.wifiConnected, isTrue);
      expect(connected.gpsFix, isTrue);
      expect(connected.wifiSsid, 'my,wifi');

      final unknown = GPSData.fromSerial(
        'GPS,1,2,3,4,0,0,0,0,0,unknown,1,false,no,4,wifi',
      );
      expect(unknown.roadCategory, 'normal');
      expect(unknown.wifiConnected, isFalse);
      expect(unknown.gpsFix, isFalse);
    });

    test('rejects frames that are too short', () {
      expect(() => GPSData.fromSerial('GPS,1'), throwsFormatException);
    });
  });

  group('Pothole model', () {
    test('parses nested fallback payloads and category aliases', () {
      final bump = Pothole.fromJson({
        'gps': {'lat': '-6.3', 'lng': 107.2, 'speed_kmh': '12'},
        'sensor': {
          'linear_accel': {'z': '2.5'},
        },
        'source': 'sensor',
        'type': 'speed bump event',
      });
      expect(bump.category, 'bumper');
      expect(bump.source, 'sensor');

      expect(
        Pothole.fromJson({'event_type': 'lubang jalan'}).category,
        'pothole',
      );
      expect(Pothole.fromJson({'category': 'normal'}).category, 'normal');
      expect(
        Pothole.fromJson({'category': 'custom'}).backendCategory,
        'custom',
      );
      expect(Pothole.fromJson({'category': ''}).backendCategory, isNull);
      expect(Pothole.fromJson({'severity': 'bad'}).severity, 0);
    });

    test('covers every local classification boundary', () {
      expect(
        Pothole(lat: 1, lng: 1, severity: 1, speed: 10).category,
        'normal',
      );
      expect(
        Pothole(lat: 1, lng: 1, severity: 3, speed: 30).category,
        'normal',
      );
      expect(
        Pothole(
          lat: 1,
          lng: 1,
          severity: 1,
          speed: 1,
          backendCategory: 'bumper',
        ).category,
        'bumper',
      );
    });

    test('copyWith replaces every field and retains omitted fields', () {
      final time = DateTime(2026);
      final original = Pothole(lat: 1, lng: 2, severity: 3, speed: 4);
      final copy = original.copyWith(
        lat: 5,
        lng: 6,
        severity: 7,
        speed: 8,
        source: 'esp32',
        backendCategory: 'pothole',
        detectedAt: time,
      );
      expect(
        [copy.lat, copy.lng, copy.severity, copy.speed, copy.source],
        [5, 6, 7, 8, 'esp32'],
      );
      expect(copy.detectedAt, time);
      expect(copy.copyWith().backendCategory, 'pothole');
    });
  });

  group('Pothole detection engine', () {
    test('sorts active hazards by severity and drops normal data', () {
      final active = PotholeDetectionEngine.activeHazards([
        Pothole(
          lat: 1,
          lng: 1,
          severity: 2,
          speed: 10,
          backendCategory: 'bumper',
        ),
        Pothole(lat: 1, lng: 1, severity: 0, speed: 0),
        Pothole(
          lat: 1,
          lng: 1,
          severity: 5,
          speed: 10,
          backendCategory: 'pothole',
        ),
      ]);
      expect(active.map((item) => item.severity), [5, 2]);
    });

    test('rejects invalid, slow, and below-threshold telemetry', () {
      expect(
        PotholeDetectionEngine.liveHazardFromTelemetry(
          telemetry(lat: 0, lng: 0, gpsFix: false),
        ),
        isNull,
      );
      expect(
        PotholeDetectionEngine.liveHazardFromTelemetry(
          telemetry(speed: 2, acceleration: 10),
        ),
        isNull,
      );
      expect(
        PotholeDetectionEngine.liveHazardFromTelemetry(
          telemetry(speed: 30, acceleration: 1),
        ),
        isNull,
      );
    });

    test('requires two local samples before creating a pothole', () {
      final gps = telemetry(speed: 10, acceleration: 5);
      expect(PotholeDetectionEngine.liveHazardFromTelemetry(gps), isNull);
      final detected = PotholeDetectionEngine.liveHazardFromTelemetry(gps);
      expect(detected?.category, 'pothole');
      expect(PotholeDetectionEngine.liveHazardFromTelemetry(gps), isNull);
      expect(
        PotholeDetectionEngine.liveHazardFromTelemetry(
          telemetry(speed: 10, category: 'pothole', severity: 5),
        ),
        isNull,
      );
    });

    test('creates a locally classified bumper after two samples', () {
      final gps = telemetry(speed: 10, acceleration: 3);
      expect(PotholeDetectionEngine.liveHazardFromTelemetry(gps), isNull);
      expect(PotholeDetectionEngine.liveHazardFromTelemetry(gps), isNull);
      expect(
        PotholeDetectionEngine.liveHazardFromTelemetry(gps)?.category,
        'bumper',
      );
    });

    test('device pothole bypasses consecutive sample requirement', () {
      final hazard = PotholeDetectionEngine.liveHazardFromTelemetry(
        telemetry(speed: 10, category: 'pothole', severity: 5),
      );
      expect(hazard?.category, 'pothole');
    });

    test('finds closest relevant hazard and maps route hazard points', () {
      Pothole hazard(double lat, String category) => Pothole(
        lat: lat,
        lng: 107.2,
        severity: 5,
        speed: 10,
        backendCategory: category,
      );

      final farAhead = hazard(-6.2997, 'pothole');
      final nearAhead = hazard(-6.2999, 'pothole');
      final found = PotholeDetectionEngine.findHazardAhead(
        current: const LatLng(-6.3, 107.2),
        heading: 0,
        hazards: [
          hazard(-6.3, 'normal'),
          hazard(-6.29, 'pothole'),
          hazard(-6.3001, 'pothole'),
          farAhead,
          nearAhead,
        ],
      );
      expect(found, same(nearAhead));

      final points = PotholeDetectionEngine.routeHazardPoints(
        const [LatLng(-6.3, 107.2), LatLng(-6.29, 107.2)],
        [nearAhead, hazard(-6.3, 'bumper')],
        'pothole',
      );
      expect(points, [const LatLng(-6.3, 107.2)]);
    });

    test('calculates distance, bearing, and direct angle difference', () {
      expect(PotholeDetectionEngine.distanceKm(0, 0, 0, 0), 0);
      expect(PotholeDetectionEngine.bearing(0, 0, 1, 0), closeTo(0, 0.01));
      expect(PotholeDetectionEngine.angleDiff(10, 30), 20);
    });
  });

  group('Pothole API', () {
    test('default configuration can be constructed', () {
      final service = PotholeService();
      expect(service.baseUrl, contains('/api/v1'));
      expect(service.token, isEmpty);
    });

    test('rejects invalid payload and non-success response', () async {
      final invalidPayload = PotholeService(
        client: MockClient((_) async => http.Response('{"data":{}}', 200)),
      );
      await expectLater(invalidPayload.fetchPotholes(), throwsException);

      final failed = PotholeService(
        client: MockClient((_) async => http.Response('error', 500)),
      );
      await expectLater(failed.fetchPotholes(), throwsException);
    });

    test('ignores non-map records in a successful payload', () async {
      final service = PotholeService(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'data': [
                'invalid',
                {'gps_lat': 1, 'gps_lng': 2},
              ],
            }),
            200,
          ),
        ),
      );
      expect(await service.fetchPotholes(), hasLength(1));
    });
  });
}
