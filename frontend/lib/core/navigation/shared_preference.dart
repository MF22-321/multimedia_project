import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/core/themes/car_theme.dart';

class DriverProfile {
  /// 🔥 GET THEME
  static Future<CarThemeType> getTheme(String name) async {
    final prefs = await SharedPreferences.getInstance();

    final saved = prefs.getString("theme_$name");

    if (saved != null) {
      return CarThemeType.values.firstWhere(
        (e) => e.name == saved,
        orElse: () => CarThemeType.comfort,
      );
    }

    return CarThemeType.comfort; // default
  }

  /// 🔥 SAVE THEME
  static Future<void> saveTheme(String name, CarThemeType theme) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("theme_$name", theme.name);
  }

  /// 🔥 DELETE DRIVER PROFILE
  static Future<void> deleteDriver(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove("theme_$name");
  }
}