import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:frontend/core/themes/car_theme.dart';

class MenuContent extends StatelessWidget {
  const MenuContent({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: CarThemes.currentTheme,
      builder: (context, themeType, _) {
        final theme = CarThemes.getTheme(themeType);

        return Padding(
          padding: EdgeInsets.symmetric(horizontal: 80.w, vertical: 60.h),

          child: Row(
            children: [
              /// MENU ICON GRID
              Expanded(
                flex: 2,
                child: Wrap(
                  spacing: 40.w,
                  runSpacing: 40.h,
                  children: [
                    _icon(Icons.music_note, "Music", theme),
                    _icon(Icons.phone, "Phone", theme),
                    _icon(Icons.navigation, "Maps", theme),
                    _icon(Icons.bluetooth, "Bluetooth", theme),
                    _icon(Icons.radio, "Radio", theme),
                    _icon(Icons.usb, "USB", theme),
                    _icon(Icons.info, "Info", theme),
                    _icon(Icons.settings, "Settings", theme),
                  ],
                ),
              ),

              /// CAR HERO TARGET
              Expanded(
                flex: 3,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: TweenAnimationBuilder(
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.easeOutCubic,
                    tween: Tween<double>(begin: 0.7, end: 1.4),
                    builder: (context, scale, child) {
                      return Transform.scale(scale: scale, child: child);
                    },
                    child: Image.asset(
                      "assets/images/yaris_cross.png",
                      width: 560.w,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _icon(IconData icon, String label, CarThemeData theme) {
    return Column(
      children: [
        Container(
          width: 90.w,
          height: 90.w,

          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(25.r),
            color: Colors.white.withOpacity(0.2),

            boxShadow: [
              BoxShadow(
                color: theme.accentColor.withOpacity(0.5),
                blurRadius: 20,
              ),
            ],
          ),

          child: Icon(icon, color: theme.accentColor, size: 36.sp),
        ),

        SizedBox(height: 10.h),

        Text(
          label,
          style: TextStyle(color: theme.textColor, fontSize: 16.sp),
        ),
      ],
    );
  }
}
