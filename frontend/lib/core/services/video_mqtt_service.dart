import 'dart:async';

import 'package:frontend/core/utils/app_logger.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

class VideoMqttService {
  static final VideoMqttService _instance = VideoMqttService._internal();
  factory VideoMqttService() => _instance;

  VideoMqttService._internal();

  static const String broker = 'broker.hivemq.com';
  static const int port = 1883;
  static const String videoTopic = 'SOP/video';

  final String _clientId =
      'flutter_video_client_${DateTime.now().millisecondsSinceEpoch}';

  final StreamController<String> _controller =
      StreamController<String>.broadcast();

  MqttServerClient? _client;
  StreamSubscription? _updatesSubscription;
  Timer? _reconnectTimer;
  Future<bool>? _connectTask;
  bool _manualDisconnect = false;

  Stream<String> get stream => _controller.stream;

  bool get isConnected {
    return _client?.connectionStatus?.state == MqttConnectionState.connected;
  }

  Future<bool> connect() {
    if (isConnected) return Future.value(true);
    if (_connectTask != null) return _connectTask!;

    _connectTask = _connectInternal().whenComplete(() {
      _connectTask = null;
    });

    return _connectTask!;
  }

  Future<bool> _connectInternal() async {
    _manualDisconnect = false;

    final client = MqttServerClient(broker, _clientId);
    _client = client;

    client.port = port;
    client.keepAlivePeriod = 20;
    client.connectTimeoutPeriod = 3000;

    client.onConnected = () {
      AppLogger.info('Video MQTT connected');
      client.subscribe(videoTopic, MqttQos.atLeastOnce);
    };

    client.onDisconnected = () {
      AppLogger.info('Video MQTT disconnected');
      if (!_manualDisconnect) _scheduleReconnect();
    };

    try {
      await client.connect();
    } catch (e) {
      AppLogger.error('Video MQTT connect failed: $e');
      client.disconnect();
      _scheduleReconnect();
      return false;
    }

    await _updatesSubscription?.cancel();
    _updatesSubscription = client.updates?.listen((events) {
      if (events.isEmpty) return;

      final message = events.first.payload as MqttPublishMessage;
      final payload = MqttPublishPayload.bytesToStringAsString(
        message.payload.message,
      ).trim();

      if (payload.isEmpty) return;

      AppLogger.info('Video MQTT payload: $payload');
      _controller.add(payload);
    });

    if (!isConnected) _scheduleReconnect();
    return isConnected;
  }

  void _scheduleReconnect() {
    if (_manualDisconnect || isConnected || _reconnectTimer?.isActive == true) {
      return;
    }

    _reconnectTimer = Timer(const Duration(seconds: 2), () {
      if (_manualDisconnect || isConnected) return;
      connect();
    });
  }

  void dispose() {
    _manualDisconnect = true;
    _reconnectTimer?.cancel();
    _updatesSubscription?.cancel();
    _client?.disconnect();
  }
}
