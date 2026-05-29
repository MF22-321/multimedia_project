import 'dart:async';

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

    await _mqtt.publish(controlTopic, _shortcutPayload(cartridge));
  }

  Map<String, dynamic> _shortcutPayload(int cartridge) {
    switch (cartridge) {
      case 3:
        return {
          'selectedCartridge': 3,
          'mainPower': true,
          'autoMode': false,
          'motor1': {'enabled': true, 'speedLevel': 3},
          'motor2': {'enabled': true, 'speedLevel': 3},
        };
      case 1:
        return {
          'selectedCartridge': 1,
          'mainPower': true,
          'autoMode': false,
          'motor1': {'enabled': true, 'speedLevel': 3},
          'motor2': {'enabled': false, 'speedLevel': 1},
        };
      case 2:
        return {
          'selectedCartridge': 2,
          'mainPower': true,
          'autoMode': false,
          'motor1': {'enabled': false, 'speedLevel': 1},
          'motor2': {'enabled': true, 'speedLevel': 3},
        };
      default:
        return {
          'selectedCartridge': 0,
          'mainPower': false,
          'autoMode': false,
          'motor1': {'enabled': false, 'speedLevel': 1},
          'motor2': {'enabled': false, 'speedLevel': 1},
        };
    }
  }
}
