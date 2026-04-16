import 'dart:async';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'package:frontend/core/model/gps_data.dart';

class SerialService {
  SerialPort? _port;
  SerialPortReader? _reader;

  final _controller = StreamController<GPSData>.broadcast();
  Stream<GPSData> get stream => _controller.stream;

  String _buffer = "";

  void start() {
    try {
      final ports = SerialPort.availablePorts;

      print("AVAILABLE PORTS: $ports");

      if (ports.isEmpty) {
        print("No serial device");
        return;
      }

      final portName = ports.first;

      print("Using port: $portName");

      _port = SerialPort(portName);

      /// OPEN PORT
      if (!_port!.openRead()) {
        print("Failed open serial");
        return;
      }

      /// CONFIG SERIAL
      final config = _port!.config;

      config.baudRate = 115200;
      config.bits = 8;
      config.stopBits = 1;
      config.parity = SerialPortParity.none;

      _port!.config = config;

      /// START READER
      _reader = SerialPortReader(_port!);

      _reader!.stream.listen((data) {
        _buffer += String.fromCharCodes(data);

        /// cek jika ada newline
        if (_buffer.contains("\n")) {
          final lines = _buffer.split("\n");

          /// simpan sisa buffer
          _buffer = lines.last;

          for (final line in lines) {
            final clean = line.trim();

            if (clean.isEmpty) continue;

            print("SERIAL: $clean");

            /// hanya parsing GPS
            if (clean.startsWith("GPS")) {
              final parts = clean.split(",");

              if (parts.length < 4) {
                return;
              }

              try {
                final gps = GPSData.fromSerial(clean);
                _controller.add(gps);
              } catch (e) {
                print("Parse error: $e");
              }
            }
          }
        }
      });
    } catch (e) {
      print("Serial error: $e");
    }
  }
}
