import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:frontend/core/navigation/car_animation_controller.dart';
import 'package:frontend/core/themes/car_theme.dart';

class CarStatusCard extends StatefulWidget {
  const CarStatusCard({super.key});

  @override
  State<CarStatusCard> createState() => _CarStatusCardState();
}

class _CarStatusCardState extends State<CarStatusCard> {

  int selectedMode = 0;

  Color getMusicAccentColor(
    CarThemeType type,
    CarThemeData theme,
  ) {
    switch (type) {

      case CarThemeType.comfort:
        return const Color(0xFF6CB4FF);

      case CarThemeType.sport:
        return Colors.redAccent;

      case CarThemeType.futuristic:
        return const Color(0xFF00E5FF);

      case CarThemeType.retro:
        return const Color(0xFFFF2BC2);

      case CarThemeType.playful:
        return const Color(0xFFC6A883);

      case CarThemeType.custom:
        return theme.buttonColor;
    }
  }

  @override
  Widget build(BuildContext context) {

    return ValueListenableBuilder(
      valueListenable: CarThemes.currentTheme,

      builder: (context, themeType, _) {

        final theme =
            CarThemes.getTheme(themeType);

        final musicAccent =
            themeType == CarThemeType.comfort
                ? getMusicAccentColor(
                    themeType,
                    theme,
                  )
                : theme.accentColor;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 400),

          height: 295.h,

          decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30.r),

        gradient: LinearGradient(
          colors: [
            theme.backgroundGradient.last.withOpacity(0.8),
            theme.backgroundGradient.last.withOpacity(0.5),
            Colors.black.withOpacity(0.4),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),

        border: Border.all(
          color: theme.accentColor.withOpacity(0.4),
          width: 2,
        ),
      ),

          child: Stack(
            children: [

              /// =========================
              /// CAR IMAGE
              /// =========================
              Padding(
                padding: EdgeInsets.only(
                  bottom: 60.h,
                ),

                child: Center(
                  child: ValueListenableBuilder(
                    valueListenable:
                        CarAnimationController.menuActive,

                    builder: (
                      context,
                      menuActive,
                      _,
                    ) {

                      return AnimatedScale(
                        duration: const Duration(
                          milliseconds: 700,
                        ),

                        curve: Curves.easeOutCubic,

                        scale:
                            menuActive ? 1.2 : 1.0,

                        child: Hero(
                          tag: "carHero",

                          child: Image.asset(
                            "assets/images/veloz.png",

                            width: 450.w,

                            fit: BoxFit.contain,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              /// =========================
              /// DRIVE MODE MENU
              /// =========================
              Positioned(
                bottom: 15.h,
                left: 20.w,
                right: 20.w,

                child: Container(
                  height: 62.h,

                  padding: EdgeInsets.symmetric(
                    horizontal: 10.w,
                  ),

                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(
                      0.08,
                    ),

                    borderRadius:
                        BorderRadius.circular(30.r),

                    border: Border.all(
                      color: Colors.white
                          .withOpacity(0.08),
                    ),

                    boxShadow: [
                      BoxShadow(
                        color: Colors.black
                            .withOpacity(0.25),

                        blurRadius: 20,
                      ),
                    ],
                  ),

                  child: Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceAround,

                    children: [

                      _modeButton(
                        index: 0,
                        icon: Icons.eco,
                        title: "Eco",
                        accent: musicAccent,
                      ),

                      _modeButton(
                        index: 1,
                        icon: Icons.flash_on,
                        title: "Sport",
                        accent: musicAccent,
                      ),

                      _modeButton(
                        index: 2,
                        icon: Icons.directions_car,
                        title: "Drive",
                        accent: musicAccent,
                      ),

                      _modeButton(
                        index: 3,
                        icon: Icons.person,
                        title: "Profile",
                        accent: musicAccent,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _modeButton({
    required int index,
    required IconData icon,
    required String title,
    required Color accent,
  }) {

    final active =
        selectedMode == index;

    return GestureDetector(
      onTap: () {

        setState(() {
          selectedMode = index;
        });
      },

      child: AnimatedContainer(
        duration: const Duration(
          milliseconds: 280,
        ),

        padding: EdgeInsets.symmetric(
          horizontal: 16.w,
          vertical: 8.h,
        ),

        decoration: BoxDecoration(
          borderRadius:
              BorderRadius.circular(18.r),

          color: active
              ? accent.withOpacity(0.18)
              : Colors.transparent,

          border: Border.all(
            color: active
                ? accent.withOpacity(0.45)
                : Colors.transparent,
          ),

          boxShadow: active
              ? [
                  BoxShadow(
                    color:
                        accent.withOpacity(0.35),

                    blurRadius: 16,
                  ),
                ]
              : [],
        ),

        child: Row(
          children: [

            Icon(
              icon,

              color: active
                  ? accent
                  : Colors.white70,

              size: 24.sp,
            ),

            SizedBox(width: 8.w),

            AnimatedDefaultTextStyle(
              duration: const Duration(
                milliseconds: 250,
              ),

              style: TextStyle(
                color: active
                    ? accent
                    : Colors.white70,

                fontSize: 15.sp,

                fontWeight: FontWeight.w700,
              ),

              child: Text(title),
            ),
          ],
        ),
      ),
    );
  }
}