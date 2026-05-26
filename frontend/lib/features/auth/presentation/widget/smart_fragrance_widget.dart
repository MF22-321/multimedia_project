import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:frontend/core/localization/app_strings.dart';
import 'package:frontend/core/navigation/app_routes.dart';
import 'package:frontend/core/themes/car_theme.dart';

class SmartFragranceSection extends StatelessWidget {
  final int selectedCartridge;
  final Function(int) onSelect;
  final CarThemeType? previewThemeType;
  final CarThemeData? previewTheme;

  const SmartFragranceSection({
    super.key,
    required this.selectedCartridge,
    required this.onSelect,
    this.previewThemeType,
    this.previewTheme,
  });

  @override
  Widget build(BuildContext context) {
    if (previewThemeType != null && previewTheme != null) {
      return _buildContent(context, previewThemeType!, previewTheme!);
    }

    return ValueListenableBuilder(
      valueListenable: CarThemes.currentTheme,
      builder: (context, themeType, _) {
        final theme = CarThemes.getTheme(themeType);
        return _buildContent(context, themeType, theme);
      },
    );
  }

  Widget _buildContent(
    BuildContext context,
    CarThemeType themeType,
    CarThemeData theme,
  ) {
    final accentColor = getMusicAccentColor(themeType, theme);
    final buttonColor = themeType == CarThemeType.comfort
        ? accentColor
        : theme.buttonColor;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 30.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: theme.backgroundGradient,
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                AppStrings.smartFragranceControl,
                style: TextStyle(
                  fontSize: 20.sp,
                  color: theme.textColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                AppStrings.selectCartridge,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.sp,
                  color: theme.textColor.withValues(alpha: 0.9),
                ),
              ),
              SizedBox(width: 20.w),
              _cartridgeButton("1", 1, theme, accentColor),
              SizedBox(width: 10.w),
              _cartridgeButton("2", 2, theme, accentColor),
            ],
          ),
          SizedBox(height: 16.h),
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () {
                Navigator.pushNamed(context, AppRoutes.fragranceSettings);
              },
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 30.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: buttonColor,
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Text(
                  AppStrings.customSettings,
                  style: TextStyle(
                    fontSize: 14.sp,
                    color:
                        ThemeData.estimateBrightnessForColor(buttonColor) ==
                            Brightness.dark
                        ? Colors.white
                        : Colors.black,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cartridgeButton(
    String text,
    int value,
    CarThemeData theme,
    Color accentColor,
  ) {
    final bool selected = selectedCartridge == value;

    return GestureDetector(
      onTap: () => onSelect(value),

      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 60.w,
        height: 60.w,

        decoration: BoxDecoration(
          color: selected ? accentColor : Colors.transparent,
          borderRadius: BorderRadius.circular(15.r),

          border: Border.all(color: accentColor, width: 3),

          boxShadow: selected
              ? [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.5),
                    blurRadius: 10,
                  ),
                ]
              : [],
        ),

        child: Center(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
              color: selected ? Colors.white : theme.textColor,
            ),
          ),
        ),
      ),
    );
  }
}
