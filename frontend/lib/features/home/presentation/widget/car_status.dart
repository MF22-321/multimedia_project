import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:frontend/core/navigation/car_animation_controller.dart';
import 'package:frontend/core/themes/car_theme.dart';

class CarStatusCard extends StatelessWidget {
  const CarStatusCard({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: CarThemes.currentTheme,
      builder: (context, themeType, _) {
        final theme = CarThemes.getTheme(themeType);

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

              /// CAR IMAGE
              Padding(
                padding: EdgeInsets.only(bottom: 60.h),

                child: Center(
                  child: ValueListenableBuilder(
                    valueListenable: CarAnimationController.menuActive,
                    builder: (context, menuActive, _) {

                      return AnimatedScale(
                        duration: const Duration(milliseconds: 700),
                        curve: Curves.easeOutCubic,
                        scale: menuActive ? 1.2 : 1.0,

                        child: Hero(
                          tag: "carHero",

                          child: Image.asset(
                            "assets/images/yaris_cross.png",
                            width: 450.w,
                            fit: BoxFit.contain,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              /// BOTTOM MENU
              Positioned(
                bottom: 15.h,
                left: 20.w,
                right: 20.w,

                child: Container(
                  height: 40.h,

                  padding: EdgeInsets.symmetric(horizontal: 10.w),

                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(30.r),
                  ),

                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [

                      /// ECO MODE
                      _iconButton(
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 10.w,
                            vertical: 4.h,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(6.r),
                          ),
                          child: const Text(
                            "eco",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),

                      /// PERFORMANCE MODE
                      _iconButton(
                        child: Icon(
                          Icons.flag,
                          size: 26.sp,
                          color: Colors.black,
                        ),
                      ),

                      /// CAR INFO
                      _iconButton(
                        child: Icon(
                          Icons.directions_car,
                          size: 28.sp,
                          color: Colors.black,
                        ),
                      ),

                      /// DRIVER PROFILE
                      Container(
                        width: 50.w,
                        height: 50.w,

                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: theme.accentColor,
                        ),

                        child: Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 28.sp,
                        ),
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

  Widget _iconButton({required Widget child}) {
    return Container(
      width: 45.w,
      height: 45.w,
      alignment: Alignment.center,
      child: child,
    );
  }
}