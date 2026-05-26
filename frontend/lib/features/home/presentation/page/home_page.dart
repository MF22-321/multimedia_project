import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:frontend/core/localization/app_strings.dart';
import 'package:frontend/core/navigation/app_language_control.dart';
import 'package:frontend/core/navigation/drowsiness_control.dart';
import 'package:frontend/core/navigation/driver_session.dart';
import 'package:frontend/core/navigation/smart_music_navigation.dart';
import 'package:frontend/core/services/drive_pref_service.dart';
import 'package:frontend/core/services/drowsiness_api.dart';
import 'package:frontend/features/face_recognition/presentation/pages/drowsines_alert_page.dart';
import 'package:frontend/features/home/presentation/widget/music_page.dart';
import 'package:frontend/features/home/presentation/widget/phone_content.dart';
import 'package:frontend/features/home/presentation/widget/settings_content.dart';
import 'package:provider/provider.dart';

import 'package:frontend/core/navigation/app_navigation.dart';
import 'package:frontend/core/themes/car_theme.dart';
import 'package:frontend/core/themes/futuristic_particle_background.dart';
import 'package:frontend/core/themes/playful_background.dart';
import 'package:frontend/core/themes/retro_background.dart';

import 'package:frontend/features/home/presentation/widget/car_status.dart';
import 'package:frontend/features/home/presentation/widget/map_card.dart';
import 'package:frontend/features/home/presentation/widget/media_card.dart';
import 'package:frontend/features/home/presentation/widget/menu_content.dart';
import 'package:frontend/features/home/presentation/widget/quick_action_grid.dart';
import 'package:frontend/features/home/presentation/widget/side_menu.dart';
import 'package:frontend/features/home/presentation/widget/top_bar.dart';

import 'package:frontend/features/video/provider/video_provider.dart';

