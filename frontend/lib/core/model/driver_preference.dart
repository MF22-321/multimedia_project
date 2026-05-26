import 'package:flutter/material.dart';
import 'package:frontend/core/themes/car_theme.dart';

class DriverPreference {
  final String name; // 🔑 internal key (lowercase)
  final String displayName; // 🎨 UI + backend (original)

  final int fanLevel;
  final int temperature;
  final int cartridge;
  final int themeIndex;
  final String languageCode;
  final int? customGradient1;
  final int? customGradient2;
  final int? customAccentColor;
  final int? customTextColor;
  final String? customBackgroundImage;

  DriverPreference({
    required this.name,
    required this.displayName,
    required this.fanLevel,
    required this.temperature,
    required this.cartridge,
    required this.themeIndex,
    this.languageCode = "id",
    this.customGradient1,
    this.customGradient2,
    this.customAccentColor,
    this.customTextColor,
    this.customBackgroundImage,
  });

  Map<String, dynamic> toJson() => {
    "name": name,
    "displayName": displayName,
    "fanLevel": fanLevel,
    "temperature": temperature,
    "cartridge": cartridge,
    "themeIndex": themeIndex,
    "languageCode": languageCode,
    "customGradient1": customGradient1,
    "customGradient2": customGradient2,
    "customAccentColor": customAccentColor,
    "customTextColor": customTextColor,
    "customBackgroundImage": customBackgroundImage,
  };

  factory DriverPreference.fromJson(Map<String, dynamic> json) {
    final rawLanguage = (json["languageCode"] ?? json["language"] ?? "id")
        .toString()
        .toLowerCase();

    return DriverPreference(
      name: json["name"] ?? "",
      displayName: json["displayName"] ?? json["name"] ?? "Guest",
      fanLevel: json["fanLevel"] ?? 3,
      temperature: json["temperature"] ?? 19,
      cartridge: json["cartridge"] ?? 2,
      themeIndex: json["themeIndex"] ?? 0,
      languageCode: rawLanguage == "en" ? "en" : "id",
      customGradient1: _toInt(json["customGradient1"]),
      customGradient2: _toInt(json["customGradient2"]),
      customAccentColor: _toInt(json["customAccentColor"]),
      customTextColor: _toInt(json["customTextColor"]),
      customBackgroundImage: json["customBackgroundImage"]?.toString(),
    );
  }

  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  bool get hasCustomTheme {
    return customGradient1 != null &&
        customGradient2 != null &&
        customAccentColor != null &&
        customTextColor != null;
  }

  CarThemeData? get customThemeData {
    if (!hasCustomTheme) return null;

    return CarThemeData(
      backgroundGradient: [
        Color(customGradient1!),
        Color(customGradient2!),
      ],
      accentColor: Color(customAccentColor!),
      buttonColor: Color(customAccentColor!),
      textColor: Color(customTextColor!),
      backgroundImage: customBackgroundImage,
    );
  }
}
