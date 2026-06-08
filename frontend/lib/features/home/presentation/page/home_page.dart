import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:frontend/core/model/fragrance_feedback.dart';
import 'package:frontend/core/localization/app_strings.dart';
import 'package:frontend/core/navigation/app_language_control.dart';
import 'package:frontend/core/navigation/drowsiness_control.dart';
import 'package:frontend/core/navigation/driver_session.dart';
import 'package:frontend/core/navigation/smart_music_navigation.dart';
import 'package:frontend/core/provider/music_provider.dart';
import 'package:frontend/core/services/drive_pref_service.dart';
import 'package:frontend/core/services/drowsiness_api.dart';
import 'package:frontend/core/services/fragrance_ai_mqtt_service.dart';
import 'package:frontend/core/services/music_mqtt_service.dart';
import 'package:frontend/services/mqtt_avatar_service.dart';
import 'package:frontend/models/avatar_state.dart';
import 'package:frontend/features/home/presentation/widget/music_page.dart'
    hide getMusicAccentColor;
import 'package:frontend/features/home/presentation/widget/phone_content.dart';
import 'package:frontend/features/home/presentation/widget/settings_content.dart';
import 'package:frontend/widgets/ai_assistant_overlay.dart';
import 'package:frontend/widgets/fragrance_feedback_overlay.dart';
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

