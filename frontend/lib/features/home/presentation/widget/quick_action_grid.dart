import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
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
    final actions = [
      _ActionItem("M-Toyota", Icons.car_rental),
      _ActionItem("Music", Icons.play_circle_fill),
      _ActionItem("Radio", Icons.radio),
      _ActionItem("Bluetooth", Icons.bluetooth),
      _ActionItem("Car Status", Icons.directions_car),
      _ActionItem("Screen Cast", Icons.cast),
      _ActionItem("USB", Icons.usb),
      _ActionItem("Info", Icons.info),
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
                  if (item.label == "M-Toyota") {
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
                  } else if (item.label == "Music") {
                    AppNavigation.currentIndex.value = 0;
                  } else if (item.label == "Radio") {
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
                  } else if (item.label == "Bluetooth") {
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
                  }else if (item.label == "Screen Cast") {
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
                  }else if (item.label == "Car Status") {
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
                  }else if (item.label == "Info") {
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
                  }else if (item.label == "USB") {
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
                        theme.backgroundGradient.last.withOpacity(0.85),
                        Colors.black.withOpacity(0.35),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),

                    border: Border.all(
                      color: theme.accentColor.withOpacity(0.4),
                      width: 1.5,
                    ),

                    boxShadow: [
                      BoxShadow(
                        color: theme.accentColor.withOpacity(0.25),
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
  }
}

class _ActionItem {
  final String label;
  final IconData icon;

  _ActionItem(this.label, this.icon);
}
