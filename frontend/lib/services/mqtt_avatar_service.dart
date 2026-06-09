import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:frontend/models/avatar_state.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

class MqttAvatarService extends ChangeNotifier {
  MqttAvatarService({
    this.broker = 'broker.hivemq.com',
    this.port = 1883,
    String? clientId,
  }) : clientId =
           clientId ?? 'toyota_avatar_${DateTime.now().millisecondsSinceEpoch}';

  static const String stateTopic = 'toyota/avatar/state';
  static const String wordTopic = 'toyota/avatar/word';

  final String broker;
  final int port;
  final String clientId;

  MqttServerClient? _client;
  StreamSubscription<List<MqttReceivedMessage<MqttMessage>>>? _subscription;
  Timer? _reconnectTimer;
  bool _manualDisconnect = false;
  bool _connecting = false;

  AvatarState _state = AvatarState.idle;
  String _subtitle = '';
  bool _connected = false;

  AvatarState get state => _state;
  String get subtitle => _subtitle;
  bool get isConnected => _connected;

  Future<void> connect() async {
    if (_connected || _connecting) return;

    _connecting = true;
    _manualDisconnect = false;

    final client = MqttServerClient(broker, clientId)
      ..port = port
      ..keepAlivePeriod = 20
      ..connectTimeoutPeriod = 3000
      ..logging(on: false)
      ..onConnected = _handleConnected
      ..onDisconnected = _handleDisconnected
      ..pongCallback = () {};

    final message = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .startClean();
    client.connectionMessage = message;
    _client = client;

    try {
      await client.connect();
    } catch (e) {
      debugPrint('MQTT avatar connect error: $e');
      client.disconnect();
      _scheduleReconnect();
    } finally {
      _connecting = false;
    }
  }

  void _handleConnected() {
    final client = _client;
    if (client == null) return;

    debugPrint('MQTT avatar connected');
    _connected = true;
    notifyListeners();

    client.subscribe(stateTopic, MqttQos.atLeastOnce);
    client.subscribe(wordTopic, MqttQos.atLeastOnce);

    _subscription?.cancel();
    _subscription = client.updates?.listen(_handleMessages);
  }

  void _handleDisconnected() {
    _connected = false;
    notifyListeners();

    _subscription?.cancel();
    _subscription = null;

    if (!_manualDisconnect) {
      _scheduleReconnect();
    }
  }

  void _handleMessages(List<MqttReceivedMessage<MqttMessage>> events) {
    for (final event in events) {
      final message = event.payload as MqttPublishMessage;
      final payload = MqttPublishPayload.bytesToStringAsString(
        message.payload.message,
      ).trim();

      if (event.topic == stateTopic) {
        debugPrint('MQTT avatar state payload: $payload');
        _handleStatePayload(payload);
      } else if (event.topic == wordTopic) {
        debugPrint('MQTT avatar word payload: $payload');
        appendWord(payload);
      }
    }
  }

  void _handleStatePayload(String payload) {
    try {
      final data = jsonDecode(payload);
      if (data is! Map<String, dynamic>) return;

      final nextState = AvatarStateX.fromString(data['state']?.toString());
      final resetText = data['resetText'] == true;

      setState(nextState, resetText: resetText);
    } catch (e) {
      debugPrint('MQTT avatar invalid state payload: $payload ($e)');
    }
  }

  void setState(AvatarState nextState, {bool resetText = false}) {
    if (_state == nextState && !resetText) return;

    _state = nextState;
    debugPrint('MQTT avatar state applied: ${nextState.name}');

    if (resetText ||
        nextState == AvatarState.idle ||
        nextState == AvatarState.thinking) {
      _subtitle = '';
    }

    notifyListeners();
  }

  void appendWord(String word) {
    final cleanWord = word.trim();
    if (cleanWord.isEmpty || _state != AvatarState.answering) return;

    _subtitle = _subtitle.isEmpty ? cleanWord : '$_subtitle $cleanWord';
    notifyListeners();
  }

  void _scheduleReconnect() {
    if (_manualDisconnect || _reconnectTimer?.isActive == true) return;

    _reconnectTimer = Timer(const Duration(seconds: 2), () {
      if (!_manualDisconnect) {
        connect();
      }
    });
  }

  @override
  void dispose() {
    _manualDisconnect = true;
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _client?.disconnect();
    super.dispose();
  }
}
