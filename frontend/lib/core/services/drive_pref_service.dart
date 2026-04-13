import 'dart:convert';
import 'package:frontend/core/storage/driver_preference.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DriverPrefService {
  /// 🔥 SAVE
  static Future<void> save(DriverPreference pref) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      "driver_${pref.name}",
      jsonEncode(pref.toJson()),
    );
  }

  /// 🔥 LOAD
  static Future<DriverPreference?> load(String name) async {
    final prefs = await SharedPreferences.getInstance();

    final data = prefs.getString("driver_$name");
    if (data == null) return null;

    return DriverPreference.fromJson(jsonDecode(data));
  }

  /// 🔥 OPTIONAL: DELETE
  static Future<void> delete(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove("driver_$name");
    
  }
  
}