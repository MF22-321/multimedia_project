import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/model/gps_data.dart';
import 'package:frontend/core/model/pothole.dart';
import 'package:frontend/core/services/pothole_service.dart';
import 'package:frontend/core/utils/pothole_detection_engine.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';

void main() {
  setUp(PotholeDetectionEngine.resetLiveDetectionState);

  test('GPS parser supports extended ESP32 telemetry', () {
    final gps = GPSData.fromSerial(
      'GPS,-6.3,107.2,15,90,1,2,3,4,12,pothole,5.5,1,1,7,Febrian',
    );

    expect(gps.lat, -6.3);
    expect(gps.heading, 90);
    expect(gps.linearAccelMagnitude, 13);
    expect(gps.isValid, isTrue);
    expect(gps.roadCategory, 'pothole');
    expect(gps.roadSeverity, 5.5);
    expect(gps.wifiConnected, isTrue);
    expect(gps.gpsFix, isTrue);
    expect(gps.satellites, 7);
    expect(gps.wifiSsid, 'Febrian');
  });

  test('USB telemetry remains usable while WiFi and GPS are offline', () {
    final gps = GPSData.fromSerial(
      'GPS,0,0,0,94,3,-7,-0.1,-0.2,-0.3,normal,0.4,0,0,0,Febrian',
    );

    expect(gps.isValid, isFalse);
    expect(gps.heading, 94);
    expect(gps.wifiConnected, isFalse);
    expect(gps.wifiSsid, 'Febrian');
  });

  test('GPS parser stays compatible with old telemetry format', () {
    final gps = GPSData.fromSerial('GPS,-6.3,107.2,15,90,1,2,3,4,12');
    expect(gps.roadCategory, 'normal');
    expect(gps.roadSeverity, isNull);
  });

  test('GPS parser rejects malformed prefix', () {
    expect(() => GPSData.fromSerial('IMU,1,2,3,4'), throwsFormatException);
  });

  test('backend category overrides local classification', () {
    final hazard = Pothole(
      lat: -6.3,
      lng: 107.2,
      severity: 0,
      speed: 0,
      backendCategory: 'pothole',
    );

    expect(hazard.category, 'pothole');
    expect(hazard.isDanger, isTrue);
  });

  test('classifies telemetry thresholds', () {
    expect(Pothole(lat: 1, lng: 1, severity: 4, speed: 8).category, 'pothole');
    expect(Pothole(lat: 1, lng: 1, severity: 2, speed: 20).category, 'bumper');
    expect(Pothole(lat: 1, lng: 1, severity: 10, speed: 2).category, 'normal');
  });

  test('finds only hazards ahead within alert radius', () {
    final ahead = Pothole(
      lat: -6.2997,
      lng: 107.2,
      severity: 5,
      speed: 10,
      backendCategory: 'pothole',
    );
    final behind = Pothole(
      lat: -6.3003,
      lng: 107.2,
      severity: 5,
      speed: 10,
      backendCategory: 'pothole',
    );

    final found = PotholeDetectionEngine.findHazardAhead(
      current: const LatLng(-6.3, 107.2),
      heading: 0,
      hazards: [behind, ahead],
    );

    expect(found, same(ahead));
  });

  test('angle difference wraps across north', () {
    expect(PotholeDetectionEngine.angleDiff(350, 10), 20);
  });

  test('explicit ESP32 speed bump becomes a marker immediately', () {
    final gps = GPSData.fromSerial(
      'GPS,-6.3,107.2,12,90,1,2,0.1,0.2,0.3,bumper,2.8,1,1,7,Febrian',
    );

    final marker = PotholeDetectionEngine.liveHazardFromTelemetry(gps);

    expect(marker, isNotNull);
    expect(marker?.category, 'bumper');
    expect(marker?.lat, -6.3);
    expect(marker?.lng, 107.2);
  });

  test('public pothole API works without an authorization token', () async {
    final client = MockClient((request) async {
      expect(request.headers.containsKey('Authorization'), isFalse);
      return http.Response('{"data":[]}', 200);
    });

    final hazards = await PotholeService(
      token: '',
      client: client,
    ).fetchPotholes();
    expect(hazards, isEmpty);
  });

  test(
    'pothole API parses valid coordinates and filters zero values',
    () async {
      final client = MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer test-token');
        return http.Response(
          jsonEncode({
            'data': [
              {
                'gps_lat': '-6.3',
                'gps_lng': '107.2',
                'severity': 5,
                'gps_speed_kmh': 10,
              },
              {'gps_lat': 0, 'gps_lng': 0},
            ],
          }),
          200,
        );
      });

      final hazards = await PotholeService(
        token: 'test-token',
        client: client,
      ).fetchPotholes();

      expect(hazards, hasLength(1));
      expect(hazards.single.category, 'pothole');
    },
  );
}
