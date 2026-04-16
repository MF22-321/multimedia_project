import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:frontend/core/navigation/driver_session.dart';
import 'package:frontend/core/services/drive_pref_service.dart';
import 'package:frontend/core/services/drowsiness_api.dart';
import 'package:frontend/features/face_recognition/presentation/pages/drowsines_alert_page.dart';
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

  @override
  void initState() {
    super.initState();

    DriverSession.currentDriver.addListener(_onDriverChanged);

    _init();

    Future.microtask(() {
      context.read<VideoProvider>().init(context);
    });
  }

  @override
  void dispose() {
    DriverSession.currentDriver.removeListener(_onDriverChanged);
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
    await _startDrowsiness();
  }

  /// ================= APPLY PREF =================
  Future<void> _applyDriverPreference() async {
    final driver = DriverSession.currentDriver.value;

    debugPrint("🧠 DRIVER SESSION: $driver");

    if (driver == null) {
      CarThemes.currentTheme.value = CarThemeType.comfort;
      return;
    }

    final key = driver.toLowerCase();

    final pref = await DriverHiveService.load(key);

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

    if (driver == null) return;

    try {
      final result = await DrowsinessApi.startDrowsiness(
        driverName: driver.toLowerCase(), // backend pakai lowercase
      );

      _isMonitoring = result["active"] == true;

      debugPrint("🚀 Drowsiness started for $driver");

      _startPolling();
    } catch (e) {
      debugPrint("❌ start drowsiness error: $e");
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

        final status = result["status"]?.toString() ?? "inactive";

        debugPrint("📊 STATUS: $status");

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
                onDisable: () async {
                  await DrowsinessApi.stopDrowsiness();
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
              const SideMenu(),

              Expanded(
                child: ValueListenableBuilder(
                  valueListenable: AppNavigation.currentIndex,
                  builder: (context, index, _) {
                    switch (index) {
                      case 2:
                        return const _HomeContent();
                      case 3:
                        return const MenuContent();
                      default:
                        return const _HomeContent();
                    }
                  },
                ),
              ),
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
