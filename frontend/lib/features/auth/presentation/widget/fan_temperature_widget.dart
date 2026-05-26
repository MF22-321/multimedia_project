import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:frontend/core/localization/app_strings.dart';
import 'package:frontend/core/themes/car_theme.dart';

class FanTemperatureSection extends StatelessWidget {
  final int fanLevel;
  final int temperature;
  final VoidCallback onFanPlus;
  final VoidCallback onFanMinus;
  final VoidCallback onTempPlus;
  final VoidCallback onTempMinus;

  const FanTemperatureSection({
    super.key,
    required this.fanLevel,
    required this.temperature,
    required this.onFanPlus,
    required this.onFanMinus,
    required this.onTempPlus,
    required this.onTempMinus,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: CarThemes.currentTheme,
      builder: (context, themeType, _) {
        final theme = CarThemes.getTheme(themeType);
        final accentColor = themeType == CarThemeType.comfort
            ? const Color(0xFF6CB4FF)
            : theme.accentColor;

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// TITLE
              Text(
                AppStrings.fanTemperatureControl,
                style: TextStyle(
                  fontSize: 20.sp,
                  color: theme.textColor,
                  fontWeight: FontWeight.w600,
                ),
              ),

              SizedBox(height: 20.h),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  /// FAN
                  Row(
                    children: [
                      Image.asset(
                        "assets/images/fan.png",
                        width: 50.w,
                        color: theme.accentColor,
                      ),

                      SizedBox(width: 20.w),

                      /// FAN BARS
                      Row(
                        children: List.generate(5, (index) {
                          final active = index < fanLevel;

                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: EdgeInsets.symmetric(horizontal: 4.w),
                            width: 12.w,
                            height: (20 + (index * 10)).h,

                            decoration: BoxDecoration(
                              color: active
                                  ? accentColor
                                  : Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(5.r),
                            ),
                          );
                        }),
                      ),

                      SizedBox(width: 10.w),

                      /// FAN BUTTONS
                      Column(
                        children: [
                          IconButton(
                            onPressed: onFanPlus,
                            icon: Icon(
                              Icons.add,
                              size: 30.sp,
                              color: accentColor,
                            ),
                          ),
                          IconButton(
                            onPressed: onFanMinus,
                            icon: Icon(
                              Icons.remove,
                              size: 30.sp,
                              color: accentColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  /// TEMPERATURE
                  Row(
                    children: [
                      Image.asset(
                        "assets/images/ac.png",
                        width: 50.w,
                        color: theme.accentColor,
                      ),

                      SizedBox(width: 10.w),

                      /// TEMPERATURE BOX
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),

                        padding: EdgeInsets.symmetric(
                          horizontal: 20.w,
                          vertical: 10.h,
                        ),

                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(15.r),

                          border: Border.all(color: accentColor, width: 2),
                        ),

                        child: Text(
                          "$temperature°",
                          style: TextStyle(
                            fontSize: 22.sp,
                            fontWeight: FontWeight.bold,
                            color: theme.textColor,
                          ),
                        ),
                      ),

                      SizedBox(width: 10.w),

                      /// TEMP BUTTONS
                      Column(
                        children: [
                          IconButton(
                            onPressed: onTempPlus,
                            icon: Icon(
                              Icons.add,
                              size: 30.sp,
                              color: accentColor,
                            ),
                          ),
                          IconButton(
                            onPressed: onTempMinus,
                            icon: Icon(
                              Icons.remove,
                              size: 30.sp,
                              color: accentColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
