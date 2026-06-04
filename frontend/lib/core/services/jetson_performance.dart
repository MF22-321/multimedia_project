import 'dart:io';

class JetsonPerformance {
  const JetsonPerformance._();

  static bool get videoHardwareAcceleration {
    final value = Platform.environment['VIDEO_HW_ACCEL']?.trim().toLowerCase();
    return value == '1' || value == 'true' || value == 'yes';
  }

  static int get tutorialVideoWidth => _readInt('VIDEO_SURFACE_WIDTH', 960);

  static int get tutorialVideoHeight => _readInt('VIDEO_SURFACE_HEIGHT', 540);

  static int get assistantVideoWidth => _readInt('AI_VIDEO_WIDTH', 360);

  static int get assistantVideoHeight => _readInt('AI_VIDEO_HEIGHT', 202);

  static int _readInt(String name, int fallback) {
    final value = int.tryParse(Platform.environment[name] ?? '');
    if (value == null || value <= 0) {
      return fallback;
    }
    return value;
  }
}
