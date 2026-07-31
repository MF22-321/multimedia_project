import 'dart:async';
import 'dart:convert';

import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

import 'fragrance_mqtt_gateway.dart';

class FragranceMqttService implements FragranceMqttGateway {
  static const broker = 'broker.hivemq.com';
  static const port = 1883;
  static const controlTopic = 'humidifier/control';
  static const stateTopic = 'humidifier/state';

  final StreamController<Map<String, dynamic>> _stateController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();

  MqttServerClient? _client;
  StreamSubscription<List<MqttReceivedMessage<MqttMessage>>>?
      _updatesSubscription;
  Timer? _reconnectTimer;
  Future<bool>? _connectTask;
  bool _manualDisconnect = false;
  bool _disposed = false;

  @override
  Stream<Map<String, dynamic>> get stateStream => _stateController.stream;

  @override
  Stream<bool> get connectionStream => _connectionController.stream;

  @override
  bool get isConnected =>
      _client?.connectionStatus?.state == MqttConnectionState.connected;

  @override
  Future<bool> connect() {
    if (isConnected) return Future.value(true);
    if (_connectTask != null) return _connectTask!;

    _connectTask = _connectInternal().whenComplete(() => _connectTask = null);
    return _connectTask!;
  }

  Future<bool> _connectInternal() async {
    if (_disposed) return false;
    _manualDisconnect = false;

    final clientId =
        'android_smart_fragrance_${DateTime.now().millisecondsSinceEpoch}';
    final client = MqttServerClient(broker, clientId)
      ..port = port
      ..keepAlivePeriod = 20
      ..connectTimeoutPeriod = 5000
      ..onConnected = _handleConnected
      ..onDisconnected = _handleDisconnected;

    _client = client;

    try {
      await client.connect();
    } catch (_) {
      client.disconnect();
      _emitConnection(false);
      _scheduleReconnect();
      return false;
    }

    await _updatesSubscription?.cancel();
    _updatesSubscription = client.updates?.listen(_handleMessages);
    client.subscribe(stateTopic, MqttQos.atLeastOnce);

    if (!isConnected) {
      _emitConnection(false);
      _scheduleReconnect();
    }
    return isConnected;
  }

  @override
  Future<bool> publishState(Map<String, dynamic> state) async {
    if (!isConnected && !await connect()) return false;

    final builder = MqttClientPayloadBuilder()..addString(jsonEncode(state));
    final payload = builder.payload;
    if (payload == null) return false;

    try {
      _client!.publishMessage(
        controlTopic,
        MqttQos.atLeastOnce,
        payload,
        retain: true,
      );
      return true;
    } catch (_) {
      _emitConnection(false);
      _scheduleReconnect();
      return false;
    }
  }

  void _handleConnected() {
    _emitConnection(true);
  }

  void _handleDisconnected() {
    _emitConnection(false);
    if (!_manualDisconnect) _scheduleReconnect();
  }

  void _handleMessages(
    List<MqttReceivedMessage<MqttMessage>> messages,
  ) {
    for (final message in messages) {
      if (message.topic != stateTopic) continue;
      final publishMessage = message.payload as MqttPublishMessage;
      final payload = MqttPublishPayload.bytesToStringAsString(
        publishMessage.payload.message,
      );

      try {
        final decoded = jsonDecode(payload);
        if (decoded is Map<String, dynamic> && !_stateController.isClosed) {
          _stateController.add(decoded);
        }
      } on FormatException {
        // Ignore malformed messages from the public broker.
      }
    }
  }

  void _scheduleReconnect() {
    if (_disposed ||
        _manualDisconnect ||
        isConnected ||
        _reconnectTimer?.isActive == true) {
      return;
    }

    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      if (!_disposed && !_manualDisconnect && !isConnected) {
        connect();
      }
    });
  }

  void _emitConnection(bool connected) {
    if (!_connectionController.isClosed) {
      _connectionController.add(connected);
    }
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    _manualDisconnect = true;
    _reconnectTimer?.cancel();
    await _updatesSubscription?.cancel();
    _client?.disconnect();
    await _stateController.close();
    await _connectionController.close();
  }
}
