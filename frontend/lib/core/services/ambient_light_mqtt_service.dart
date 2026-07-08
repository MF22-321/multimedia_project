import 'dart:ui';

import 'package:frontend/core/services/mqtt_service.dart';
import 'package:frontend/core/utils/app_logger.dart';

class AmbientLightMqttService {
  AmbientLightMqttService._();

  static final AmbientLightMqttService instance = AmbientLightMqttService._();

  static const String topic = 'toyota/ambient';

  final MQTTService _mqtt = MQTTService();

  Future<bool> setPower(bool enabled) {
    return _publish({'command': enabled ? 'ON' : 'OFF'});
  }

  Future<bool> setColor(Color color, {int brightness = 200}) {
    final value = color.toARGB32();

    return _publish({
      'command': 'RGB',
      'r': (value >> 16) & 0xff,
      'g': (value >> 8) & 0xff,
      'b': value & 0xff,
      'brightness': brightness.clamp(1, 255),
    });
  }

  Future<bool> setPreset(String command, {int brightness = 200}) {
    return _publish({
      'command': command.toUpperCase(),
      'brightness': brightness.clamp(1, 255),
    });
  }

  Future<bool> _publish(Map<String, dynamic> payload) async {
    final ok = await _mqtt.publish(topic, payload);
    if (!ok) {
      AppLogger.error('Ambient light publish failed: $payload');
    }
    return ok;
  }
}
