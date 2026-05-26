import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:frontend/core/utils/app_logger.dart';

class LanService {
  static final LanService _instance = LanService._internal();
  factory LanService() => _instance;

  LanService._internal();

  Socket? _socket;
  bool _isConnecting = false;
  bool _shouldReconnect = true;

  final _controller = StreamController<String>.broadcast();
  Stream<String> get stream => _controller.stream;

  Future<void> connect() async {
    if (_isConnecting) return;

    _isConnecting = true;

    while (_shouldReconnect) {
      try {
        AppLogger.info("LAN trying to connect...");
        _socket = await Socket.connect(
          '10.0.0.1',
          9000,
          timeout: const Duration(seconds: 3),
        );

        AppLogger.info('LAN connected');
        _isConnecting = false;

        _socket!.listen(
          (data) {
            final message = utf8.decode(data).trim();
            _controller.add(message);
          },
          onError: (e) {
            AppLogger.error('LAN error: $e');
            _reconnect();
          },
          onDone: () {
            AppLogger.info('LAN disconnected');
            _reconnect();
          },
          cancelOnError: true,
        );

        break; // keluar dari loop kalau berhasil connect
      } catch (e) {
        AppLogger.error('LAN connection failed: $e');
        await Future.delayed(const Duration(seconds: 2));
      }
    }
  }

  void _reconnect() {
    if (!_shouldReconnect) return;

    _socket?.destroy();
    _socket = null;

    AppLogger.info("LAN reconnecting in 2s...");
    Future.delayed(const Duration(seconds: 2), () {
      connect();
    });
  }

  void dispose() {
    _shouldReconnect = false;
    _socket?.destroy();
    _controller.close();
  }
}
