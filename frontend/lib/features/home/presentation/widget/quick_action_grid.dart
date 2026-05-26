import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:frontend/core/localization/app_strings.dart';
import 'package:frontend/core/navigation/app_language_control.dart';
import 'package:frontend/core/navigation/app_navigation.dart';
import 'package:frontend/core/themes/car_theme.dart';
import 'package:frontend/features/home/presentation/widget/bluetooth_content.dart';
import 'package:frontend/features/home/presentation/widget/car_info_content.dart';
import 'package:frontend/features/home/presentation/widget/info_content.dart';
import 'package:frontend/features/home/presentation/widget/radio_content.dart';
import 'package:frontend/features/home/presentation/widget/screen_cast_content.dart';
import 'package:frontend/features/home/presentation/widget/tutorial_content.dart';
import 'package:frontend/features/home/presentation/widget/usb_connect_content.dart';

class QuickActionGrid extends StatelessWidget {
  const QuickActionGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: AppLanguageControl.languageCode,
      builder: (context, _, _) {
        final actions = [
          _ActionItem("tutorial", AppStrings.mToyota, Icons.car_rental),
          _ActionItem("music", AppStrings.music, Icons.play_circle_fill),
          _ActionItem("radio", AppStrings.radio, Icons.radio),
          _ActionItem("bluetooth", AppStrings.bluetooth, Icons.bluetooth),
          _ActionItem("car_status", AppStrings.carStatus, Icons.directions_car),
          _ActionItem("screen_cast", AppStrings.screenCast, Icons.cast),
          _ActionItem("usb", AppStrings.usb, Icons.usb),
          _ActionItem("info", AppStrings.info, Icons.info),
        ];

        return ValueListenableBuilder(
          valueListenable: CarThemes.currentTheme,
          builder: (context, themeType, _) {
            final theme = CarThemes.getTheme(themeType);

            return Expanded(
              child: GridView.builder(
                itemCount: actions.length,

            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 20.h,
              crossAxisSpacing: 20.w,
              childAspectRatio: 1,
            ),

            itemBuilder: (context, index) {
              final item = actions[index];

              return GestureDetector(
                onTap: () {
                  /// OPEN TUTORIAL PAGE
                  if (item.key == "tutorial") {
                    Navigator.push(
                      context,

                      PageRouteBuilder(
                        transitionDuration: const Duration(milliseconds: 450),

                        reverseTransitionDuration: const Duration(
                          milliseconds: 350,
                        ),

                        pageBuilder: (context, animation, secondaryAnimation) {
                          return const TutorialPage();
                        },

                        transitionsBuilder:
                            (context, animation, secondaryAnimation, child) {
                              final curved = CurvedAnimation(
                                parent: animation,

                                curve: Curves.easeInOutCubic,
                              );

                              return FadeTransition(
                                opacity: curved,

                                child: SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(0.08, 0),

                                    end: Offset.zero,
                                  ).animate(curved),

                                  child: child,
                                ),
                              );
                            },
                      ),
                    );
                  } else if (item.key == "music") {
                    AppNavigation.currentIndex.value = 0;
                  } else if (item.key == "radio") {
                    Navigator.push(
                      context,

                      PageRouteBuilder(
                        transitionDuration: const Duration(milliseconds: 450),

                        reverseTransitionDuration: const Duration(
                          milliseconds: 350,
                        ),

                        pageBuilder: (context, animation, secondaryAnimation) {
                          return const RadioContent();
                        },

                        transitionsBuilder:
                            (context, animation, secondaryAnimation, child) {
                              final curved = CurvedAnimation(
                                parent: animation,

                                curve: Curves.easeInOutCubic,
                              );

                              return FadeTransition(
                                opacity: curved,

                                child: SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(0.08, 0),

                                    end: Offset.zero,
                                  ).animate(curved),

                                  child: child,
                                ),
                              );
                            },
                      ),
                    );
                  } else if (item.key == "bluetooth") {
                    Navigator.push(
                      context,

                      PageRouteBuilder(
                        transitionDuration: const Duration(milliseconds: 450),

                        reverseTransitionDuration: const Duration(
                          milliseconds: 350,
                        ),

                        pageBuilder: (context, animation, secondaryAnimation) {
                          return const BluetoothContent();
                        },

                        transitionsBuilder:
                            (context, animation, secondaryAnimation, child) {
                              final curved = CurvedAnimation(
                                parent: animation,

                                curve: Curves.easeInOutCubic,
                              );

                              return FadeTransition(
                                opacity: curved,

                                child: SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(0.08, 0),

                                    end: Offset.zero,
                                  ).animate(curved),

                                  child: child,
                                ),
                              );
                            },
                      ),
                    );
                  } else if (item.key == "screen_cast") {
                    Navigator.push(
                      context,

                      PageRouteBuilder(
                        transitionDuration: const Duration(milliseconds: 450),

                        reverseTransitionDuration: const Duration(
                          milliseconds: 350,
                        ),

                        pageBuilder: (context, animation, secondaryAnimation) {
                          return const ScreenCastContent();
                        },

                        transitionsBuilder:
                            (context, animation, secondaryAnimation, child) {
                              final curved = CurvedAnimation(
                                parent: animation,

                                curve: Curves.easeInOutCubic,
                              );

                              return FadeTransition(
                                opacity: curved,

                                child: SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(0.08, 0),

                                    end: Offset.zero,
                                  ).animate(curved),

                                  child: child,
                                ),
                              );
                            },
                      ),
                    );
                  } else if (item.key == "car_status") {
                    Navigator.push(
                      context,

                      PageRouteBuilder(
                        transitionDuration: const Duration(milliseconds: 450),

                        reverseTransitionDuration: const Duration(
                          milliseconds: 350,
                        ),

                        pageBuilder: (context, animation, secondaryAnimation) {
                          return const CarInfoContent();
                        },

                        transitionsBuilder:
                            (context, animation, secondaryAnimation, child) {
                              final curved = CurvedAnimation(
                                parent: animation,

                                curve: Curves.easeInOutCubic,
                              );

                              return FadeTransition(
                                opacity: curved,

                                child: SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(0.08, 0),

                                    end: Offset.zero,
                                  ).animate(curved),

                                  child: child,
                                ),
                              );
                            },
                      ),
                    );
                  } else if (item.key == "info") {
                    Navigator.push(
                      context,

                      PageRouteBuilder(
                        transitionDuration: const Duration(milliseconds: 450),

                        reverseTransitionDuration: const Duration(
                          milliseconds: 350,
                        ),

                        pageBuilder: (context, animation, secondaryAnimation) {
                          return const InfoContent();
                        },

                        transitionsBuilder:
                            (context, animation, secondaryAnimation, child) {
                              final curved = CurvedAnimation(
                                parent: animation,

                                curve: Curves.easeInOutCubic,
                              );

                              return FadeTransition(
                                opacity: curved,

                                child: SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(0.08, 0),

                                    end: Offset.zero,
                                  ).animate(curved),

                                  child: child,
                                ),
                              );
                            },
                      ),
                    );
                  } else if (item.key == "usb") {
                    Navigator.push(
                      context,

                      PageRouteBuilder(
                        transitionDuration: const Duration(milliseconds: 450),

                        reverseTransitionDuration: const Duration(
                          milliseconds: 350,
                        ),

                        pageBuilder: (context, animation, secondaryAnimation) {
                          return const UsbConnectContent();
                        },

                        transitionsBuilder:
                            (context, animation, secondaryAnimation, child) {
                              final curved = CurvedAnimation(
                                parent: animation,

                                curve: Curves.easeInOutCubic,
                              );

                              return FadeTransition(
                                opacity: curved,

                                child: SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(0.08, 0),

                                    end: Offset.zero,
                                  ).animate(curved),

                                  child: child,
                                ),
                              );
                            },
                      ),
                    );
                  }
                },

                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 400),

                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22.r),

                    gradient: LinearGradient(
                      colors: [
                        theme.backgroundGradient.last.withValues(alpha: 0.85),
                        Colors.black.withValues(alpha: 0.35),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),

                    border: Border.all(
                      color: theme.accentColor.withValues(alpha: 0.4),
                      width: 1.5,
                    ),

                    boxShadow: [
                      BoxShadow(
                        color: theme.accentColor.withValues(alpha: 0.25),
                        blurRadius: 12,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),

                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(item.icon, size: 40.sp, color: theme.accentColor),

                      SizedBox(height: 8.h),

                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: theme.textColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
              ),
            );
          },
        );
      },
    );
  }
}

class _ActionItem {
  final String key;
  final String label;
  final IconData icon;

  _ActionItem(this.key, this.label, this.icon);
}
