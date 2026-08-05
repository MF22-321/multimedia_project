import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/services/serial_telemetry_decoder.dart';

Uint8List bytes(String value) => Uint8List.fromList(value.codeUnits);

void main() {
  test('keeps partial frames and emits a complete GPS frame', () {
    final decoder = SerialTelemetryDecoder();

    expect(decoder.add(bytes('GPS,-6.3,107.2,')), isEmpty);
    final decoded = decoder.add(bytes('10,90\n'));

    expect(decoded, hasLength(1));
    expect(decoded.single.lat, -6.3);
    expect(decoded.single.heading, 90);
  });

  test('ignores empty/debug frames and decodes multiple GPS frames', () {
    final decoder = SerialTelemetryDecoder();
    final decoded = decoder.add(
      bytes('\nDEBUG:IMU\nGPS,1,2,3,4\r\nGPS,5,6,7,8\n'),
    );

    expect(decoded.map((item) => item.lat), [1, 5]);
  });

  test('reset discards an unfinished frame', () {
    final decoder = SerialTelemetryDecoder();
    decoder.add(bytes('GPS,1,2'));
    decoder.reset();

    expect(decoder.add(bytes(',3,4\n')), isEmpty);
  });

  test('reports a malformed GPS frame to its caller', () {
    final decoder = SerialTelemetryDecoder();
    expect(() => decoder.add(bytes('GPS,1\n')), throwsFormatException);
  });
}
