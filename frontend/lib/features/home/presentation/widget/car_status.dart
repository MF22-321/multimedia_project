import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:frontend/core/themes/ambient_motion_control.dart';
import 'package:frontend/core/themes/car_theme.dart';
import 'package:frontend/core/services/vehicle_3d_controller.dart';
import 'package:frontend/core/widgets/vehicle_3d_viewer.dart';
import 'package:frontend/features/vehicle_analysis/presentation/vehicle_analysis_page.dart';

class CarStatusCard extends StatefulWidget {
  const CarStatusCard({super.key});

  @override
  State<CarStatusCard> createState() => _CarStatusCardState();
}

class _CarStatusCardState extends State<CarStatusCard> {
  static const double _homeYaw = -0.38;
  static const double _homePitch = 0.08;
  static const double _homeZoom = 1.20;

  int selectedMode = 0;
  bool _openingAnalysis = false;
  late final Vehicle3DController _vehicleController;
  OverlayEntry? _analysisOverlay;

  @override
  void initState() {
    super.initState();
    _vehicleController = Vehicle3DController()
      ..viewYaw = _homeYaw
      ..viewPitch = _homePitch
      ..viewZoom = _homeZoom;
  }

  void _openVehicleAnalysis() {
    if (_openingAnalysis || !mounted) return;
    _openingAnalysis = true;
    AmbientMotionControl.inspectionActive.value = true;
    AmbientMotionControl.suspendFor(const Duration(milliseconds: 300));
    late final OverlayEntry entry;
    final useDirectGpuView = _vehicleController.available;
    entry = OverlayEntry(
      // Keep the same GPU view alive and move it into the analysis viewport.
      // This avoids loading/painting a second 156k-triangle model during the
      // transition and avoids remapping a new Linux GL surface.
      opaque: false,
      builder: (_) => VehicleAnalysisPage(
        controller: _vehicleController,
        externalNativeView: useDirectGpuView,
        onClose: () => _closeVehicleAnalysis(entry),
      ),
    );
    _analysisOverlay = entry;
    Overlay.of(context, rootOverlay: true).insert(entry);
  }

  void _closeVehicleAnalysis(OverlayEntry entry) {
    if (_analysisOverlay != entry) return;
    entry.remove();
    _analysisOverlay = null;
    _openingAnalysis = false;
    AmbientMotionControl.inspectionActive.value = false;
    unawaited(
      _vehicleController.setViewTransform(
        yaw: _homeYaw,
        pitch: _homePitch,
        zoom: _homeZoom,
      ),
    );
    _vehicleController.setVehicleTapHandler((_) => _openVehicleAnalysis());
  }

  @override
  void dispose() {
    _analysisOverlay?.remove();
    _analysisOverlay = null;
    AmbientMotionControl.inspectionActive.value = false;
    _vehicleController.dispose();
    super.dispose();
  }

  Color getMusicAccentColor(CarThemeType type, CarThemeData theme) {
    switch (type) {
      case CarThemeType.comfort:
        return const Color(0xFF6CB4FF);

      case CarThemeType.sport:
        return Colors.redAccent;

      case CarThemeType.futuristic:
        return const Color(0xFF00E5FF);

      case CarThemeType.retro:
        return const Color(0xFFFF2BC2);

      case CarThemeType.playful:
        return const Color(0xFFC6A883);

      case CarThemeType.custom:
        return theme.buttonColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: CarThemes.currentTheme,
      builder: (context, themeType, _) {
        return ValueListenableBuilder(
          valueListenable: CarThemes.customTheme,
          builder: (context, __, ___) {
            final theme = CarThemes.getTheme(themeType);

            final musicAccent = themeType == CarThemeType.comfort
                ? getMusicAccentColor(themeType, theme)
                : theme.accentColor;

            return AnimatedContainer(
              duration: const Duration(milliseconds: 400),

              height: 295.h,

              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30.r),

                gradient: LinearGradient(
                  colors: [
                    theme.backgroundGradient.last.withValues(alpha: 0.8),
                    theme.backgroundGradient.last.withValues(alpha: 0.5),
                    Colors.black.withValues(alpha: 0.4),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),

                border: Border.all(
                  color: theme.accentColor.withValues(alpha: 0.4),
                  width: 2,
                ),
              ),

              child: Stack(
                children: [
                  /// Static contact shadow keeps the transparent native model
                  /// visually grounded without adding work to the GL drag
                  /// path or forcing another continuously rendered surface.
                  Positioned(
                    top: 163.h,
                    left: 95.w,
                    right: 95.w,
                    height: 30.h,
                    child: IgnorePointer(
                      child: RepaintBoundary(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              colors: [
                                Colors.black.withValues(alpha: 0.48),
                                Colors.black.withValues(alpha: 0.20),
                                Colors.transparent,
                              ],
                              stops: const [0, 0.55, 1],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  /// =========================
                  /// CAR IMAGE
                  /// =========================
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: 215.h,
                    child: Center(
                      child: Vehicle3DViewer(
                        controller: _vehicleController,
                        width: 470.w,
                        height: 215.h,
                        modelScale: 1.10,
                        useNativeView: true,
                        showBadge: false,
                        showResetButton: false,
                        onTap: (_) => _openVehicleAnalysis(),
                      ),
                    ),
                  ),

                  /// =========================
                  /// DRIVE MODE MENU
                  /// =========================
                  Positioned(
                    bottom: 15.h,
                    left: 20.w,
                    right: 20.w,

                    child: Container(
                      height: 62.h,

                      padding: EdgeInsets.symmetric(horizontal: 10.w),

                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),

                        borderRadius: BorderRadius.circular(30.r),

                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),

                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),

                            blurRadius: 20,
                          ),
                        ],
                      ),

                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,

                        children: [
                          _modeButton(
                            index: 0,
                            icon: Icons.eco,
                            title: "Eco",
                            accent: musicAccent,
                          ),

                          _modeButton(
                            index: 1,
                            icon: Icons.flash_on,
                            title: "Sport",
                            accent: musicAccent,
                          ),

                          _modeButton(
                            index: 2,
                            icon: Icons.directions_car,
                            title: "Drive",
                            accent: musicAccent,
                          ),

                          _modeButton(
                            index: 3,
                            icon: Icons.person,
                            title: "Profile",
                            accent: musicAccent,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _modeButton({
    required int index,
    required IconData icon,
    required String title,
    required Color accent,
  }) {
    final active = selectedMode == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedMode = index;
        });
      },

      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),

        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),

        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18.r),

          color: active ? accent.withValues(alpha: 0.18) : Colors.transparent,

          border: Border.all(
            color: active ? accent.withValues(alpha: 0.45) : Colors.transparent,
          ),

          boxShadow: active
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.35),
                    blurRadius: 16,
                  ),
                ]
              : [],
        ),

        child: Row(
          children: [
            Icon(icon, color: active ? accent : Colors.white70, size: 24.sp),

            SizedBox(width: 8.w),

            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 250),

              style: TextStyle(
                color: active ? accent : Colors.white70,

                fontSize: 15.sp,

                fontWeight: FontWeight.w700,
              ),

              child: Text(title),
            ),
          ],
        ),
      ),
    );
  }
}
