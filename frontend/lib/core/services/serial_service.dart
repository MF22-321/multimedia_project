import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'package:frontend/core/model/gps_data.dart';
import 'package:frontend/core/services/serial_telemetry_decoder.dart';
import 'package:frontend/core/utils/app_logger.dart';

class SerialService {
  SerialPort? _port;
  SerialPortReader? _reader;
  StreamSubscription? _readerSub;
  Timer? _scanTimer;

  final _controller = StreamController<GPSData>.broadcast();
  Stream<GPSData> get stream => _controller.stream;
  final _statusController = StreamController<String>.broadcast();
  Stream<String> get statusStream => _statusController.stream;

  final SerialTelemetryDecoder _decoder = SerialTelemetryDecoder();

  bool _connected = false;
  bool _disposed = false;
  String? _currentPort;
  List<String> _lastPorts = [];
  String? _lastStatus;

  void _emitStatus(String status) {
    if (_disposed || status == _lastStatus) return;
    _lastStatus = status;
    _statusController.add(status);
  }

  // ================= START =================
  void start() {
    _emitStatus("Scanning USB device...");
    _startAutoScan();
  }

  // ================= AUTO SCAN =================
  void _startAutoScan() {
    _scanTimer?.cancel();

    _scanTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _scanPorts(),
    );

    _scanPorts();
  }

  void _scanPorts() {
    if (_disposed) return;
    if (_connected) return;

    try {
      final ports = _availablePorts();

      // print hanya jika berubah
      if (ports.toString() != _lastPorts.toString()) {
        AppLogger.info("AVAILABLE PORTS: $ports");
        _lastPorts = List.from(ports);
      }

      if (ports.isEmpty) {
        _emitStatus("ESP32 USB device not found");
        return;
      }

      var connected = false;
      for (final portName in ports) {
        if (_tryConnect(portName)) {
          connected = true;
          break;
        }
      }

      if (!connected) {
        _emitStatus("ESP32 USB port busy or unavailable");
      }
    } catch (e) {
      AppLogger.error("SCAN ERROR: $e");
    }
  }

  List<String> _availablePorts() {
    final ports = <String>{...SerialPort.availablePorts};

    if (Platform.isLinux) {
      try {
        for (final entity in Directory('/dev').listSync()) {
          final path = entity.path;
          if (path.startsWith('/dev/ttyCH341USB') ||
              path.startsWith('/dev/ttyUSB') ||
              path.startsWith('/dev/ttyACM')) {
            ports.add(path);
          }
        }
      } catch (e) {
        AppLogger.error("LINUX SERIAL SCAN ERROR: $e");
      }
    }

    final result = ports.toList();
    result.sort((a, b) {
      final aPriority = a.startsWith('/dev/ttyCH341USB') ? 0 : 1;
      final bPriority = b.startsWith('/dev/ttyCH341USB') ? 0 : 1;
      final priority = aPriority.compareTo(bPriority);
      return priority != 0 ? priority : a.compareTo(b);
    });
    return result;
  }

  // ================= CONNECT =================
  bool _tryConnect(String portName) {
    try {
      final port = SerialPort(portName);

      if (!port.openReadWrite()) {
        return false;
      }

      final config = port.config;
      config.baudRate = 115200;
      config.bits = 8;
      config.stopBits = 1;
      config.parity = SerialPortParity.none;
      port.config = config;

      _port = port;
      _reader = SerialPortReader(port);
      _currentPort = portName;
      _connected = true;
      _decoder.reset();

      AppLogger.info("CONNECTED TO $portName");
      _emitStatus("USB Connected - Waiting telemetry");

      _readerSub = _reader!.stream.listen(
        _onDataReceived,
        onDone: _handleDisconnect,
        onError: (_) => _handleDisconnect(),
        cancelOnError: true,
      );

      return true;
    } catch (e) {
      AppLogger.error("CONNECT FAIL $portName : $e");
      return false;
    }
  }

  // ================= DATA =================
  void _onDataReceived(Uint8List data) {
    try {
      try {
        for (final gps in _decoder.add(data)) {
          AppLogger.info(
            "SERIAL GPS: ${gps.lat},${gps.lng},${gps.roadCategory}",
          );
          _controller.add(gps);
        }
      } catch (e) {
        AppLogger.error("PARSE ERROR: $e");
      }
    } catch (e) {
      AppLogger.error("READ ERROR: $e");
      _handleDisconnect();
    }
  }

  // ================= DISCONNECT =================
  void _handleDisconnect() {
    if (!_connected) return;

    AppLogger.info("DISCONNECTED $_currentPort");
    _emitStatus("ESP32 USB disconnected");

    try {
      _readerSub?.cancel();
    } catch (_) {}

    _readerSub = null;

    try {
      _reader?.close();
    } catch (_) {}

    _reader = null;

    try {
      _port?.close();
    } catch (_) {}

    _port = null;

    _connected = false;
    _currentPort = null;
    _decoder.reset();
  }

  // ================= STATUS =================
  bool get isConnected => _connected;
  String? get currentPort => _currentPort;

  // ================= STOP =================
  void dispose() {
    _disposed = true;

    _scanTimer?.cancel();
    _scanTimer = null;

    _handleDisconnect();

    _controller.close();
    _statusController.close();
  }
}