import '../../../boot/presentation/widget/dotted_background.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool isReady = false;

  Timer? _drowsyTimer;
  bool _isMonitoring = false;
  bool _dialogShown = false;
  bool _moodSuggestionShown = false;
  String? _lastSuggestedMood;
  DateTime? _lastMoodSuggestionAt;

  @override
  void initState() {
    super.initState();

    DriverSession.currentDriver.addListener(_onDriverChanged);
    DrowsinessControl.enabled.addListener(_onDrowsinessSettingChanged);

    _init();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<VideoProvider>().init(context);
    });
  }

  @override
  void dispose() {
    DriverSession.currentDriver.removeListener(_onDriverChanged);
    DrowsinessControl.enabled.removeListener(_onDrowsinessSettingChanged);
    _drowsyTimer?.cancel();
    super.dispose();
  }

  /// ================= INIT =================
  Future<void> _init() async {
    await _applyDriverPreference();
    await _startDrowsiness();

    setState(() {
      isReady = true;
    });
  }

  void _onDriverChanged() async {
    debugPrint("🔄 Driver changed");

    _drowsyTimer?.cancel();

    await _applyDriverPreference(); // 🔥 tunggu selesai
    if (DrowsinessControl.enabled.value) {
      await _startDrowsiness();
    }
  }

  void _onDrowsinessSettingChanged() async {
    if (DrowsinessControl.enabled.value) {
      await _startDrowsiness();
    } else {
      await _stopDrowsiness();
    }
  }

  /// ================= APPLY PREF =================
  Future<void> _applyDriverPreference() async {
    final driver = DriverSession.currentDriver.value;

    debugPrint("🧠 DRIVER SESSION: $driver");
    AppLanguageControl.loadForCurrentDriver();

    if (driver == null) {
      CarThemes.currentTheme.value = CarThemeType.comfort;
      return;
    }

    final key = driver.toLowerCase();

    final pref = DriverHiveService.load(key);

    /// 🔥 CEK LAGI DRIVER (ANTI RACE CONDITION)
    if (DriverSession.currentDriver.value != driver) {
      debugPrint("⛔ Driver berubah saat load → skip apply");
      return;
    }

    if (pref != null) {
      debugPrint("🎨 APPLY THEME INDEX: ${pref.themeIndex}");

      CarThemes.currentTheme.value = CarThemeType.values[pref.themeIndex];
    } else {
      debugPrint("⛔ NO PREF FOUND");
    }
  }

  /// ================= START DROWSINESS =================
  Future<void> _startDrowsiness() async {
    final driver = DriverSession.currentDriver.value;

    if (driver == null || !DrowsinessControl.enabled.value) return;

    try {
      final result = await DrowsinessApi.startDrowsiness(driverName: driver);

      _isMonitoring = result["active"] == true;

      debugPrint("🚀 Drowsiness started for $driver");

      _startPolling();
    } catch (e) {
      debugPrint("❌ start drowsiness error: $e");
    }
  }

  Future<void> _stopDrowsiness() async {
    _drowsyTimer?.cancel();
    _isMonitoring = false;
    _dialogShown = false;
    _moodSuggestionShown = false;

    try {
      await DrowsinessApi.stopDrowsiness();
      debugPrint("🛑 Drowsiness stopped");
    } catch (e) {
      debugPrint("❌ stop drowsiness error: $e");
    }
  }

  /// ================= POLLING =================
  void _startPolling() {
    _drowsyTimer?.cancel();

    _drowsyTimer = Timer.periodic(const Duration(milliseconds: 800), (_) async {
      if (!_isMonitoring) return;

      try {
        final result = await DrowsinessApi.getDrowsinessStatus();

        if (!mounted) return;

        _isMonitoring = result["active"] == true;

        final status = result["status"]?.toString() ?? "inactive";
        final mood = result["mood"]?.toString() ?? "unknown";
        final rawMood = result["raw_mood"]?.toString() ?? "unknown";
        final driverMatch = result["driver_match"] == true;

        debugPrint(
          "📊 STATUS: $status | mood=$mood | raw=$rawMood | match=$driverMatch",
        );

        if (driverMatch) {
          _maybeShowMoodSuggestion(mood);
        }

        if (status == "drowsy" && !_dialogShown) {
          _dialogShown = true;

          await Navigator.push(
            context,
            PageRouteBuilder(
              opaque: false,
              pageBuilder: (_, __, ___) => DrowsinessAlertPage(
                onYes: () {
                  debugPrint("🌸 Fragrance ON");
                  Navigator.pop(context);
                },
                onNo: () {
                  Navigator.pop(context);
                },
                onDisable: () {
                  DrowsinessControl.enabled.value = false;
                  Navigator.pop(context);
                },
              ),
            ),
          );
        }

        if (status != "drowsy") {
          _dialogShown = false;
        }
      } catch (e) {
        debugPrint("❌ polling error: $e");
      }
    });
  }

  Future<void> _maybeShowMoodSuggestion(String mood) async {
    if (_moodSuggestionShown) return;

    if (mood != "happy" && mood != "sad") {
      _lastSuggestedMood = null;
      return;
    }

    final now = DateTime.now();

    final sameMood = _lastSuggestedMood == mood;

    final stillInCooldown =
        _lastMoodSuggestionAt != null &&
        now.difference(_lastMoodSuggestionAt!) < const Duration(minutes: 2);

    if (sameMood && stillInCooldown) {
      return;
    }

    _moodSuggestionShown = true;

    _lastSuggestedMood = mood;

    _lastMoodSuggestionAt = now;

    final isHappy = mood == "happy";

    /// ===============================
    /// AUTO MUSIC KEYWORD
    /// ===============================
    final keyword = isHappy
        ? "happy upbeat driving"
        : "calm relaxing night drive";
    Future.microtask(() {
      SmartMusicSuggestion.suggestedKeyword.value = keyword;
    });

    final title = isHappy
        ? AppStrings.positiveMoodDetected
        : AppStrings.tiredMoodDetected;

    final subtitle = isHappy
        ? AppStrings.happyMoodSubtitle
        : AppStrings.calmMoodSubtitle;

    final buttonText = isHappy
        ? AppStrings.playHappyMusic
        : AppStrings.playCalmMusic;

    final currentTheme = CarThemes.currentTheme.value;

    final theme = CarThemes.getTheme(currentTheme);

    final accent = currentTheme == CarThemeType.comfort
        ? const Color(0xFF6CB4FF)
        : theme.accentColor;

    if (!mounted) return;

    await showGeneralDialog(
      context: context,

      barrierDismissible: true,

      barrierLabel: "Mood Dialog",

      barrierColor: Colors.black.withValues(alpha: 0.45),

      transitionDuration: const Duration(milliseconds: 450),

      pageBuilder: (context, animation, secondaryAnimation) {
        return StatefulBuilder(
          builder: (context, setState) {
            return BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),

              child: Center(
                child: Container(
                  width: 520.w,

                  padding: EdgeInsets.all(30.w),

                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(36.r),

                    gradient: LinearGradient(
                      begin: Alignment.topLeft,

                      end: Alignment.bottomRight,

                      colors: [
                        Colors.white.withValues(alpha: 0.08),

                        Colors.white.withValues(alpha: 0.03),
                      ],
                    ),

                    border: Border.all(color: accent.withValues(alpha: 0.18)),

                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.20),

                        blurRadius: 40,

                        spreadRadius: 1,
                      ),
                    ],
                  ),

                  child: Column(
                    mainAxisSize: MainAxisSize.min,

                    children: [
                      /// ICON
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 400),

                        width: 100.w,
                        height: 100.w,

                        decoration: BoxDecoration(
                          shape: BoxShape.circle,

                          color: accent.withValues(alpha: 0.12),

                          boxShadow: [
                            BoxShadow(
                              color: accent.withValues(alpha: 0.35),

                              blurRadius: 30,
                            ),
                          ],
                        ),

                        child: Icon(
                          isHappy
                              ? Icons.sentiment_very_satisfied
                              : Icons.nightlight_round,

                          color: accent,

                          size: 54.sp,
                        ),
                      ),

                      SizedBox(height: 26.h),

                      /// TITLE
                      Text(
                        title,

                        textAlign: TextAlign.center,

                        style: TextStyle(
                          color: Colors.white,

                          fontSize: 30.sp,

                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      SizedBox(height: 18.h),

                      /// SUBTITLE
                      Text(
                        subtitle,

                        textAlign: TextAlign.center,

                        style: TextStyle(
                          color: Colors.white70,

                          fontSize: 18.sp,

                          height: 1.5,
                        ),
                      ),

                      SizedBox(height: 30.h),

                      /// MUSIC CHIP
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 18.w,
                          vertical: 14.h,
                        ),

                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22.r),

                          color: Colors.white.withValues(alpha: 0.06),
                        ),

                        child: Row(
                          mainAxisSize: MainAxisSize.min,

                          children: [
                            Icon(Icons.music_note, color: accent, size: 22.sp),

                            SizedBox(width: 10.w),

                            Text(
                              keyword,

                              style: TextStyle(
                                color: Colors.white,

                                fontSize: 15.sp,

                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 34.h),

                      /// BUTTONS
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                Navigator.pop(context);
                              },

                              child: Container(
                                height: 66.h,

                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(24.r),

                                  color: Colors.white.withValues(alpha: 0.05),
                                ),

                                child: Center(
                                  child: Text(
                                    AppStrings.later,

                                    style: TextStyle(
                                      color: Colors.white70,

                                      fontSize: 18.sp,

                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          SizedBox(width: 18.w),

                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                /// OPEN MUSIC PAGE
                                AppNavigation.currentIndex.value = 0;

                                Navigator.pop(context);
                              },

                              child: Container(
                                height: 66.h,

                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(24.r),

                                  color: accent,

                                  boxShadow: [
                                    BoxShadow(
                                      color: accent.withValues(alpha: 0.35),

                                      blurRadius: 24,
                                    ),
                                  ],
                                ),

                                child: Center(
                                  child: Text(
                                    buttonText,

                                    textAlign: TextAlign.center,

                                    style: TextStyle(
                                      color: Colors.black,

                                      fontSize: 18.sp,

                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },

      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,

          child: ScaleTransition(
            scale: Tween<double>(begin: 0.88, end: 1).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
            ),

            child: child,
          ),
        );
      },
    );

    _moodSuggestionShown = false;
  }

  /// ================= UI =================
  @override
  Widget build(BuildContext context) {
    if (!isReady) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: Stack(
        children: [
          /// BACKGROUND
          ValueListenableBuilder(
            valueListenable: CarThemes.currentTheme,
            builder: (context, themeType, _) {
              return ValueListenableBuilder(
                valueListenable: CarThemes.customTheme,
                builder: (context, __, ___) {
                  final theme = CarThemes.getTheme(themeType);

                  return Stack(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 600),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: theme.backgroundGradient,
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),

                      if (themeType == CarThemeType.comfort)
                        const Positioned.fill(child: DottedBackground()),

                      if (themeType == CarThemeType.futuristic)
                        const Positioned.fill(
                          child: FuturisticParticlesBackground(),
                        ),

                      if (themeType == CarThemeType.retro)
                        const Positioned.fill(
                          child: RetroParticlesBackground(),
                        ),

                      if (themeType == CarThemeType.playful)
                        const Positioned.fill(
                          child: PlayfulParticlesBackground(),
                        ),
                    ],
                  );
                },
              );
            },
          ),

          /// MAIN UI
          Row(
            children: [
              Expanded(
                child: ValueListenableBuilder(
                  valueListenable: AppNavigation.currentIndex,
                  builder: (context, index, _) {
                    switch (index) {
                      case 0:
                        return const MusicPage();
                      case 1:
                        return const PhoneContent();
                      case 2:
                        return const _HomeContent();
                      case 3:
                        return const MenuContent();
                      case 4:
                        return const SettingsContent();
                      default:
                        return const _HomeContent();
                    }
                  },
                ),
              ),
              const SideMenu(),
            ],
          ),
        ],
      ),
    );
  }
}

/// ================= HOME CONTENT =================
class _HomeContent extends StatelessWidget {
  const _HomeContent();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(30.w),
      child: Column(
        children: [
          const TopBar(),
          SizedBox(height: 30.h),

          Expanded(
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      const MapCard(),
                      SizedBox(height: 25.h),
                      const MediaCard(),
                    ],
                  ),
                ),

                SizedBox(width: 30.w),

                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      const CarStatusCard(),
                      SizedBox(height: 25.h),
                      const QuickActionGrid(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