enum _HomePopup { none, drowsy, mood }

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final MqttAvatarService _avatarService = MqttAvatarService();
  final MusicMqttService _musicMqttService = MusicMqttService();
  late final FragranceAiMqttService _fragranceAiMqttService;

  bool isReady = false;

  Timer? _drowsyTimer;
  bool _isMonitoring = false;
  bool _dialogShown = false;
  bool _moodSuggestionShown = false;
  _HomePopup _activePopup = _HomePopup.none;
  String? _lastSuggestedMood;
  DateTime? _lastMoodSuggestionAt;
  Timer? _fragranceFeedbackTimer;
  FragranceFeedback? _fragranceFeedback;
  bool _showFragranceFeedback = false;

  @override
  void initState() {
    super.initState();

    DriverSession.currentDriver.addListener(_onDriverChanged);
    DrowsinessControl.enabled.addListener(_onDrowsinessSettingChanged);
    _fragranceAiMqttService = FragranceAiMqttService(
      onFeedback: _showFragranceOverlay,
    );

    _init();
    _avatarService.connect();
    _fragranceAiMqttService.connect();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<VideoProvider>().init(context);
      _musicMqttService.connect(musicProvider: context.read<MusicProvider>());
    });
  }

  @override
  void dispose() {
    DriverSession.currentDriver.removeListener(_onDriverChanged);
    DrowsinessControl.enabled.removeListener(_onDrowsinessSettingChanged);
    _drowsyTimer?.cancel();
    _fragranceFeedbackTimer?.cancel();
    _avatarService.dispose();
    _musicMqttService.dispose();
    _fragranceAiMqttService.dispose();
    super.dispose();
  }

  void _showFragranceOverlay(FragranceFeedback feedback) {
    if (!mounted) return;

    _fragranceFeedbackTimer?.cancel();

    setState(() {
      _fragranceFeedback = feedback;
      _showFragranceFeedback = true;
    });

    _fragranceFeedbackTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() => _showFragranceFeedback = false);
    });
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

      final customTheme = pref.customThemeData;
      if (customTheme != null) {
        CarThemes.customTheme.value = customTheme;
      }

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
    _activePopup = _HomePopup.none;

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
        final eyeClosedElapsed = result["eye_closed_elapsed"];
        final alertReason = result["alert_reason"]?.toString() ?? "-";
        final ear = result["ear"];
        final earRatio = result["ear_ratio"];

        debugPrint(
          "📊 STATUS: $status | mood=$mood | raw=$rawMood | "
          "match=$driverMatch | ear=$ear | ratio=$earRatio | "
          "closed=${eyeClosedElapsed}s | reason=$alertReason",
        );

        if (status == "drowsy") {
          if (!_dialogShown) {
            _dialogShown = true;
            await _showDrowsyWarning();
          }
          return;
        }

        _dialogShown = false;

        if (driverMatch) {
          await _maybeShowMoodSuggestion(mood);
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

    if (!mounted || _activePopup != _HomePopup.none) return;

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
    final accent = getMusicAccentColor(currentTheme, theme);

    _activePopup = _HomePopup.mood;

    try {
      await showGeneralDialog(
        context: context,
        barrierDismissible: true,
        barrierLabel: "Mood Dialog",
        barrierColor: Colors.black.withValues(alpha: 0.58),
        transitionDuration: const Duration(milliseconds: 360),
        pageBuilder: (context, animation, secondaryAnimation) {
          return _PremiumHomeDialog(
            accent: accent,
            haloColor: isHappy
                ? const Color(0xFF7CFFB2)
                : const Color(0xFF88B8FF),
            icon: isHappy
                ? Icons.sentiment_very_satisfied_rounded
                : Icons.nightlight_round,
            title: title,
            subtitle: subtitle,
            tagIcon: Icons.music_note_rounded,
            tagLabel: keyword,
            secondaryText: AppStrings.later,
            primaryText: buttonText,
            tertiaryText: null,
            onSecondary: () => Navigator.of(context).pop(),
            onPrimary: () {
              AppNavigation.currentIndex.value = 0;
              Navigator.of(context).pop();
            },
          );
        },
        transitionBuilder: _premiumDialogTransition,
      );
    } finally {
      if (_activePopup == _HomePopup.mood) {
        _activePopup = _HomePopup.none;
      }
      _moodSuggestionShown = false;
    }
  }

  Future<void> _showDrowsyWarning() async {
    if (!mounted) return;
    if (_activePopup == _HomePopup.drowsy) return;

    if (_activePopup == _HomePopup.mood) {
      Navigator.of(context, rootNavigator: true).pop();
      await Future.delayed(const Duration(milliseconds: 180));
      if (_activePopup == _HomePopup.mood) {
        _activePopup = _HomePopup.none;
      }
    }

    if (!mounted || _activePopup != _HomePopup.none) return;

    final currentTheme = CarThemes.currentTheme.value;
    final theme = CarThemes.getTheme(currentTheme);
    final actionColor = getMusicAccentColor(currentTheme, theme);
    const alertColor = Color(0xFFFF5A5F);

    _activePopup = _HomePopup.drowsy;

    try {
      await showGeneralDialog(
        context: context,
        barrierDismissible: false,
        barrierLabel: "Drowsiness Dialog",
        barrierColor: Colors.black.withValues(alpha: 0.66),
        transitionDuration: const Duration(milliseconds: 320),
        pageBuilder: (context, animation, secondaryAnimation) {
          return _PremiumHomeDialog(
            accent: actionColor,
            haloColor: alertColor,
            icon: Icons.warning_amber_rounded,
            title: AppStrings.drowsyWarning,
            subtitle: AppStrings.smartFragranceQuestion,
            tagIcon: Icons.air_rounded,
            tagLabel: AppStrings.fragrance,
            secondaryText: AppStrings.no,
            primaryText: AppStrings.yes,
            tertiaryText: AppStrings.disableDrowsiness,
            onSecondary: () => Navigator.of(context).pop(),
            onPrimary: () {
              debugPrint("🌸 Fragrance ON");
              Navigator.of(context).pop();
            },
            onTertiary: () {
              DrowsinessControl.enabled.value = false;
              Navigator.of(context).pop();
            },
          );
        },
        transitionBuilder: _premiumDialogTransition,
      );
    } finally {
      if (_activePopup == _HomePopup.drowsy) {
        _activePopup = _HomePopup.none;
      }
    }
  }

  /// ================= UI =================
  @override
  Widget build(BuildContext context) {
    if (!isReady) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: AnimatedBuilder(
        animation: _avatarService,
        builder: (context, _) {
          final avatarVisible = _avatarService.state.isVisible;

          if (avatarVisible) {
            return Stack(
              children: [
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFF061017),
                          Color(0xFF010407),
                        ],
                      ),
                    ),
                  ),
                ),
                AiAssistantOverlay(service: _avatarService),
              ],
            );
          }

          return Stack(
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
                              image: theme.backgroundImage != null
                                  ? DecorationImage(
                                      image: FileImage(
                                        File(theme.backgroundImage!),
                                      ),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
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

              FragranceFeedbackOverlay(
                feedback: _fragranceFeedback,
                visible: _showFragranceFeedback,
              ),

              AiAssistantOverlay(service: _avatarService),
            ],
          );
        },
      ),
    );
  }
}

