import 'dart:typed_data';

import 'package:frontend/core/model/gps_data.dart';

/// Stateful decoder for newline-delimited telemetry sent by the ESP32.
///
/// Keeping framing and parsing independent from the physical serial port makes
/// the USB protocol deterministic to test without requiring ESP32 hardware.
class SerialTelemetryDecoder {
  String _buffer = '';

  List<GPSData> add(Uint8List data) {
    _buffer += String.fromCharCodes(data);
    final result = <GPSData>[];

    while (_buffer.contains('\n')) {
      final index = _buffer.indexOf('\n');
      final line = _buffer.substring(0, index).trim();
      _buffer = _buffer.substring(index + 1);

      if (line.isEmpty || !line.startsWith('GPS')) continue;
      result.add(GPSData.fromSerial(line));
    }

    return result;
  }

  void reset() {
    _buffer = '';
  }
}
