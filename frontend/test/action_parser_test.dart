import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/utils/action_parser.dart';

void main() {
  test('parses standard SOP play payload', () {
    expect(
      ActionParser.parseMapToVideo({
        'action': 'play',
        'video': 'open_hood',
        'language': 'eng',
      }),
      'assets/video_sdr/BukaKapMobil_eng_sdr.mp4',
    );
  });

  test('parses Raspberry action-as-video payload', () {
    expect(
      ActionParser.parseMapToVideo({'action': 'open hood', 'language': 'jpn'}),
      'assets/video_sdr/BukaKapMobil_jpn_sdr.mp4',
    );
  });

  test('supports every required language-neutral SOP id', () {
    for (final id in [
      'open_trunk',
      'change_tire',
      'check_oil',
      'fire_extinguisher',
      'accident',
    ]) {
      expect(
        ActionParser.parseMapToVideo({'action': id}),
        isNotNull,
        reason: id,
      );
    }
  });

  test('stop is not parsed as a video', () {
    expect(ActionParser.parseMapToVideo({'action': 'stop'}), isNull);
  });
}
