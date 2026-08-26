import 'package:flutter/foundation.dart';

class AppLogger {
  const AppLogger._();

  static const bool _verboseInfo = bool.fromEnvironment(
    'HMI_VERBOSE_LOGS',
    defaultValue: false,
  );

  static void info(Object? message) {
    // High-rate ESP32 telemetry is useful during development, but formatting
    // and printing it on every packet steals UI-thread time on the Jetson.
    if (!kDebugMode && !_verboseInfo) return;
    debugPrint(
      '${DateTime.now().toIso8601String()} level=INFO ${message?.toString()}',
    );
  }

  static void error(Object? message) {
    debugPrint(
      '${DateTime.now().toIso8601String()} level=ERROR ${message?.toString()}',
    );
  }
}
