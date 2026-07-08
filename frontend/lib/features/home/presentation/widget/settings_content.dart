import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:frontend/core/navigation/app_language_control.dart';
import 'package:frontend/core/navigation/app_routes.dart';
import 'package:frontend/core/navigation/drowsiness_control.dart';
import 'package:frontend/core/navigation/driver_session.dart';
import 'package:frontend/core/navigation/pothole_detection_control.dart';
import 'package:frontend/core/provider/pothole_provider.dart';
import 'package:frontend/core/services/drowsiness_api.dart';
import 'package:frontend/core/themes/car_theme.dart';
import 'package:provider/provider.dart';

class SettingsContent extends StatefulWidget {
  const SettingsContent({super.key});

  @override
  State<SettingsContent> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsContent> {
  double _volume = 70;
  Timer? _volumeDebounce;

  @override
  void initState() {
    super.initState();
    AppLanguageControl.loadForCurrentDriver();
    DriverSession.currentDriver.addListener(_loadLanguagePreference);
    AppLanguageControl.languageCode.addListener(_refreshLanguageText);
    _loadCurrentVolume();
  }

  @override
  void dispose() {
    _volumeDebounce?.cancel();
    DriverSession.currentDriver.removeListener(_loadLanguagePreference);
    AppLanguageControl.languageCode.removeListener(_refreshLanguageText);
    super.dispose();
  }

  Future<void> _loadCurrentVolume() async {
    // Coba PulseAudio dulu (pactl), fallback ke ALSA (amixer)
    try {
      final pa = await Process.run('sh', [
        '-c',
        "pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null | grep -oP '\\d+(?=%)' | head -1",
      ]);
      if (pa.exitCode == 0 && pa.stdout.toString().trim().isNotEmpty) {
        final vol = double.tryParse(pa.stdout.toString().trim());
        if (vol != null && mounted) {
          setState(() => _volume = vol.clamp(0, 100));
          return;
        }
      }
    } catch (_) {}

    try {
      final alsa = await Process.run('sh', [
        '-c',
        "amixer get Master 2>/dev/null | grep -oP '\\d+(?=%)' | head -1",
      ]);
      if (alsa.exitCode == 0 && alsa.stdout.toString().trim().isNotEmpty) {
        final vol = double.tryParse(alsa.stdout.toString().trim());
        if (vol != null && mounted) {
          setState(() => _volume = vol.clamp(0, 100));
        }
      }
    } catch (_) {}
  }

  void _setVolume(double value) {
    setState(() => _volume = value);
    _volumeDebounce?.cancel();
    _volumeDebounce = Timer(const Duration(milliseconds: 150), () {
      final pct = '${value.round()}%';
      Process.run('pactl', ['set-sink-volume', '@DEFAULT_SINK@', pct]);
      Process.run('amixer', ['sset', 'Master', pct]);
    });
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

                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
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
                        /// VOLUME
                        /// =========================
                        buildVolumeCard(
                          accentColor: accentColor,
                          isEnglish: isEnglish,
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

                        SizedBox(height: 24.h),

                        buildActionCard(
                          icon: Icons.switch_account_rounded,
                          title: isEnglish ? 'Switch Driver' : 'Ganti Driver',
                          description: isEnglish
                              ? 'Return to driver selection and restart face recognition.'
                              : 'Kembali ke halaman pilih driver dan aktifkan ulang face recognition.',
                          buttonText: isEnglish ? 'Select Driver' : 'Pilih Driver',
                          accentColor: accentColor,
                          onTap: () {
                            unawaited(DrowsinessApi.stopDrowsiness());
                            DriverSession.clear();
                            Navigator.pushNamedAndRemoveUntil(
                              context,
                              AppRoutes.driverSelect,
                              (_) => false,
                            );
                          },
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

  Widget buildVolumeCard({
    required Color accentColor,
    required bool isEnglish,
  }) {
    return Container(
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30.r),
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.25),
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.08),
            blurRadius: 20,
            spreadRadius: 1,
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
            child: Icon(
              _volume == 0
                  ? Icons.volume_off_rounded
                  : _volume < 50
                  ? Icons.volume_down_rounded
                  : Icons.volume_up_rounded,
              color: accentColor,
              size: 34.sp,
            ),
          ),

          SizedBox(width: 20.w),

          /// TEXT + SLIDER
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isEnglish ? 'System Volume' : 'Volume Sistem',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${_volume.round()}%',
                      style: TextStyle(
                        color: accentColor,
                        fontSize: 22.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 4.h),

                Text(
                  isEnglish
                      ? 'Adjust Jetson audio output level.'
                      : 'Atur level keluaran audio Jetson.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 16.sp,
                  ),
                ),

                SizedBox(height: 10.h),

                SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 5,
                    thumbShape: RoundSliderThumbShape(
                      enabledThumbRadius: 10.r,
                    ),
                    overlayShape: RoundSliderOverlayShape(
                      overlayRadius: 18.r,
                    ),
                    activeTrackColor: accentColor,
                    inactiveTrackColor: Colors.white.withValues(alpha: 0.15),
                    thumbColor: accentColor,
                    overlayColor: accentColor.withValues(alpha: 0.2),
                  ),
                  child: Slider(
                    value: _volume,
                    min: 0,
                    max: 100,
                    onChanged: _setVolume,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildActionCard({
    required IconData icon,
    required String title,
    required String description,
    required String buttonText,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30.r),
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(color: accentColor.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
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
          InkWell(
            borderRadius: BorderRadius.circular(18.r),
            onTap: onTap,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 22.w, vertical: 15.h),
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(18.r),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.28),
                    blurRadius: 18,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.login_rounded, color: Colors.white, size: 20.sp),
                  SizedBox(width: 8.w),
                  Text(
                    buttonText,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
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
