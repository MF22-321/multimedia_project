import 'package:hive/hive.dart';
import 'package:frontend/core/utils/app_logger.dart';

import '../model/driver_preference.dart';

class DriverHiveService {
  static final _box = Hive.box('drivers'); // 🔥 SATUIN

  static String _key(String name) {
    return name.trim().toLowerCase();
  }

  /// SAVE
  static Future<void> save(DriverPreference pref) async {
    final key = _key(pref.name);
    await _box.put(key, pref.toJson());

    AppLogger.info("HIVE SAVE: $key");
  }

  /// LOAD
  static DriverPreference? load(String name) {
    final key = _key(name);

    final data = _box.get(key);
    if (data == null) return null;

    return DriverPreference.fromJson(Map<String, dynamic>.from(data));
  }

  /// DELETE (FIXED)
  static Future<void> delete(String name) async {
    final key = _key(name);
    await _box.delete(key);

    AppLogger.info("HIVE DELETE: $key");
  }

  /// DEBUG
  static void printAll() {
    AppLogger.info("=== HIVE DATA ===");
    for (var key in _box.keys) {
      AppLogger.info("$key = ${_box.get(key)}");
    }
  }
}
