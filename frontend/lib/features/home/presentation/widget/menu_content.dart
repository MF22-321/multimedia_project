import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:frontend/core/localization/app_strings.dart';
import 'package:frontend/core/navigation/app_language_control.dart';
import 'package:frontend/core/navigation/app_navigation.dart';
import 'package:frontend/core/navigation/hmi_page_route.dart';
import 'package:frontend/core/themes/car_theme.dart';
import 'package:frontend/features/home/presentation/widget/ambient_light_content.dart';
import 'package:frontend/features/home/presentation/widget/bluetooth_content.dart';
import 'package:frontend/features/home/presentation/widget/car_info_content.dart';
import 'package:frontend/features/home/presentation/widget/info_content.dart';
import 'package:frontend/features/home/presentation/widget/radio_content.dart';
import 'package:frontend/features/home/presentation/widget/tutorial_content.dart';
import 'package:frontend/features/projection/domain/projection_models.dart';
import 'package:frontend/features/projection/presentation/projection_page.dart';
import 'package:frontend/features/smart_fragrance/page/smart_fragrance_page.dart';

class MenuContent extends StatelessWidget {
  const MenuContent({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: AppLanguageControl.languageCode,
      builder: (context, _, _) {
        return ValueListenableBuilder(
          valueListenable: CarThemes.currentTheme,
          builder: (context, themeType, _) {
            final theme = CarThemes.getTheme(themeType);
            final accent = _accentFor(themeType, theme);
            final apps = _buildApps(context);

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(64.w, 42.h, 48.w, 42.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _MenuHeader(theme: theme, accent: accent),
                    SizedBox(height: 34.h),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final crossAxisCount = constraints.maxWidth > 1320.w
                              ? 5
                              : 4;

                          return GridView.builder(
                            physics: const BouncingScrollPhysics(),
                            itemCount: apps.length,
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: crossAxisCount,
                                  mainAxisSpacing: 22.h,
                                  crossAxisSpacing: 22.w,
                                  childAspectRatio: 1.16,
                                ),
                            itemBuilder: (context, index) {
                              final app = apps[index];

                              return _AppTile(
                                app: app,
                                theme: theme,
                                accent: accent,
                                featured: index < 4,
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  List<_LauncherApp> _buildApps(BuildContext context) {
    return [
      _LauncherApp(
        title: AppStrings.music,
        subtitle: AppStrings.moodPlaylist,
        icon: Icons.graphic_eq_rounded,
        onTap: () => AppNavigation.currentIndex.value = 0,
      ),
      _LauncherApp(
        title: AppStrings.phone,
        subtitle: AppStrings.callsContacts,
        icon: Icons.phone_rounded,
        onTap: () => AppNavigation.currentIndex.value = 1,
      ),
      _LauncherApp(
        title: AppStrings.navigation,
        subtitle: AppStrings.mapOverview,
        icon: Icons.explore_rounded,
        onTap: () => AppNavigation.currentIndex.value = 2,
      ),
      _LauncherApp(
        title: AppStrings.settings,
        subtitle: AppStrings.driveControls,
        icon: Icons.tune_rounded,
        onTap: () => AppNavigation.currentIndex.value = 4,
      ),
      _LauncherApp(
        title: AppStrings.radio,
        subtitle: AppStrings.liveStations,
        icon: Icons.radio_rounded,
        onTap: () => _openPage(context, const RadioContent()),
      ),
      _LauncherApp(
        title: AppStrings.bluetooth,
        subtitle: AppStrings.devicePairing,
        icon: Icons.bluetooth_rounded,
        onTap: () => _openPage(context, const BluetoothContent()),
      ),
      _LauncherApp(
        title: AppStrings.androidAuto,
        subtitle: AppStrings.androidAutoSubtitle,
        icon: Icons.android_rounded,
        onTap: () => _openPage(
          context,
          const ProjectionPage(initialTarget: ProjectionTarget.androidAuto),
        ),
      ),
      _LauncherApp(
        title: AppStrings.appleCarPlay,
        subtitle: AppStrings.carPlaySubtitle,
        icon: Icons.apple,
        onTap: () => _openPage(
          context,
          const ProjectionPage(initialTarget: ProjectionTarget.carPlay),
        ),
      ),
      _LauncherApp(
        title: AppStrings.vehicle,
        subtitle: AppStrings.carStatus,
        icon: Icons.directions_car_filled_rounded,
        onTap: () => _openPage(context, const CarInfoContent()),
      ),
      _LauncherApp(
        title: AppStrings.driveInfo,
        subtitle: AppStrings.systemDetails,
        icon: Icons.dashboard_customize_rounded,
        onTap: () => _openPage(context, const InfoContent()),
      ),
      _LauncherApp(
        title: AppStrings.mToyota,
        subtitle: AppStrings.guidedHelp,
        icon: Icons.menu_book_rounded,
        onTap: () => _openPage(context, const TutorialPage()),
      ),
      _LauncherApp(
        title: AppStrings.fragrance,
        subtitle: AppStrings.cabinScent,
        icon: Icons.air_rounded,
        onTap: () => _openPage(context, const SmartFragrancePage()),
      ),
      _LauncherApp(
        title: AppStrings.ambientLight,
        subtitle: AppStrings.cabinLighting,
        icon: Icons.light_mode_rounded,
        onTap: () => _openPage(context, const AmbientLightContent()),
      ),
    ];
  }

  void _openPage(BuildContext context, Widget page) {
    Navigator.push(context, HmiPageRoute(builder: (_) => page));
  }

  Color _accentFor(CarThemeType themeType, CarThemeData theme) {
    if (themeType == CarThemeType.comfort) {
      return const Color(0xFFBFD7FF);
    }

    return theme.accentColor;
  }
}

class _MenuHeader extends StatelessWidget {
  final CarThemeData theme;
  final Color accent;

  const _MenuHeader({required this.theme, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppStrings.applications,
                style: TextStyle(
                  color: theme.textColor,
                  fontSize: 42.sp,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                AppStrings.connectedCockpit,
                style: TextStyle(
                  color: theme.textColor.withValues(alpha: 0.62),
                  fontSize: 17.sp,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
        _StatusPill(
          icon: Icons.shield_rounded,
          label: AppStrings.drive,
          accent: accent,
        ),
        SizedBox(width: 12.w),
        _StatusPill(
          icon: Icons.wifi_rounded,
          label: AppStrings.online,
          accent: accent,
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color accent;

  const _StatusPill({
    required this.icon,
    required this.label,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44.h,
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22.r),
        color: Colors.black.withValues(alpha: 0.18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: accent, size: 18.sp),
          SizedBox(width: 8.w),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.88),
              fontSize: 13.sp,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _AppTile extends StatelessWidget {
  final _LauncherApp app;
  final CarThemeData theme;
  final Color accent;
  final bool featured;

  const _AppTile({
    required this.app,
    required this.theme,
    required this.accent,
    required this.featured,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(28.r),
        onTap: app.onTap,
        child: Ink(
          padding: EdgeInsets.all(22.w),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28.r),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: featured
                  ? [
                      Colors.white.withValues(alpha: 0.18),
                      theme.backgroundGradient.last.withValues(alpha: 0.32),
                      Colors.black.withValues(alpha: 0.24),
                    ]
                  : [
                      Colors.white.withValues(alpha: 0.10),
                      Colors.black.withValues(alpha: 0.22),
                    ],
            ),
            border: Border.all(
              color: featured
                  ? accent.withValues(alpha: 0.38)
                  : Colors.white.withValues(alpha: 0.10),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: featured
                    ? accent.withValues(alpha: 0.14)
                    : Colors.black.withValues(alpha: 0.18),
                blurRadius: featured ? 26 : 16,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 58.w,
                    height: 58.w,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18.r),
                      color: accent.withValues(alpha: featured ? 0.22 : 0.14),
                    ),
                    child: Icon(app.icon, color: accent, size: 30.sp),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.north_east_rounded,
                    color: Colors.white.withValues(alpha: 0.32),
                    size: 20.sp,
                  ),
                ],
              ),
              const Spacer(),
              Text(
                app.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: theme.textColor,
                  fontSize: 22.sp,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
              SizedBox(height: 6.h),
              Text(
                app.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: theme.textColor.withValues(alpha: 0.58),
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LauncherApp {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _LauncherApp({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });
}
