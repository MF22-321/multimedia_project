import 'dart:async';

import 'package:frontend/core/services/fragrance_control_payload.dart';
import 'package:frontend/core/services/mqtt_service.dart';
import 'package:frontend/core/utils/app_logger.dart';

class SmartFragranceMqttService {
  SmartFragranceMqttService._();

  static final SmartFragranceMqttService instance =
      SmartFragranceMqttService._();

  static const String controlTopic = 'humidifier/control';

  final MQTTService _mqtt = MQTTService();
  Future<bool>? _connectionTask;

  Future<bool> _ensureConnected() {
    if (_mqtt.isConnected) return Future.value(true);

    _connectionTask ??= _mqtt.connect().whenComplete(() {
      _connectionTask = null;
    });

    return _connectionTask!;
  }

  Future<void> selectShortcutCartridge(int cartridge) async {
    final connected = await _ensureConnected();
    if (!connected) {
      AppLogger.error('Smart fragrance MQTT shortcut skipped: not connected');
      return;
    }

    await _mqtt.publish(
      controlTopic,
      FragranceControlPayload.forCartridge(cartridge),
    );
  }
}
