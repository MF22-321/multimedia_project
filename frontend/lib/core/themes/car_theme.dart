import 'package:flutter/material.dart';

enum CarThemeType { comfort, sport, futuristic, retro, playful, custom }

class CarThemeData {
  final List<Color> backgroundGradient;
  final Color accentColor;
  final Color buttonColor;
  final Color textColor;
  final String? backgroundImage;

  const CarThemeData({
    required this.backgroundGradient,
    required this.accentColor,
    required this.buttonColor,
    required this.textColor,
    this.backgroundImage,
  });
}

class CarThemes {
  /// DEFAULT THEMES
  static final Map<CarThemeType, CarThemeData> themes = {
    /// COMFORT
    CarThemeType.comfort: const CarThemeData(
      backgroundGradient: [Color(0xFF737373), Color(0xFFBABABA)],
      accentColor: Colors.white,
      buttonColor: Colors.white,
      textColor: Colors.white,
    ),

    /// SPORT
    CarThemeType.sport: const CarThemeData(
      backgroundGradient: [Color(0xFF1A0000), Color(0xFF3A0000)],
      accentColor: Colors.redAccent,
      buttonColor: Colors.redAccent,
      textColor: Colors.white,
    ),

    /// FUTURISTIC
    CarThemeType.futuristic: const CarThemeData(
      backgroundGradient: [Color(0xFF041C2C), Color(0xFF073B55)],
      accentColor: Color(0xFF00E5FF),
      buttonColor: Color(0xFF00E5FF),
      textColor: Colors.white,
    ),

    /// RETRO
    CarThemeType.retro: const CarThemeData(
      backgroundGradient: [Color(0xFF140028), Color(0xFF2B004F)],
      accentColor: Color(0xFFFF2BC2),
      buttonColor: Color(0xFFFF2BC2),
      textColor: Colors.white,
    ),

    /// PLAYFUL
    CarThemeType.playful: const CarThemeData(
      backgroundGradient: [Color(0xFF8F9F9A), Color(0xFFA8B5B1)],
      accentColor: Color(0xFFC6A883),
      buttonColor: Color(0xFFC6A883),
      textColor: Colors.white,
    ),
  };

  /// CURRENT ACTIVE THEME
  static final ValueNotifier<CarThemeType> currentTheme = ValueNotifier(
    CarThemeType.comfort,
  );

  /// CUSTOM THEME DATA
  static final ValueNotifier<CarThemeData> customTheme = ValueNotifier(
    const CarThemeData(
      backgroundGradient: [Color(0xFF444444), Color(0xFF888888)],
      accentColor: Colors.blue,
      buttonColor: Colors.blue,
      textColor: Colors.white,
    ),
  );

  /// GET ACTIVE THEME SAFELY
  static CarThemeData getTheme(CarThemeType type) {
    if (type == CarThemeType.custom) {
      return customTheme.value;
    }

    return themes[type]!;
  }
}

/// ===============================
/// MUSIC ACCENT COLOR
/// ===============================

Color getMusicAccentColor(CarThemeType type, CarThemeData theme) {
  switch (type) {
    /// COMFORT
    case CarThemeType.comfort:
      return const Color(0xFF6CB4FF);

    /// SPORT
    case CarThemeType.sport:
      return Colors.redAccent;

    /// FUTURISTIC
    case CarThemeType.futuristic:
      return const Color(0xFF00E5FF);

    /// RETRO
    case CarThemeType.retro:
      return const Color(0xFFFF2BC2);

    /// PLAYFUL
    case CarThemeType.playful:
      return const Color(0xFFC6A883);

    /// CUSTOM
    case CarThemeType.custom:
      return theme.buttonColor;
  }
}
