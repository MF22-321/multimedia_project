import 'package:flutter/material.dart';
import 'package:frontend/core/model/driver_preference.dart';
import 'package:frontend/core/navigation/driver_session.dart';
import 'package:frontend/core/services/drive_pref_service.dart';
import 'package:frontend/core/themes/car_theme.dart';

class AppLanguageControl {
  static const String defaultLanguageCode = 'id';
  static const String englishCode = 'en';
  static const String guestKey = 'guest';

  static final ValueNotifier<String> languageCode = ValueNotifier<String>(
    defaultLanguageCode,
  );

  static String get currentDriverKey {
    final driver = DriverSession.currentDriver.value?.trim();
    if (driver == null || driver.isEmpty) return guestKey;
    return driver;
  }

  static String get selectedLanguageLabel {
    return languageCode.value == englishCode ? 'English' : 'Bahasa';
  }

  static bool get isEnglish => languageCode.value == englishCode;

  static void loadForCurrentDriver() {
    if (currentDriverKey.trim().toLowerCase() == guestKey) {
      languageCode.value = defaultLanguageCode;
      return;
    }

    final pref = DriverHiveService.load(currentDriverKey);
    languageCode.value = _normalize(pref?.languageCode);
  }

  static Future<void> setLanguageForCurrentDriver(String code) async {
    final normalizedCode = _normalize(code);
    final key = currentDriverKey;

    if (key.trim().toLowerCase() == guestKey) {
      languageCode.value = normalizedCode;
      return;
    }

    final existing = DriverHiveService.load(key);

    await DriverHiveService.save(
      DriverPreference(
        name: key.trim().toLowerCase(),
        displayName: existing?.displayName ?? _displayNameFor(key),
        fanLevel: existing?.fanLevel ?? 3,
        temperature: existing?.temperature ?? 19,
        cartridge: existing?.cartridge ?? 2,
        themeIndex: existing?.themeIndex ?? CarThemeType.comfort.index,
        languageCode: normalizedCode,
      ),
    );

    languageCode.value = normalizedCode;
  }

  static String _displayNameFor(String key) {
    if (key.trim().toLowerCase() == guestKey) return 'Guest';
    return key.trim();
  }

  static String _normalize(String? code) {
    return code?.toLowerCase() == englishCode
        ? englishCode
        : defaultLanguageCode;
  }
}
