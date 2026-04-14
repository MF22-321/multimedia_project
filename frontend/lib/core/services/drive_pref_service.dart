import 'dart:convert';
import 'package:frontend/core/storage/driver_preference.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DriverPrefService {
  static String _key(String name) {
    return "driver_${name.trim().toLowerCase()}";
  }

  static Future<void> save(DriverPreference pref) async {
    final prefs = await SharedPreferences.getInstance();

    final key = _key(pref.name);

    await prefs.setString(
      key,
      jsonEncode(pref.toJson()),
    );
  }

  static Future<DriverPreference?> load(String name) async {
    final prefs = await SharedPreferences.getInstance();

    final key = _key(name);

    final data = prefs.getString(key);
    if (data == null) return null;

    try {
      return DriverPreference.fromJson(jsonDecode(data));
    } catch (e) {
      print("❌ JSON error: $e");
      return null;
    }
  }

  static Future<void> delete(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(name));
  }
}