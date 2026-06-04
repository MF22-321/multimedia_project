import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:frontend/core/model/fragrance_feedback.dart';
import 'package:frontend/core/utils/app_logger.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

class FragranceAiMqttService {
  FragranceAiMqttService({
    this.onFeedback,
  });

  static const String broker = 'broker.hivemq.com';
  static const int port = 1883;
  static const String commandTopic = 'toyota/fragrance/command';
  static const String stateTopic = 'humidifier/state';

  final void Function(FragranceFeedback feedback)? onFeedback;
  final String _clientId =
      'flutter_fragrance_ai_${DateTime.now().millisecondsSinceEpoch}';

  MqttServerClient? _client;
  StreamSubscription? _updatesSubscription;
  Timer? _reconnectTimer;
  Future<bool>? _connectTask;
  bool _manualDisconnect = false;
  Map<String, dynamic>? _lastState;
  bool _hasSeenInitialState = false;

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
    client.logging(on: false);

    client.onConnected = () {
      AppLogger.info('Fragrance AI MQTT connected');
      client.subscribe(stateTopic, MqttQos.atLeastOnce);
    };

    client.onDisconnected = () {
      AppLogger.info('Fragrance AI MQTT disconnected');
      if (!_manualDisconnect) _scheduleReconnect();
    };

    try {
      await client.connect();
    } catch (e) {
      AppLogger.error('Fragrance AI MQTT connect failed: $e');
      client.disconnect();
      _scheduleReconnect();
      return false;
    }

    await _updatesSubscription?.cancel();
    _updatesSubscription = client.updates?.listen(_handleMessages);

    if (!isConnected) _scheduleReconnect();
    return isConnected;
  }

  void _handleMessages(List<MqttReceivedMessage<MqttMessage>> events) {
    for (final event in events) {
      final message = event.payload as MqttPublishMessage;
      final payload = MqttPublishPayload.bytesToStringAsString(
        message.payload.message,
      ).trim();

      if (payload.isEmpty) continue;

      if (event.topic == stateTopic) {
        _handleState(payload, retained: message.header?.retain == true);
      }
    }
  }

  void _handleState(String payload, {required bool retained}) {
    try {
      final data = jsonDecode(payload);
      if (data is! Map<String, dynamic>) return;

      final normalized = Map<String, dynamic>.from(data);
      final previous = _lastState;
      _lastState = normalized;

      if (retained || !_hasSeenInitialState) {
        _hasSeenInitialState = true;
        return;
      }

      final feedback = _feedbackForState(previous, normalized);
      if (feedback != null) {
        onFeedback?.call(feedback);
      }
    } catch (e) {
      AppLogger.error('Fragrance AI state parse failed: $e');
    }
  }

  FragranceFeedback? _feedbackForState(
    Map<String, dynamic>? previous,
    Map<String, dynamic> current,
  ) {
    final previousCartridge =
        (previous?['selectedCartridge'] as num?)?.toInt() ?? -1;
    final currentCartridge =
        (current['selectedCartridge'] as num?)?.toInt() ?? previousCartridge;
    final previousPower = previous?['mainPower'] == true;
    final currentPower = current['mainPower'] == true;

    final previousCoffee = _motorEnabled(previous, 'motor1');
    final currentCoffee = _motorEnabled(current, 'motor1');
    final previousLavender = _motorEnabled(previous, 'motor2');
    final currentLavender = _motorEnabled(current, 'motor2');
    final autoMode = current['autoMode'] == true;
    final interval = current['autoInterval']?.toString() ?? '10s';

    if (!currentPower && previousPower) {
      return const FragranceFeedback(
        title: 'Fragrance Off',
        message: 'Smart fragrance dimatikan',
        accent: Color(0xFFFF6B7A),
        icon: Icons.air_rounded,
      );
    }

    if (currentCartridge != previousCartridge ||
        currentCoffee != previousCoffee ||
        currentLavender != previousLavender ||
        currentPower != previousPower) {
      if (currentCoffee && currentLavender) {
        return FragranceFeedback(
          title: 'Coffee + Lavender',
          message: autoMode
              ? 'Mode auto aktif setiap $interval'
              : 'Kedua aroma aktif',
          accent: const Color(0xFF7CFFB2),
          icon: Icons.spa_rounded,
        );
      }

      if (currentCoffee) {
        return FragranceFeedback(
          title: 'Coffee Fragrance',
          message: 'Aroma coffee dinyalakan',
          accent: const Color(0xFFFFC46B),
          icon: Icons.local_cafe_rounded,
        );
      }

      if (currentLavender) {
        return FragranceFeedback(
          title: 'Lavender Fragrance',
          message: 'Aroma lavender dinyalakan',
          accent: const Color(0xFFB69CFF),
          icon: Icons.spa_rounded,
        );
      }
    }

    if (autoMode != (previous?['autoMode'] == true)) {
      return FragranceFeedback(
        title: autoMode ? 'Auto Fragrance' : 'Manual Fragrance',
        message: autoMode
            ? 'Mode auto aktif setiap $interval'
            : 'Mode manual aktif',
        accent: const Color(0xFF5CE1FF),
        icon: Icons.autorenew_rounded,
      );
    }

    return null;
  }

  bool _motorEnabled(Map<String, dynamic>? state, String key) {
    final motor = state?[key];
    if (motor is! Map) return false;
    return motor['enabled'] == true;
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