Widget _premiumDialogTransition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);

  return FadeTransition(
    opacity: curved,
    child: ScaleTransition(
      scale: Tween<double>(begin: 0.94, end: 1).animate(curved),
      child: child,
    ),
  );
}

class _PremiumHomeDialog extends StatelessWidget {
  const _PremiumHomeDialog({
    required this.accent,
    required this.haloColor,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.tagIcon,
    required this.tagLabel,
    required this.secondaryText,
    required this.primaryText,
    required this.onSecondary,
    required this.onPrimary,
    this.tertiaryText,
    this.onTertiary,
  });

  final Color accent;
  final Color haloColor;
  final IconData icon;
  final String title;
  final String subtitle;
  final IconData tagIcon;
  final String tagLabel;
  final String secondaryText;
  final String primaryText;
  final String? tertiaryText;
  final VoidCallback onSecondary;
  final VoidCallback onPrimary;
  final VoidCallback? onTertiary;

  @override
  Widget build(BuildContext context) {
    final primaryTextColor =
        ThemeData.estimateBrightnessForColor(accent) == Brightness.dark
        ? Colors.white
        : const Color(0xFF08111F);

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 560.w,
            constraints: BoxConstraints(maxWidth: 0.74.sw),
            padding: EdgeInsets.all(26.w),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30.r),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xE61B1F28), Color(0xE6101218)],
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.13),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.42),
                  blurRadius: 46,
                  offset: const Offset(0, 24),
                ),
                BoxShadow(
                  color: haloColor.withValues(alpha: 0.22),
                  blurRadius: 56,
                  spreadRadius: -12,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 86.w,
                      height: 86.w,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24.r),
                        color: haloColor.withValues(alpha: 0.14),
                        border: Border.all(
                          color: haloColor.withValues(alpha: 0.28),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: haloColor.withValues(alpha: 0.28),
                            blurRadius: 30,
                            spreadRadius: -6,
                          ),
                        ],
                      ),
                      child: Icon(icon, color: haloColor, size: 44.sp),
                    ),
                    SizedBox(width: 22.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 29.sp,
                              fontWeight: FontWeight.w800,
                              height: 1.08,
                            ),
                          ),
                          SizedBox(height: 12.h),
                          Text(
                            subtitle,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.72),
                              fontSize: 17.sp,
                              fontWeight: FontWeight.w500,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 24.h),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(
                    horizontal: 18.w,
                    vertical: 15.h,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(20.r),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38.w,
                        height: 38.w,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(13.r),
                        ),
                        child: Icon(tagIcon, color: accent, size: 20.sp),
                      ),
                      SizedBox(width: 13.w),
                      Expanded(
                        child: Text(
                          tagLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 26.h),
                Row(
                  children: [
                    Expanded(
                      child: _DialogActionButton(
                        label: secondaryText,
                        foreground: Colors.white.withValues(alpha: 0.82),
                        background: Colors.white.withValues(alpha: 0.08),
                        borderColor: Colors.white.withValues(alpha: 0.10),
                        onTap: onSecondary,
                      ),
                    ),
                    SizedBox(width: 14.w),
                    Expanded(
                      child: _DialogActionButton(
                        label: primaryText,
                        foreground: primaryTextColor,
                        background: accent,
                        borderColor: accent.withValues(alpha: 0.34),
                        shadowColor: accent.withValues(alpha: 0.35),
                        onTap: onPrimary,
                      ),
                    ),
                  ],
                ),
                if (tertiaryText != null && onTertiary != null) ...[
                  SizedBox(height: 14.h),
                  GestureDetector(
                    onTap: onTertiary,
                    child: Container(
                      width: double.infinity,
                      height: 48.h,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18.r),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.10),
                        ),
                      ),
                      child: Text(
                        tertiaryText!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.62),
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DialogActionButton extends StatelessWidget {
  const _DialogActionButton({
    required this.label,
    required this.foreground,
    required this.background,
    required this.borderColor,
    required this.onTap,
    this.shadowColor,
  });

  final String label;
  final Color foreground;
  final Color background;
  final Color borderColor;
  final Color? shadowColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 62.h,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(color: borderColor),
          boxShadow: shadowColor == null
              ? null
              : [
                  BoxShadow(
                    color: shadowColor!,
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: foreground,
            fontSize: 16.sp,
            fontWeight: FontWeight.w800,
            height: 1.1,
          ),
        ),
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
