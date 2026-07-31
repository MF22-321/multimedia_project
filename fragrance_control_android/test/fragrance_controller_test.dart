import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fragrance_control_android/core/mqtt/fragrance_mqtt_gateway.dart';
import 'package:fragrance_control_android/features/fragrance_control/controller/fragrance_controller.dart';

void main() {
  test('publishes toggles immediately and ignores stale ESP32 state', () async {
    final mqtt = _FakeMqttGateway();
    final controller = FragranceController(mqttService: mqtt);
    await controller.initialize();

    controller.toggleCoffee();
    await Future<void>.delayed(Duration.zero);

    expect(mqtt.publishedStates, hasLength(1));
    expect(
      (mqtt.publishedStates.single['motor1'] as Map)['enabled'],
      true,
    );
    expect(controller.state.coffeeEnabled, true);
    expect(controller.syncStatus, FragranceSyncStatus.sending);

    mqtt.emitState({
      'online': true,
      'mainPower': false,
      'autoMode': false,
      'autoInterval': '10s',
      'motor1': {'enabled': false, 'speedLevel': 1},
      'motor2': {'enabled': false, 'speedLevel': 1},
    });
    await Future<void>.delayed(Duration.zero);

    expect(
      controller.state.coffeeEnabled,
      true,
      reason: 'Periodic stale state must not roll back the optimistic toggle.',
    );
    expect(controller.state.hasPendingChanges, true);

    mqtt.emitState({
      'online': true,
      ...mqtt.publishedStates.single,
    });
    await Future<void>.delayed(Duration.zero);

    expect(controller.state.coffeeEnabled, true);
    expect(controller.state.hasPendingChanges, false);
    expect(controller.syncStatus, FragranceSyncStatus.synchronized);

    controller.dispose();
  });
}

class _FakeMqttGateway implements FragranceMqttGateway {
  final _stateController = StreamController<Map<String, dynamic>>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();

  final List<Map<String, dynamic>> publishedStates = [];
  bool _connected = false;

  @override
  Stream<Map<String, dynamic>> get stateStream => _stateController.stream;

  @override
  Stream<bool> get connectionStream => _connectionController.stream;

  @override
  bool get isConnected => _connected;

  @override
  Future<bool> connect() async {
    _connected = true;
    _connectionController.add(true);
    return true;
  }

  @override
  Future<bool> publishState(Map<String, dynamic> state) async {
    publishedStates.add(state);
    return true;
  }

  void emitState(Map<String, dynamic> state) {
    _stateController.add(state);
  }

  @override
  Future<void> dispose() async {
    await _stateController.close();
    await _connectionController.close();
  }
}
