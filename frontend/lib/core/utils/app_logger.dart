import 'package:flutter/foundation.dart';

class AppLogger {
  const AppLogger._();

  static void info(Object? message) {
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
