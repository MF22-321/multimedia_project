import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:frontend/core/navigation/app_language_control.dart';
import 'package:frontend/core/navigation/drowsiness_control.dart';
import 'package:frontend/core/navigation/driver_session.dart';
import 'package:frontend/core/navigation/pothole_detection_control.dart';
import 'package:frontend/core/provider/pothole_provider.dart';
import 'package:frontend/core/themes/car_theme.dart';
import 'package:provider/provider.dart';

class SettingsContent extends StatefulWidget {
  const SettingsContent({super.key});

  @override
  State<SettingsContent> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsContent> {
  @override
  void initState() {
    super.initState();
    AppLanguageControl.loadForCurrentDriver();
    DriverSession.currentDriver.addListener(_loadLanguagePreference);
    AppLanguageControl.languageCode.addListener(_refreshLanguageText);
  }

  @override
  void dispose() {
    DriverSession.currentDriver.removeListener(_loadLanguagePreference);
    AppLanguageControl.languageCode.removeListener(_refreshLanguageText);
    super.dispose();
  }

  void _loadLanguagePreference() {
    AppLanguageControl.loadForCurrentDriver();
  }

  void _refreshLanguageText() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final currentTheme = CarThemes.currentTheme.value;
    final isEnglish = AppLanguageControl.isEnglish;

    final theme = CarThemes.getTheme(currentTheme);

    final accentColor = currentTheme == CarThemeType.comfort
        ? const Color(0xFF6CB4FF)
        : theme.accentColor;

    return Scaffold(
      backgroundColor: Colors.black,

      body: Container(
        width: double.infinity,
        height: double.infinity,

        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,

            end: Alignment.bottomRight,

            colors: theme.backgroundGradient,
          ),
        ),

        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(24.w),

            child: Row(
              children: [
                /// =========================
                /// CONTENT
                /// =========================
                Expanded(
                  child: Container(
                    padding: EdgeInsets.all(30.w),

                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(40.r),

                      color: Colors.white.withValues(alpha: 0.05),

                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),

                      boxShadow: [
                        BoxShadow(
                          color: accentColor.withValues(alpha: 0.08),

                          blurRadius: 30,

                          spreadRadius: 2,
                        ),
                      ],
                    ),

                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [
                        /// =========================
                        /// HEADER
                        /// =========================
                        Row(
                          children: [
                            Container(
                              width: 64.w,
                              height: 64.w,

                              decoration: BoxDecoration(
                                shape: BoxShape.circle,

                                color: accentColor,

                                boxShadow: [
                                  BoxShadow(
                                    color: accentColor.withValues(alpha: 0.4),

                                    blurRadius: 25,
                                  ),
                                ],
                              ),

                              child: Icon(
                                Icons.settings,

                                color: Colors.white,

                                size: 30.sp,
                              ),
                            ),

                            SizedBox(width: 18.w),

                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,

                              children: [
                                Text(
                                  isEnglish ? 'Settings' : 'Pengaturan',

                                  style: TextStyle(
                                    color: Colors.white,

                                    fontSize: 38.sp,

                                    fontWeight: FontWeight.bold,
                                  ),
                                ),

                                SizedBox(height: 4.h),

                                Text(
                                  isEnglish
                                      ? 'Smart Vehicle Features'
                                      : 'Fitur Kendaraan Pintar',

                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.6),

                                    fontSize: 18.sp,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),

                        SizedBox(height: 40.h),

                        /// =========================
                        /// DROWSINESS
                        /// =========================
                        ValueListenableBuilder(
                          valueListenable: DrowsinessControl.enabled,
                          builder: (context, drowsinessEnabled, _) {
                            return buildFeatureCard(
                              icon: Icons.bedtime_rounded,

                              title: isEnglish
                                  ? 'Drowsiness Alert'
                                  : 'Peringatan Kantuk',

                              description: isEnglish
                                  ? 'Enable automatic drowsiness detection and warning.'
                                  : 'Aktifkan fitur untuk mendeteksi kantuk dan memberi peringatan otomatis.',

                              value: drowsinessEnabled,

                              accentColor: accentColor,

                              onChanged: (value) {
                                DrowsinessControl.enabled.value = value;
                              },
                            );
                          },
                        ),

                        SizedBox(height: 24.h),

                        /// =========================
                        /// POTHOLE
                        /// =========================
                        ValueListenableBuilder(
                          valueListenable: PotholeDetectionControl.enabled,
                          builder: (context, potholeEnabled, _) {
                            return buildFeatureCard(
                              icon: Icons.traffic_rounded,

                              title: isEnglish
                                  ? 'Pothole Detection'
                                  : 'Deteksi Lubang Jalan',

                              description: isEnglish
                                  ? 'Detect potholes in realtime and show hazard notifications.'
                                  : 'Deteksi lubang jalan secara realtime dan tampilkan notifikasi bahaya.',

                              value: potholeEnabled,

                              accentColor: accentColor,

                              onChanged: (value) {
                                PotholeDetectionControl.enabled.value = value;

                                if (value) {
                                  context
                                      .read<PotholeProvider>()
                                      .loadPotholes();
                                }
                              },
                            );
                          },
                        ),

                        SizedBox(height: 24.h),

                        /// =========================
                        /// LANGUAGE
                        /// =========================
                        ValueListenableBuilder(
                          valueListenable: AppLanguageControl.languageCode,
                          builder: (context, languageCode, _) {
                            final isEnglish =
                                languageCode == AppLanguageControl.englishCode;

                            return Container(
                              padding: EdgeInsets.all(24.w),

                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(30.r),

                                color: Colors.white.withValues(alpha: 0.05),

                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.06),
                                ),
                              ),

                              child: Row(
                                children: [
                                  /// ICON
                                  Container(
                                    width: 72.w,
                                    height: 72.w,

                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,

                                      color: accentColor.withValues(alpha: 0.15),
                                    ),

                                    child: Icon(
                                      Icons.language,

                                      color: accentColor,

                                      size: 34.sp,
                                    ),
                                  ),

                                  SizedBox(width: 20.w),

                                  /// TEXT
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,

                                      children: [
                                        Text(
                                          isEnglish ? 'Language' : 'Bahasa',

                                          style: TextStyle(
                                            color: Colors.white,

                                            fontSize: 26.sp,

                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),

                                        SizedBox(height: 6.h),

                                        Text(
                                          isEnglish
                                              ? 'Choose the infotainment system language.'
                                              : 'Pilih bahasa sistem infotainment.',

                                          style: TextStyle(
                                            color: Colors.white.withValues(
                                              alpha: 0.55,
                                            ),

                                            fontSize: 16.sp,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  /// BUTTONS
                                  Container(
                                    padding: EdgeInsets.all(6.w),

                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(20.r),

                                      color: Colors.white.withValues(
                                        alpha: 0.06,
                                      ),
                                    ),

                                    child: Row(
                                      children: [
                                        buildLanguageButton(
                                          title: 'Bahasa',

                                          isSelected: languageCode ==
                                              AppLanguageControl
                                                  .defaultLanguageCode,

                                          accentColor: accentColor,

                                          onTap: () {
                                            AppLanguageControl
                                                .setLanguageForCurrentDriver(
                                              AppLanguageControl
                                                  .defaultLanguageCode,
                                            );
                                          },
                                        ),

                                        SizedBox(width: 10.w),

                                        buildLanguageButton(
                                          title: 'English',

                                          isSelected: languageCode ==
                                              AppLanguageControl.englishCode,

                                          accentColor: accentColor,

                                          onTap: () {
                                            AppLanguageControl
                                                .setLanguageForCurrentDriver(
                                              AppLanguageControl.englishCode,
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// =========================
  /// FEATURE CARD
  /// =========================
  Widget buildFeatureCard({
    required IconData icon,
    required String title,
    required String description,
    required bool value,
    required Color accentColor,
    required Function(bool) onChanged,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),

      padding: EdgeInsets.all(24.w),

      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30.r),

        color: Colors.white.withValues(alpha: 0.05),

        border: Border.all(
          color: value
              ? accentColor.withValues(alpha: 0.25)
              : Colors.white.withValues(alpha: 0.06),
        ),

        boxShadow: [
          if (value)
            BoxShadow(
              color: accentColor.withValues(alpha: 0.18),

              blurRadius: 25,
              spreadRadius: 2,
            ),
        ],
      ),

      child: Row(
        children: [
          /// ICON
          Container(
            width: 72.w,
            height: 72.w,

            decoration: BoxDecoration(
              shape: BoxShape.circle,

              color: accentColor.withValues(alpha: 0.15),
            ),

            child: Icon(icon, color: accentColor, size: 34.sp),
          ),

          SizedBox(width: 20.w),

          /// TEXT
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Text(
                  title,

                  style: TextStyle(
                    color: Colors.white,

                    fontSize: 26.sp,

                    fontWeight: FontWeight.bold,
                  ),
                ),

                SizedBox(height: 8.h),

                Text(
                  description,

                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),

                    fontSize: 16.sp,

                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(width: 20.w),

          /// SWITCH
          Switch(
            value: value,
            activeThumbColor: accentColor,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  /// =========================
  /// LANGUAGE BUTTON
  /// =========================
  Widget buildLanguageButton({
    required String title,
    required bool isSelected,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,

      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),

        padding: EdgeInsets.symmetric(horizontal: 22.w, vertical: 14.h),

        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16.r),

          color: isSelected ? accentColor : Colors.transparent,

          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: accentColor.withValues(alpha: 0.35),
                blurRadius: 18,
              ),
          ],
        ),

        child: Text(
          title,

          style: TextStyle(
            color: Colors.white,

            fontSize: 16.sp,

            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
