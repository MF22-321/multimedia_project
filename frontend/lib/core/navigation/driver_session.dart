import 'package:flutter/material.dart';

class DriverSession {
  static final ValueNotifier<String?> currentDriver =
      ValueNotifier<String?>(null);

  /// SET DRIVER
  static void setDriver(String name) {
    currentDriver.value = name.trim().toLowerCase();
  }

  /// CLEAR (GUEST)
  static void clear() {
    currentDriver.value = null;
  }
}