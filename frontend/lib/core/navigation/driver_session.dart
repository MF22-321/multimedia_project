import 'package:flutter/material.dart';

class DriverSession {
  static final ValueNotifier<String?> currentDriver =
      ValueNotifier<String?>(null);

  /// SET DRIVER
 static void setDriver(String name) {
  currentDriver.value = name; // 🔥 JANGAN LOWERCASE
  }

  /// CLEAR (GUEST)
  static void clear() {
    currentDriver.value = null;
  }
}