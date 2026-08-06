import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/services/drowsiness_api.dart';
import 'package:frontend/core/services/faceid_api.dart';
import 'package:http/http.dart' as http;

class _RecordingClient extends http.BaseClient {
  _RecordingClient(this.handler);

  final Future<http.StreamedResponse> Function(http.BaseRequest request)
  handler;
  final List<http.BaseRequest> requests = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(request);
    return handler(request);
  }
}

http.StreamedResponse _response(Object body, int statusCode) {
  final encoded = utf8.encode(body is String ? body : jsonEncode(body));
  return http.StreamedResponse(Stream.value(encoded), statusCode);
}

void main() {
  const baseUrl = 'http://test.sdt';

  group('FaceIdApi - alur daftar dan login', () {
    test('mengambil daftar driver dan memakai endpoint yang benar', () async {
      final client = _RecordingClient(
        (request) async => _response({
          'drivers': ['Alya', 'Budi'],
        }, 200),
      );

      final drivers = await FaceIdApi.getDrivers(
        client: client,
        baseUrl: baseUrl,
      );

      expect(drivers, ['Alya', 'Budi']);
      expect(client.requests.single.method, 'GET');
      expect(client.requests.single.url.toString(), '$baseUrl/drivers');
    });

    test(
      'gagal mengambil daftar driver dilaporkan sebagai exception',
      () async {
        final client = _RecordingClient((_) async => _response('offline', 503));

        await expectLater(
          FaceIdApi.getDrivers(client: client, baseUrl: baseUrl),
          throwsA(isA<Exception>()),
        );
      },
    );

    test('status wajah terdaftar dapat dipakai untuk auto login', () async {
      final client = _RecordingClient(
        (_) async => _response({
          'recognized': true,
          'driver': 'Alya',
          'confidence': 0.96,
        }, 200),
      );

      final status = await FaceIdApi.getDriverStatus(
        client: client,
        baseUrl: baseUrl,
      );

      expect(status['recognized'], isTrue);
      expect(status['driver'], 'Alya');
      expect(client.requests.single.url.path, '/driver_status');
    });

    test('status wajah gagal tidak menghasilkan login palsu', () async {
      final client = _RecordingClient((_) async => _response('offline', 503));

      await expectLater(
        FaceIdApi.getDriverStatus(client: client, baseUrl: baseUrl),
        throwsA(
          predicate(
            (error) => error.toString().contains('Driver status error'),
          ),
        ),
      );
    });

    test('status enrollment menampilkan fase dan jumlah sampel', () async {
      final client = _RecordingClient(
        (_) async => _response({
          'active': true,
          'phase': 'left',
          'guidance': 'Hadapkan wajah sedikit ke kiri',
          'accepted': 8,
          'rejected': 2,
        }, 200),
      );

      final result = await FaceIdApi.getEnrollmentStatus(
        client: client,
        baseUrl: baseUrl,
      );

      expect(result['phase'], 'left');
      expect(result['accepted'], 8);
      expect(client.requests.single.url.path, '/enrollment_status');
    });

    test('adaptive Face ID dapat dicek, disetujui, dan ditolak', () async {
      final client = _RecordingClient((request) async {
        if (request.url.path.endsWith('/approve')) {
          return _response({'success': true, 'message': 'updated'}, 200);
        }
        if (request.url.path.endsWith('/reject')) {
          return _response({'success': true, 'message': 'discarded'}, 200);
        }
        return _response({
          'available': true,
          'driver_name': 'Alya',
          'condition': 'frontal_dim',
        }, 200);
      });

      final candidate = await FaceIdApi.getAdaptiveCandidate(
        client: client,
        baseUrl: baseUrl,
      );
      final approved = await FaceIdApi.approveAdaptiveCandidate(
        client: client,
        baseUrl: baseUrl,
      );
      final rejected = await FaceIdApi.rejectAdaptiveCandidate(
        client: client,
        baseUrl: baseUrl,
      );

      expect(candidate['available'], isTrue);
      expect(approved['success'], isTrue);
      expect(rejected['success'], isTrue);
      expect(client.requests.map((request) => request.method), [
        'GET',
        'POST',
        'POST',
      ]);
    });

    test('endpoint quality Face ID meneruskan error backend', () async {
      final client = _RecordingClient((_) async => _response('offline', 503));

      await expectLater(
        FaceIdApi.getEnrollmentStatus(client: client, baseUrl: baseUrl),
        throwsA(predicate((error) => error.toString().contains('Enrollment'))),
      );
      await expectLater(
        FaceIdApi.getAdaptiveCandidate(client: client, baseUrl: baseUrl),
        throwsA(predicate((error) => error.toString().contains('candidate'))),
      );
      await expectLater(
        FaceIdApi.approveAdaptiveCandidate(client: client, baseUrl: baseUrl),
        throwsA(predicate((error) => error.toString().contains('approve'))),
      );
      await expectLater(
        FaceIdApi.rejectAdaptiveCandidate(client: client, baseUrl: baseUrl),
        throwsA(predicate((error) => error.toString().contains('reject'))),
      );
    });

    test('capture wajah mengembalikan byte JPEG tanpa perubahan', () async {
      final jpeg = Uint8List.fromList([0xff, 0xd8, 0x01, 0xff, 0xd9]);
      final client = _RecordingClient(
        (_) async => http.StreamedResponse(Stream.value(jpeg), 200),
      );

      final result = await FaceIdApi.captureFace(
        client: client,
        baseUrl: baseUrl,
      );

      expect(result, jpeg);
      expect(client.requests.single.url.path, '/capture_face');
    });

    test('capture wajah gagal tidak dikira sebagai gambar valid', () async {
      final client = _RecordingClient(
        (_) async => _response('camera off', 503),
      );

      await expectLater(
        FaceIdApi.captureFace(client: client, baseUrl: baseUrl),
        throwsA(
          predicate((error) => error.toString().contains('Capture face error')),
        ),
      );
    });

    test(
      'daftar satu foto mengirim nama dan berkas sebagai multipart',
      () async {
        late http.MultipartRequest captured;
        final client = _RecordingClient((request) async {
          captured = request as http.MultipartRequest;
          return _response({
            'success': true,
            'driver_name': 'Alya',
            'label_id': 1,
          }, 200);
        });

        final result = await FaceIdApi.enrollDriver(
          driverName: 'Alya',
          imageBytes: Uint8List.fromList([1, 2, 3]),
          client: client,
          baseUrl: baseUrl,
        );

        expect(result['success'], isTrue);
        expect(captured.method, 'POST');
        expect(captured.url.path, '/enroll');
        expect(captured.fields['driver_name'], 'Alya');
        expect(captured.files.single.field, 'image');
        expect(captured.files.single.filename, 'capture.jpg');
        expect(captured.files.single.length, 3);
      },
    );

    test('daftar live burst mengirim semua parameter registrasi', () async {
      late http.MultipartRequest captured;
      final client = _RecordingClient((request) async {
        captured = request as http.MultipartRequest;
        return _response({'success': true, 'saved_count': 60}, 200);
      });

      final result = await FaceIdApi.enrollLiveBurst(
        driverName: 'Alya',
        durationSec: 8,
        targetSamples: 60,
        client: client,
        baseUrl: baseUrl,
      );

      expect(result['saved_count'], 60);
      expect(captured.url.path, '/enroll_live_burst');
      expect(captured.fields, {
        'driver_name': 'Alya',
        'duration_sec': '8.0',
        'target_samples': '60',
      });
    });

    test('kegagalan live burst tidak dianggap registrasi sukses', () async {
      final client = _RecordingClient(
        (_) async =>
            _response({'success': false, 'message': 'No face samples'}, 422),
      );

      await expectLater(
        FaceIdApi.enrollLiveBurst(
          driverName: 'Alya',
          client: client,
          baseUrl: baseUrl,
        ),
        throwsA(
          predicate((error) => error.toString().contains('No face samples')),
        ),
      );
    });

    test('kegagalan enroll dari backend diteruskan ke UI', () async {
      final client = _RecordingClient(
        (_) async => _response({'success': false, 'message': 'No face'}, 422),
      );

      await expectLater(
        FaceIdApi.enrollDriver(
          driverName: 'Alya',
          imageBytes: Uint8List(1),
          client: client,
          baseUrl: baseUrl,
        ),
        throwsA(predicate((error) => error.toString().contains('No face'))),
      );
    });

    test('hapus driver memangkas dan meng-encode nama', () async {
      final client = _RecordingClient(
        (_) async =>
            _response({'success': true, 'driver_name': 'Alya Putri'}, 200),
      );

      final result = await FaceIdApi.deleteDriver(
        '  Alya Putri  ',
        client: client,
        baseUrl: baseUrl,
      );

      expect(result['success'], isTrue);
      expect(client.requests.single.method, 'DELETE');
      expect(client.requests.single.url.pathSegments.last, 'Alya Putri');
      expect(
        client.requests.single.url.toString(),
        '$baseUrl/driver/Alya%20Putri',
      );
    });

    test('hapus driver success false tetap dianggap gagal', () async {
      final client = _RecordingClient(
        (_) async =>
            _response({'success': false, 'message': 'Driver not found'}, 200),
      );

      await expectLater(
        FaceIdApi.deleteDriver('Nobody', client: client, baseUrl: baseUrl),
        throwsA(
          predicate((error) => error.toString().contains('Driver not found')),
        ),
      );
    });
  });

  group('DrowsinessApi - alur monitoring pengemudi', () {
    test('start mengirim nama driver sebagai JSON', () async {
      late http.Request captured;
      final client = _RecordingClient((request) async {
        captured = request as http.Request;
        return _response({
          'success': true,
          'active': true,
          'driver_name': 'Alya',
        }, 200);
      });

      final result = await DrowsinessApi.startDrowsiness(
        driverName: 'Alya',
        client: client,
        baseUrl: baseUrl,
      );

      expect(result['active'], isTrue);
      expect(captured.method, 'POST');
      expect(captured.url.path, '/start_drowsiness');
      expect(jsonDecode(captured.body), {'driver_name': 'Alya'});
      expect(captured.headers['content-type'], contains('application/json'));
    });

    test('status mengembalikan deteksi kantuk dan mood', () async {
      final client = _RecordingClient(
        (_) async => _response({
          'active': true,
          'status': 'normal',
          'mood': 'happy',
        }, 200),
      );

      final result = await DrowsinessApi.getDrowsinessStatus(
        client: client,
        baseUrl: baseUrl,
      );

      expect(result['status'], 'normal');
      expect(result['mood'], 'happy');
      expect(client.requests.single.url.path, '/drowsiness_status');
    });

    test('stop menonaktifkan monitoring', () async {
      final client = _RecordingClient(
        (_) async => _response({'success': true, 'active': false}, 200),
      );

      final result = await DrowsinessApi.stopDrowsiness(
        client: client,
        baseUrl: baseUrl,
      );

      expect(result['active'], isFalse);
      expect(client.requests.single.method, 'POST');
      expect(client.requests.single.url.path, '/stop_drowsiness');
    });

    test('error start, stop, dan status tidak dianggap sukses', () async {
      final client = _RecordingClient(
        (_) async => _response('backend error', 500),
      );

      await expectLater(
        DrowsinessApi.startDrowsiness(
          driverName: 'Alya',
          client: client,
          baseUrl: baseUrl,
        ),
        throwsA(isA<Exception>()),
      );
      await expectLater(
        DrowsinessApi.stopDrowsiness(client: client, baseUrl: baseUrl),
        throwsA(isA<Exception>()),
      );
      await expectLater(
        DrowsinessApi.getDrowsinessStatus(client: client, baseUrl: baseUrl),
        throwsA(isA<Exception>()),
      );
    });
  });
}
