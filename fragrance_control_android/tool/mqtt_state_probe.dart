// ignore_for_file: avoid_print

import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

Future<void> main() async {
  final client = MqttServerClient(
    'broker.hivemq.com',
    'smart_fragrance_probe_${DateTime.now().millisecondsSinceEpoch}',
  )
    ..port = 1883
    ..keepAlivePeriod = 10
    ..connectTimeoutPeriod = 5000;

  try {
    await client.connect();
    if (client.connectionStatus?.state != MqttConnectionState.connected) {
      print('PROBE_ERROR: MQTT connection failed');
      return;
    }

    var receivedCount = 0;
    final subscription = client.updates!.listen((batch) {
      for (final item in batch.where(
        (message) => message.topic == 'humidifier/state',
      )) {
        final message = item.payload as MqttPublishMessage;
        final payload = MqttPublishPayload.bytesToStringAsString(
          message.payload.message,
        );
        receivedCount++;
        print('STATE: $payload');
      }
    });

    client.subscribe('humidifier/state', MqttQos.atLeastOnce);
    await Future<void>.delayed(const Duration(seconds: 12));
    await subscription.cancel();
    if (receivedCount == 0) {
      print('PROBE_TIMEOUT: no humidifier/state received in 12 seconds');
    }
  } catch (error) {
    print('PROBE_ERROR: $error');
  } finally {
    client.disconnect();
  }
}
