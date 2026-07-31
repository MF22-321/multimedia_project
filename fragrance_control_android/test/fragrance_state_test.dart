import 'package:flutter_test/flutter_test.dart';
import 'package:fragrance_control_android/features/fragrance_control/model/fragrance_state.dart';

void main() {
  test('serializes Android state using the ESP32 contract', () {
    const state = FragranceState(
      mainPower: true,
      autoMode: true,
      coffeeEnabled: true,
      lavenderEnabled: false,
      coffeeSpeed: 3,
      lavenderSpeed: 1,
      autoInterval: AutoInterval.minute1,
    );

    final payload = state.toMqtt();

    expect(payload['selectedCartridge'], 1);
    expect(payload['autoInterval'], '1m');
    expect((payload['motor1'] as Map)['speedLevel'], 3);
    expect((payload['motor2'] as Map)['enabled'], false);
  });

  test('parses retained ESP32 state safely', () {
    final state = FragranceState.fromMqtt({
      'online': true,
      'mainPower': true,
      'autoMode': false,
      'autoInterval': '5m',
      'motor1': {'enabled': false, 'speedLevel': 1},
      'motor2': {'enabled': true, 'speedLevel': 3},
    });

    expect(state.mainPower, true);
    expect(state.lavenderEnabled, true);
    expect(state.lavenderSpeed, 3);
    expect(state.autoInterval, AutoInterval.minutes5);
    expect(state.hasPendingChanges, false);
  });
}
