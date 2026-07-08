import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/model/driver_preference.dart';
import 'package:frontend/core/navigation/driver_session.dart';
import 'package:frontend/core/themes/car_theme.dart';

void main() {
  tearDown(DriverSession.clear);

  test('driver session preserves backend name casing', () {
    DriverSession.setDriver('Febrian Aziz');
    expect(DriverSession.currentDriver.value, 'Febrian Aziz');
  });

  test('driver preference migrates defaults and language safely', () {
    final preference = DriverPreference.fromJson({
      'name': 'febrian',
      'language': 'unsupported',
    });

    expect(preference.displayName, 'febrian');
    expect(preference.fanLevel, 3);
    expect(preference.languageCode, 'id');
  });

  test('custom theme round-trips through preference JSON', () {
    final preference = DriverPreference(
      name: 'febrian',
      displayName: 'Febrian',
      fanLevel: 3,
      temperature: 20,
      cartridge: 2,
      themeIndex: CarThemeType.custom.index,
      customGradient1: Colors.black.toARGB32(),
      customGradient2: Colors.blue.toARGB32(),
      customAccentColor: Colors.red.toARGB32(),
      customTextColor: Colors.white.toARGB32(),
    );

    final restored = DriverPreference.fromJson(preference.toJson());
    expect(restored.hasCustomTheme, isTrue);
    expect(
      restored.customThemeData?.accentColor.toARGB32(),
      Colors.red.toARGB32(),
    );
    expect(CarThemes.getTheme(CarThemeType.comfort), isNotNull);
  });
}
