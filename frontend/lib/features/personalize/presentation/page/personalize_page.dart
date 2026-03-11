import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:frontend/core/themes/car_theme.dart';
import 'package:frontend/core/themes/futuristic_particle_background.dart';
import 'package:frontend/core/themes/playful_background.dart';
import 'package:frontend/core/themes/retro_background.dart';
import 'package:frontend/features/auth/presentation/widget/profile_setting_panel.dart';

class PersonalizePage extends StatelessWidget {
  const PersonalizePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          /// BACKGROUND (LIVE THEME PREVIEW)
          ValueListenableBuilder(
            valueListenable: CarThemes.currentTheme,
            builder: (context, themeType, _) {
              final theme = CarThemes.getTheme(themeType);

              return Stack(
                children: [
                  /// BASE GRADIENT
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: theme.backgroundGradient,
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      image: theme.backgroundImage != null
                          ? DecorationImage(
                              image: FileImage(File(theme.backgroundImage!)),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                  ),

                  /// FUTURISTIC PARTICLES
                  if (themeType == CarThemeType.futuristic)
                    const Positioned.fill(
                      child: FuturisticParticlesBackground(),
                    ),

                  /// RETRO
                  if (themeType == CarThemeType.retro)
                    const Positioned.fill(child: RetroParticlesBackground()),

                  /// PLAYFUL
                  if (themeType == CarThemeType.playful)
                    const Positioned.fill(child: PlayfulParticlesBackground()),
                ],
              );
            },
          ),

          Row(
            children: [
              /// LEFT PANEL
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(40.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      /// BACK BUTTON
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                        },
                        child: Row(
                          children: [
                            Icon(
                              Icons.arrow_back_ios,
                              color: Colors.white,
                              size: 20.sp,
                            ),
                            SizedBox(width: 8.w),
                            Text(
                              "Back",
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 16.sp,
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 15.h),

                      /// TITLE
                      Text(
                        "Profile",
                        style: TextStyle(
                          fontSize: 26.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),

                      ValueListenableBuilder(
                        valueListenable: CarThemes.currentTheme,
                        builder: (context, themeType, _) {
                          final theme = CarThemes.getTheme(themeType);

                          return Divider(
                            color: theme.accentColor,
                            thickness: 2.h,
                            height: 30.h,
                          );
                        },
                      ),

                      /// CENTER CONTENT
                      Expanded(
                        child: Center(
                          child: SizedBox(
                            width: 420.w,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                /// HELLO
                                Text(
                                  "Hello,",
                                  style: TextStyle(
                                    fontSize: 32.sp,
                                    color: Colors.white,
                                  ),
                                ),

                                Text(
                                  "Guest",
                                  style: TextStyle(
                                    fontSize: 70.sp,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),

                                SizedBox(height: 20.h),

                                /// SUBTEXT
                                Row(
                                  children: [
                                    Text(
                                      "Personalized your settings",
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 18.sp,
                                      ),
                                    ),
                                    SizedBox(width: 10.w),
                                    Icon(
                                      Icons.arrow_forward,
                                      color: Colors.white70,
                                      size: 20.sp,
                                    ),
                                  ],
                                ),

                                SizedBox(height: 60.h),

                                /// SAVE BUTTON (LIVE THEME)
                                GestureDetector(
                                  onTap: () {
                                    Navigator.pop(context);
                                  },
                                  child: ValueListenableBuilder(
                                    valueListenable: CarThemes.currentTheme,
                                    builder: (context, themeType, _) {
                                      final theme = CarThemes.getTheme(
                                        themeType,
                                      );

                                      return AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 250,
                                        ),
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 40.w,
                                          vertical: 16.h,
                                        ),
                                        decoration: BoxDecoration(
                                          color: theme.buttonColor,
                                          borderRadius: BorderRadius.circular(
                                            30.r,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: theme.buttonColor
                                                  .withOpacity(0.4),
                                              blurRadius: 20,
                                            ),
                                          ],
                                        ),
                                        child: Text(
                                          "Save Settings",
                                          style: TextStyle(
                                            color:
                                                themeType ==
                                                        CarThemeType.comfort ||
                                                    themeType ==
                                                        CarThemeType.futuristic
                                                ? Colors.black
                                                : Colors.white,
                                            fontSize: 18.sp,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              /// RIGHT PANEL
              const Expanded(child: ProfileSettingsPanel()),
            ],
          ),
        ],
      ),
    );
  }
}
