import 'dart:async';
import 'dart:convert';
import 'package:frontend/core/utils/app_logger.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

class MQTTService {
  late MqttServerClient client;
  bool _initialized = false;
  bool _manualDisconnect = false;
  Future<bool>? _connectTask;
  Timer? _reconnectTimer;
  StreamSubscription? _updatesSubscription;

  final String broker = 'broker.hivemq.com';
  final String clientId =
      'flutter_client_${DateTime.now().millisecondsSinceEpoch}';

  final StreamController<Map<String, dynamic>> _controller =
      StreamController.broadcast();
  final StreamController<bool> _connectionController =
      StreamController.broadcast();

  Stream<Map<String, dynamic>> get stream => _controller.stream;
  Stream<bool> get connectionStream => _connectionController.stream;

  bool get isConnected {
    return _initialized &&
        client.connectionStatus?.state == MqttConnectionState.connected;
  }

  Future<bool> connect() async {
    if (isConnected) return true;
    if (_connectTask != null) return _connectTask!;

    _connectTask = _connectInternal().whenComplete(() {
      _connectTask = null;
    });

    return _connectTask!;
  }

  Future<bool> _connectInternal() async {
    _manualDisconnect = false;
    client = MqttServerClient(broker, clientId);
    _initialized = true;
    client.port = 1883;
    client.keepAlivePeriod = 20;
    client.connectTimeoutPeriod = 3000;

    client.onConnected = () {
      AppLogger.info('MQTT connected');
      client.subscribe('humidifier/state', MqttQos.atLeastOnce);
      _connectionController.add(true);
    };

    client.onDisconnected = () {
      AppLogger.info('MQTT disconnected');
      _connectionController.add(false);
      if (!_manualDisconnect) _scheduleReconnect();
    };

    try {
      await client.connect();
    } catch (e) {
      AppLogger.error('MQTT error: $e');
      client.disconnect();
      _scheduleReconnect();
      return false;
    }

    await _updatesSubscription?.cancel();
    _updatesSubscription = client.updates?.listen((events) {
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

    if (!isConnected) {
      _connectionController.add(false);
      _scheduleReconnect();
    }
    return isConnected;
  }

  Future<bool> publish(String topic, Map<String, dynamic> data) async {
    if (!isConnected) {
      final connected = await connect();
      if (!connected) {
        AppLogger.error('MQTT publish skipped: client disconnected');
        return false;
      }
    }

    final builder = MqttClientPayloadBuilder();
    builder.addString(jsonEncode(data));

    try {
      client.publishMessage(
        topic,
        MqttQos.atLeastOnce,
        builder.payload!,
        retain: true,
      );
      return true;
    } catch (e) {
      AppLogger.error('MQTT publish failed: $e');
      _connectionController.add(false);
      _scheduleReconnect();
      return false;
    }
  }

  void disconnect() {
    if (!_initialized) return;
    _manualDisconnect = true;
    _reconnectTimer?.cancel();
    client.disconnect();
  }

  void _scheduleReconnect() {
    if (_manualDisconnect || isConnected || _reconnectTimer?.isActive == true) {
      return;
    }

    _reconnectTimer = Timer(const Duration(seconds: 2), () async {
      if (_manualDisconnect || isConnected) return;
      AppLogger.info('MQTT reconnect attempt');
      await connect();
    });
  }
}
