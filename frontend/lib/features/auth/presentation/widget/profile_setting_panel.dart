import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:frontend/core/localization/app_strings.dart';
import 'package:frontend/core/themes/car_theme.dart';
import 'package:frontend/features/auth/presentation/widget/fan_temperature_widget.dart';
import 'package:frontend/features/auth/presentation/widget/multimedia_theme_section_widget.dart';
import 'package:frontend/features/auth/presentation/widget/smart_fragrance_widget.dart';

class ProfileSettingsPanel extends StatelessWidget {
  final int selectedCartridge;
  final int fanLevel;
  final int temperature;
  final int selectedTheme;
  final CarThemeType? previewThemeType;
  final CarThemeData? previewTheme;
  final CarThemeData? customThemeData;

  final Function(int) onCartridgeChanged;
  final VoidCallback onFanPlus;
  final VoidCallback onFanMinus;
  final VoidCallback onTempPlus;
  final VoidCallback onTempMinus;
  final Function(int) onThemeChanged;
  final ValueChanged<CarThemeData>? onCustomThemeSaved;

  const ProfileSettingsPanel({
    super.key,
    required this.selectedCartridge,
    required this.fanLevel,
    required this.temperature,
    required this.selectedTheme,
    this.previewThemeType,
    this.previewTheme,
    this.customThemeData,
    required this.onCartridgeChanged,
    required this.onFanPlus,
    required this.onFanMinus,
    required this.onTempPlus,
    required this.onTempMinus,
    required this.onThemeChanged,
    this.onCustomThemeSaved,
  });

  @override
  Widget build(BuildContext context) {
    final List<String> themeImages = [
      "assets/themes/theme_comfort.png",
      "assets/themes/theme_sport.png",
      "assets/themes/theme_futuristic.png",
      "assets/themes/theme_retro.png",
      "assets/themes/theme_playful.png",
    ];

    if (previewThemeType != null && previewTheme != null) {
      return _buildPanel(themeImages, previewThemeType!, previewTheme!);
    }

    return ValueListenableBuilder(
      valueListenable: CarThemes.currentTheme,
      builder: (context, themeType, _) {
        final theme = CarThemes.getTheme(themeType);
        return _buildPanel(themeImages, themeType, theme);
      },
    );
  }

  Widget _buildPanel(
    List<String> themeImages,
    CarThemeType themeType,
    CarThemeData theme,
  ) {
    final accentColor = getMusicAccentColor(themeType, theme);

    return Padding(
      padding: const EdgeInsets.only(top: 20).w,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: theme.backgroundGradient,
            begin: Alignment.centerLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.only(topLeft: Radius.circular(40.r)),
          border: Border(
            top: BorderSide(color: accentColor, width: 2.w),
            left: BorderSide(color: accentColor, width: 2.w),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// HEADER
            SizedBox(height: 43.h),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20).w,
              child: Text(
                AppStrings.profileSettings,
                style: TextStyle(
                  fontSize: 26.sp,
                  fontWeight: FontWeight.bold,
                  color: theme.textColor,
                ),
              ),
            ),

            SizedBox(height: 21.h),

            Divider(color: accentColor, thickness: 2.h, height: 2.h),

            /// CONTENT
            Expanded(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    /// SMART FRAGRANCE
                    RepaintBoundary(
                      child: SmartFragranceSection(
                        selectedCartridge: selectedCartridge,
                        onSelect: onCartridgeChanged,
                        previewThemeType: themeType,
                        previewTheme: theme,
                      ),
                    ),

                    Divider(color: accentColor, thickness: 2.h, height: 0.h),

                    /// FAN TEMP
                    RepaintBoundary(
                      child: FanTemperatureSection(
                        fanLevel: fanLevel,
                        temperature: temperature,
                        onFanPlus: onFanPlus,
                        onFanMinus: onFanMinus,
                        onTempPlus: onTempPlus,
                        onTempMinus: onTempMinus,
                        previewThemeType: themeType,
                        previewTheme: theme,
                      ),
                    ),

                    Divider(color: accentColor, thickness: 2.h, height: 0.h),

                    /// THEME
                    RepaintBoundary(
                      child: MultimediaThemeSection(
                        selectedTheme: selectedTheme,
                        themeImages: themeImages,
                        onThemeChanged: onThemeChanged,
                        previewThemeType: themeType,
                        previewTheme: theme,
                        customThemeData: customThemeData,
                        onCustomThemeSaved: onCustomThemeSaved,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
