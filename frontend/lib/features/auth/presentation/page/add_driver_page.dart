import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:frontend/core/themes/car_theme.dart';
import 'package:frontend/core/themes/futuristic_particle_background.dart';
import 'package:frontend/core/themes/playful_background.dart';
import 'package:frontend/core/themes/retro_background.dart';
import 'package:frontend/features/auth/presentation/widget/profile_setting_panel.dart';
import 'package:frontend/features/auth/presentation/widget/scan_face_button.dart';

class AddDriverPage extends StatelessWidget {
  const AddDriverPage({super.key});

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      body: Stack(
        children: [

          /// BACKGROUND THEME
          ValueListenableBuilder(
            valueListenable: CarThemes.currentTheme,
            builder: (context, themeType, _) {

              final theme = CarThemes.themes[themeType]!;

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
                flex: 1,
                child: Padding(
                  padding: EdgeInsets.all(30.w),

                  child: ValueListenableBuilder(
                    valueListenable: CarThemes.currentTheme,
                    builder: (context, themeType, _) {

                      final theme = CarThemes.themes[themeType]!;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [

                          /// TITLE
                          Text(
                            "Profile\nAdd New Driver",
                            style: TextStyle(
                              fontSize: 28.sp,
                              fontWeight: FontWeight.bold,
                              color: theme.textColor,
                            ),
                          ),

                          Divider(
                            color: theme.accentColor,
                            thickness: 2.h,
                            height: 40.h,
                          ),

                          SizedBox(height: 60.h),

                          /// NAME LABEL
                          Text(
                            "Name",
                            style: TextStyle(
                              fontSize: 20.sp,
                              color: theme.textColor,
                            ),
                          ),

                          SizedBox(height: 20.h),

                          /// NAME INPUT
                          Container(
                            height: 60.h,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20.r),

                              border: Border.all(
                                color: theme.accentColor.withOpacity(0.4),
                                width: 2,
                              ),

                              boxShadow: [
                                BoxShadow(
                                  color: theme.accentColor.withOpacity(0.2),
                                  blurRadius: 15,
                                )
                              ],
                            ),
                          ),

                          SizedBox(height: 60.h),

                          /// SCAN FACE BUTTON
                          Center(
                            child: const ScanFaceButton(),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),

              /// RIGHT PANEL (SETTINGS)
              const Expanded(
                flex: 1,
                child: ProfileSettingsPanel(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}