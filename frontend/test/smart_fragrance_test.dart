import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/model/auto_interval_option.dart';
import 'package:frontend/core/services/fragrance_control_payload.dart';

void main() {
  test('coffee shortcut powers only motor one', () {
    final payload = FragranceControlPayload.forCartridge(1);

    expect(payload['mainPower'], isTrue);
    expect(payload['selectedCartridge'], 1);
    expect(payload['motor1'], {'enabled': true, 'speedLevel': 3});
    expect(payload['motor2'], {'enabled': false, 'speedLevel': 1});
  });

  test('both shortcut powers both motors', () {
    final payload = FragranceControlPayload.forCartridge(3);
    expect(payload['motor1']['enabled'], isTrue);
    expect(payload['motor2']['enabled'], isTrue);
  });

  test('invalid cartridge produces safe power-off payload', () {
    final payload = FragranceControlPayload.forCartridge(99);
    expect(payload['mainPower'], isFalse);
    expect(payload['selectedCartridge'], 0);
  });

  test('auto interval uses safe default for unknown broker value', () {
    expect(AutoIntervalOptionX.fromFirebase('invalid'), AutoIntervalOption.s10);
    expect(AutoIntervalOption.m5.firebaseValue, '5m');
  });
}
