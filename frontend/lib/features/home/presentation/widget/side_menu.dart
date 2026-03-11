import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:frontend/core/navigation/car_animation_controller.dart';
import 'package:frontend/core/themes/car_theme.dart';
import 'package:frontend/core/navigation/app_navigation.dart';

class SideMenu extends StatelessWidget {
  const SideMenu({super.key});

  Widget buildButton(
    BuildContext context,
    IconData icon,
    String label,
    int index,
    CarThemeData theme,
    CarThemeType themeType,
    int activeIndex,
  ) {
    final bool active = activeIndex == index;

    final Color activeColor = themeType == CarThemeType.comfort
        ? Colors.grey.shade500
        : theme.accentColor;

    return GestureDetector(
      onTap: () {
        AppNavigation.currentIndex.value = index;

        if (index == 3) {
          CarAnimationController.menuActive.value = true;
        } else {
          CarAnimationController.menuActive.value = false;
        }
      },

      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 15.h),

        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),

              width: 70.w,
              height: 70.w,

              decoration: BoxDecoration(
                color: active ? activeColor : Colors.transparent,

                borderRadius: BorderRadius.circular(20.r),

                border: Border.all(
                  color: activeColor.withOpacity(0.5),
                  width: 1.5,
                ),

                boxShadow: active
                    ? [
                        BoxShadow(
                          color: activeColor.withOpacity(0.45),
                          blurRadius: 12,
                        ),
                      ]
                    : [],
              ),

              child: Icon(
                icon,
                color: active ? Colors.white : theme.textColor,
                size: 30.sp,
              ),
            ),

            SizedBox(height: 6.h),

            Text(
              label,
              style: TextStyle(
                color: theme.textColor.withOpacity(0.85),
                fontSize: 14.sp,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: AppNavigation.currentIndex,
      builder: (context, activeIndex, _) {
        return ValueListenableBuilder(
          valueListenable: CarThemes.currentTheme,

          builder: (context, themeType, _) {
            final theme = CarThemes.getTheme(themeType);

            final Color sidebarColor = themeType == CarThemeType.comfort
                ? Colors.black.withOpacity(0.45)
                : Colors.black.withOpacity(0.25);

            return AnimatedContainer(
              duration: const Duration(milliseconds: 400),

              width: 120.w,

              decoration: BoxDecoration(
                color: sidebarColor,

                border: Border(
                  right: BorderSide(
                    color: theme.accentColor.withOpacity(0.4),
                    width: 1.5,
                  ),
                ),
              ),

              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,

                children: [
                  buildButton(
                    context,
                    Icons.music_note,
                    "Music",
                    0,
                    theme,
                    themeType,
                    activeIndex,
                  ),

                  buildButton(
                    context,
                    Icons.phone,
                    "Phone",
                    1,
                    theme,
                    themeType,
                    activeIndex,
                  ),

                  buildButton(
                    context,
                    Icons.home,
                    "Home",
                    2,
                    theme,
                    themeType,
                    activeIndex,
                  ),

                  buildButton(
                    context,
                    Icons.menu,
                    "Menu",
                    3,
                    theme,
                    themeType,
                    activeIndex,
                  ),

                  buildButton(
                    context,
                    Icons.settings,
                    "Settings",
                    4,
                    theme,
                    themeType,
                    activeIndex,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
