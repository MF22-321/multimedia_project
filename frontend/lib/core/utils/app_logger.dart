import 'package:flutter/foundation.dart';

class AppLogger {
  const AppLogger._();

  static void info(Object? message) {
    if (kDebugMode) {
      debugPrint(message?.toString());
    }
  }

  static void error(Object? message) {
    if (kDebugMode) {
      debugPrint(message?.toString());
    }
  }
}
