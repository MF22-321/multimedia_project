import 'dart:async';

/// Coordinates the single BlueZ discovery session owned by the Bluetooth UI.
/// Android Auto wireless must stop that scan before switching the adapter into
/// discoverable/peripheral mode.
class BluetoothDiscoveryControl {
  BluetoothDiscoveryControl._();

  static Object? _owner;
  static Future<void> Function()? _stopCallback;

  static void register(Object owner, Future<void> Function() stopCallback) {
    _owner = owner;
    _stopCallback = stopCallback;
  }

  static void unregister(Object owner) {
    if (!identical(_owner, owner)) return;
    _owner = null;
    _stopCallback = null;
  }

  static Future<void> stopActiveDiscovery() async {
    final callback = _stopCallback;
    if (callback != null) await callback();
  }
}
