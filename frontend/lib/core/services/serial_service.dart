import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'package:frontend/core/model/gps_data.dart';
import 'package:frontend/core/utils/app_logger.dart';

class SerialService {
  SerialPort? _port;
  SerialPortReader? _reader;
  StreamSubscription? _readerSub;
  Timer? _scanTimer;

  final _controller = StreamController<GPSData>.broadcast();
  Stream<GPSData> get stream => _controller.stream;

  String _buffer = "";

  bool _connected = false;
  bool _disposed = false;
  String? _currentPort;
  List<String> _lastPorts = [];

  // ================= START =================
  void start() {
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
      final ports = SerialPort.availablePorts;

      // print hanya jika berubah
      if (ports.toString() != _lastPorts.toString()) {
        AppLogger.info("AVAILABLE PORTS: $ports");
        _lastPorts = List.from(ports);
      }

      if (ports.isEmpty) return;

      for (final portName in ports) {
        if (_tryConnect(portName)) {
          break;
        }
      }
    } catch (e) {
      AppLogger.error("SCAN ERROR: $e");
    }
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
      _buffer = "";

      AppLogger.info("CONNECTED TO $portName");

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
      final incoming = String.fromCharCodes(data);
      _buffer += incoming;

      while (_buffer.contains('\n')) {
        final index = _buffer.indexOf('\n');

        final line = _buffer.substring(0, index).trim();
        _buffer = _buffer.substring(index + 1);

        if (line.isEmpty) continue;

        AppLogger.info("SERIAL: $line");

        if (line.startsWith("GPS")) {
          try {
            final gps = GPSData.fromSerial(line);
            _controller.add(gps);
          } catch (e) {
            AppLogger.error("PARSE ERROR: $e");
          }
        }
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
    _buffer = "";
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
  }
}
