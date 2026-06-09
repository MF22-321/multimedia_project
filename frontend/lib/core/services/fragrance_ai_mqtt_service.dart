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
  static const String controlTopic = 'humidifier/control';

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
      client.subscribe(commandTopic, MqttQos.atLeastOnce);
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
      } else if (event.topic == commandTopic) {
        if (message.header?.retain == true) {
          AppLogger.info('Fragrance command retained message ignored');
          continue;
        }
        unawaited(_handleCommand(payload));
      }
    }
  }

  Future<void> _handleCommand(String payload) async {
    try {
      final command = _parseCommand(payload);
      if (command == null) return;

      final control = _controlPayloadForCommand(command);
      if (control == null) {
        AppLogger.info('Fragrance command ignored: $payload');
        return;
      }

      _lastState = Map<String, dynamic>.from(control);
      await _publishControl(control);
    } catch (e) {
      AppLogger.error('Fragrance command failed: $e');
    }
  }

  Map<String, dynamic>? _parseCommand(String payload) {
    try {
      final data = jsonDecode(payload);
      if (data is Map<String, dynamic>) return data;
    } catch (_) {
      final text = payload.trim();
      if (text.isNotEmpty) {
        return {'action': text};
      }
    }

    return null;
  }

  Map<String, dynamic>? _controlPayloadForCommand(Map<String, dynamic> command) {
    final action = (command['action'] ?? command['command'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    final target = (command['target'] ?? command['fragrance'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    final state = _currentControlState();

    if (_matches(action, ['off', 'turn_off', 'matikan', 'mati', 'stop'])) {
      return _offPayload();
    }

    if (_matches(action, ['on', 'turn_on', 'nyalakan', 'hidup', 'start'])) {
      final cartridge = _readCartridge(command, fallback: _selectedOrBoth(state));
      return _cartridgePayload(cartridge, state: state);
    }

    if (_matches(action, ['coffee', 'kopi']) || _matches(target, ['coffee', 'kopi'])) {
      return _cartridgePayload(1, state: state);
    }

    if (_matches(action, ['lavender']) || _matches(target, ['lavender'])) {
      return _cartridgePayload(2, state: state);
    }

    if (_matches(action, ['both', 'all', 'campur', 'keduanya', 'semua']) ||
        _matches(target, ['both', 'all', 'campur', 'keduanya', 'semua'])) {
      return _cartridgePayload(3, state: state);
    }

    if (_matches(action, ['auto', 'automatic', 'otomatis'])) {
      final payload = _cartridgePayload(_selectedOrBoth(state), state: state);
      payload['autoMode'] = true;
      payload['autoInterval'] = command['interval'] ?? state['autoInterval'] ?? '10s';
      return payload;
    }

    if (_matches(action, ['manual'])) {
      final payload = _currentControlState();
      payload['mainPower'] = true;
      payload['autoMode'] = false;
      return payload;
    }

    if (_matches(action, ['speed', 'set_speed', 'kecepatan', 'level'])) {
      final level = _readSpeedLevel(command, fallback: _speedFromText(action));
      if (level == null) return null;
      return _speedPayload(
        level,
        target: target,
        state: state,
      );
    }

    final natural = _naturalLanguagePayload(action, state);
    if (natural != null) return natural;

    return null;
  }

  Map<String, dynamic>? _naturalLanguagePayload(
    String text,
    Map<String, dynamic> state,
  ) {
    if (text.isEmpty) return null;

    if (text.contains('mati') || text.contains('off')) {
      return _offPayload();
    }

    final level = _speedFromText(text);
    final hasSpeed = text.contains('speed') ||
        text.contains('kecepatan') ||
        text.contains('level');

    if (text.contains('kopi') || text.contains('coffee')) {
      final payload = _cartridgePayload(1, state: state);
      return level == null ? payload : _speedPayload(level, target: 'coffee', state: payload);
    }

    if (text.contains('lavender')) {
      final payload = _cartridgePayload(2, state: state);
      return level == null ? payload : _speedPayload(level, target: 'lavender', state: payload);
    }

    if (text.contains('semua') ||
        text.contains('keduanya') ||
        text.contains('both') ||
        text.contains('all')) {
      final payload = _cartridgePayload(3, state: state);
      return level == null ? payload : _speedPayload(level, target: 'all', state: payload);
    }

    if (text.contains('auto') || text.contains('otomatis')) {
      final payload = _cartridgePayload(_selectedOrBoth(state), state: state);
      payload['autoMode'] = true;
      return payload;
    }

    if (text.contains('manual')) {
      final payload = _currentControlState();
      payload['mainPower'] = true;
      payload['autoMode'] = false;
      return payload;
    }

    if (hasSpeed && level != null) {
      return _speedPayload(level, target: 'all', state: state);
    }

    if (text.contains('nyala') || text.contains('hidup') || text.contains('on')) {
      return _cartridgePayload(_selectedOrBoth(state), state: state);
    }

    return null;
  }

  Map<String, dynamic> _currentControlState() {
    final current = _lastState;
    if (current == null) return _offPayload();

    return {
      'selectedCartridge': ((current['selectedCartridge'] as num?)?.toInt() ?? 0)
          .clamp(0, 3)
          .toInt(),
      'mainPower': current['mainPower'] == true,
      'autoMode': current['autoMode'] == true,
      if (current['autoInterval'] != null) 'autoInterval': current['autoInterval'],
      'motor1': _motorState(current, 'motor1'),
      'motor2': _motorState(current, 'motor2'),
    };
  }

  Map<String, dynamic> _motorState(Map<String, dynamic> state, String key) {
    final motor = state[key];
    if (motor is Map) {
      return {
        'enabled': motor['enabled'] == true,
        'speedLevel':
            (((motor['speedLevel'] as num?)?.toInt() ?? 1).clamp(1, 3)).toInt(),
      };
    }

    return {'enabled': false, 'speedLevel': 1};
  }

  Map<String, dynamic> _offPayload() {
    return {
      'selectedCartridge': 0,
      'mainPower': false,
      'autoMode': false,
      'motor1': {'enabled': false, 'speedLevel': 1},
      'motor2': {'enabled': false, 'speedLevel': 1},
    };
  }

  Map<String, dynamic> _cartridgePayload(
    int cartridge, {
    required Map<String, dynamic> state,
  }) {
    final coffeeSpeed = _speedLevel(state, 'motor1', fallback: 3);
    final lavenderSpeed = _speedLevel(state, 'motor2', fallback: 3);

    switch (cartridge.clamp(0, 3).toInt()) {
      case 1:
        return {
          'selectedCartridge': 1,
          'mainPower': true,
          'autoMode': false,
          'motor1': {'enabled': true, 'speedLevel': coffeeSpeed},
          'motor2': {'enabled': false, 'speedLevel': 1},
        };
      case 2:
        return {
          'selectedCartridge': 2,
          'mainPower': true,
          'autoMode': false,
          'motor1': {'enabled': false, 'speedLevel': 1},
          'motor2': {'enabled': true, 'speedLevel': lavenderSpeed},
        };
      case 3:
        return {
          'selectedCartridge': 3,
          'mainPower': true,
          'autoMode': false,
          'motor1': {'enabled': true, 'speedLevel': coffeeSpeed},
          'motor2': {'enabled': true, 'speedLevel': lavenderSpeed},
        };
      default:
        return _offPayload();
    }
  }

  Map<String, dynamic> _speedPayload(
    int level, {
    required String target,
    required Map<String, dynamic> state,
  }) {
    final clamped = level.clamp(1, 3);
    final payload = Map<String, dynamic>.from(state);
    payload['mainPower'] = true;
    payload['autoMode'] = state['autoMode'] == true;
    payload['motor1'] = _motorState(state, 'motor1');
    payload['motor2'] = _motorState(state, 'motor2');

    final normalizedTarget = target.toLowerCase();
    final selected = _selectedOrBoth(state);
    if (normalizedTarget == 'coffee' || normalizedTarget == 'kopi') {
      payload['selectedCartridge'] = 1;
      payload['motor1'] = {'enabled': true, 'speedLevel': clamped};
      payload['motor2'] = {'enabled': false, 'speedLevel': 1};
      return payload;
    }

    if (normalizedTarget == 'lavender') {
      payload['selectedCartridge'] = 2;
      payload['motor1'] = {'enabled': false, 'speedLevel': 1};
      payload['motor2'] = {'enabled': true, 'speedLevel': clamped};
      return payload;
    }

    if (selected == 1) {
      payload['motor1'] = {'enabled': true, 'speedLevel': clamped};
    } else if (selected == 2) {
      payload['motor2'] = {'enabled': true, 'speedLevel': clamped};
    } else {
      payload['selectedCartridge'] = 3;
      payload['motor1'] = {'enabled': true, 'speedLevel': clamped};
      payload['motor2'] = {'enabled': true, 'speedLevel': clamped};
    }

    return payload;
  }

  int _selectedOrBoth(Map<String, dynamic> state) {
    final selected = (state['selectedCartridge'] as num?)?.toInt() ?? 0;
    if (selected >= 1 && selected <= 3) return selected;
    return 3;
  }

  int _speedLevel(
    Map<String, dynamic> state,
    String motor, {
    required int fallback,
  }) {
    return (((state[motor] as Map?)?['speedLevel'] as num?)?.toInt() ??
            fallback)
        .clamp(1, 3)
        .toInt();
  }

  int _readCartridge(Map<String, dynamic> command, {required int fallback}) {
    final raw = command['cartridge'] ?? command['selectedCartridge'];
    if (raw is num) return raw.toInt().clamp(0, 3).toInt();
    final text = raw?.toString().toLowerCase() ?? '';
    if (text.contains('coffee') || text.contains('kopi')) return 1;
    if (text.contains('lavender')) return 2;
    if (text.contains('both') || text.contains('semua')) return 3;
    return fallback;
  }

  int? _readSpeedLevel(Map<String, dynamic> command, {int? fallback}) {
    final raw = command['level'] ?? command['speed'] ?? command['speedLevel'];
    if (raw is num) return raw.toInt().clamp(1, 3).toInt();
    return _speedFromText(raw?.toString() ?? '') ?? fallback;
  }

  int? _speedFromText(String text) {
    final normalized = text.toLowerCase();
    final match = RegExp(r'\b([123])\b').firstMatch(normalized);
    if (match != null) return int.parse(match.group(1)!);
    if (normalized.contains('low') || normalized.contains('pelan')) return 1;
    if (normalized.contains('medium') || normalized.contains('sedang')) return 2;
    if (normalized.contains('high') ||
        normalized.contains('cepat') ||
        normalized.contains('kencang')) {
      return 3;
    }
    return null;
  }

  bool _matches(String value, List<String> options) {
    return options.any((option) => value == option || value.contains(option));
  }

  Future<void> _publishControl(Map<String, dynamic> data) async {
    final client = _client;
    if (client == null || !isConnected) {
      AppLogger.error('Fragrance control publish skipped: MQTT disconnected');
      return;
    }

    final builder = MqttClientPayloadBuilder();
    builder.addString(jsonEncode(data));
    client.publishMessage(
      controlTopic,
      MqttQos.atLeastOnce,
      builder.payload!,
      retain: true,
    );
    AppLogger.info('Fragrance control published: ${jsonEncode(data)}');
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
