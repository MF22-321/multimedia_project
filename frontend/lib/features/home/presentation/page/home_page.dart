import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
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

  @override
  void initState() {
    super.initState();

    /// 🔥 INIT LAN + OVERLAY SYSTEM
    Future.microtask(() {
      context.read<VideoProvider>().init(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [

          /// =============================
          /// 🎨 BACKGROUND
          /// =============================
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
                        curve: Curves.easeInOut,
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

          /// =============================
          /// 🧩 MAIN UI
          /// =============================
          Row(
            children: [
              const SideMenu(),

              Expanded(
                child: ValueListenableBuilder(
                  valueListenable: AppNavigation.currentIndex,
                  builder: (context, index, _) {
                    switch (index) {
                      case 0:
                        return const Center(
                          child: Text("Music Page",
                              style: TextStyle(color: Colors.white)),
                        );

                      case 1:
                        return const Center(
                          child: Text("Phone Page",
                              style: TextStyle(color: Colors.white)),
                        );

                      case 2:
                        return const _HomeContent();

                      case 3:
                        return const MenuContent();

                      case 4:
                        return const Center(
                          child: Text("Settings Page",
                              style: TextStyle(color: Colors.white)),
                        );

                      default:
                        return const _HomeContent();
                    }
                  },
                ),
              ),
            ],
          ),

          /// ❌ TIDAK ADA VIDEO DI SINI LAGI
          /// (sudah ditangani global overlay service)
        ],
      ),
    );
  }
}

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
                /// LEFT
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

                /// RIGHT
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