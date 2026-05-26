import 'dart:async';
import 'dart:convert';
import 'package:frontend/core/utils/app_logger.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

class MQTTService {
  late MqttServerClient client;

  final String broker = 'broker.hivemq.com';
  final String clientId =
      'flutter_client_${DateTime.now().millisecondsSinceEpoch}';

  final StreamController<Map<String, dynamic>> _controller =
      StreamController.broadcast();

  Stream<Map<String, dynamic>> get stream => _controller.stream;

  Future<void> connect() async {
    client = MqttServerClient(broker, clientId);
    client.port = 1883;
    client.keepAlivePeriod = 20;

    client.onConnected = () {
      AppLogger.info('MQTT connected');
      client.subscribe('humidifier/state', MqttQos.atLeastOnce);
    };

    client.onDisconnected = () {
      AppLogger.info('MQTT disconnected');
    };

    try {
      await client.connect();
    } catch (e) {
      AppLogger.error('MQTT error: $e');
      client.disconnect();
    }

    client.updates?.listen((events) {
      final rec = events[0].payload as MqttPublishMessage;
      final payload = MqttPublishPayload.bytesToStringAsString(
        rec.payload.message,
      );

      try {
        final data = jsonDecode(payload);
        if (data is Map<String, dynamic>) {
          _controller.add(data);
        }
      } catch (_) {}
    });
  }

  void publish(String topic, Map<String, dynamic> data) {
    final builder = MqttClientPayloadBuilder();
    builder.addString(jsonEncode(data));

    client.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
  }

  void disconnect() {
    client.disconnect();
  }
}
