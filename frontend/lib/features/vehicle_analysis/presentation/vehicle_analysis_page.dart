import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:frontend/core/localization/app_strings.dart';
import 'package:frontend/core/services/vehicle_3d_controller.dart';
import 'package:frontend/core/themes/ambient_motion_control.dart';
import 'package:frontend/core/themes/car_theme.dart';
import 'package:frontend/core/themes/futuristic_particle_background.dart';
import 'package:frontend/core/themes/playful_background.dart';
import 'package:frontend/core/themes/retro_background.dart';
import 'package:frontend/core/widgets/vehicle_3d_viewer.dart';

enum _TirePosition { frontLeft, frontRight, rearLeft, rearRight }

class _TireReading {
  const _TireReading(this.position, this.pressurePsi);

  final _TirePosition position;
  final int pressurePsi;

  String get label => switch (position) {
    _TirePosition.frontLeft => AppStrings.frontLeft,
    _TirePosition.frontRight => AppStrings.frontRight,
    _TirePosition.rearLeft => AppStrings.rearLeft,
    _TirePosition.rearRight => AppStrings.rearRight,
  };

  bool get normal => pressurePsi >= 30 && pressurePsi <= 35;
}

class VehicleAnalysisPage extends StatefulWidget {
  const VehicleAnalysisPage({
    super.key,
    this.controller,
    this.onClose,
    this.externalNativeView = false,
  });

  final Vehicle3DController? controller;
  final VoidCallback? onClose;
  final bool externalNativeView;

  @override
  State<VehicleAnalysisPage> createState() => _VehicleAnalysisPageState();
}

class _VehicleAnalysisPageState extends State<VehicleAnalysisPage>
    with SingleTickerProviderStateMixin {
  static const double _overviewZoom = 0.92;

  late final Vehicle3DController _vehicleController;
  late final bool _ownsController;
  late final AnimationController _entranceController;
  late final Animation<double> _entrance;
  late final Animation<Offset> _entranceOffset;
  final GlobalKey _vehicleTargetKey = GlobalKey();
  Rect? _lastVehicleBounds;
  double _yaw = -0.38;
  double _pitch = 0.08;
  double _zoom = _overviewZoom;
  double _gestureZoomStart = _overviewZoom;
  static const List<_TireReading> _tires = <_TireReading>[
    _TireReading(_TirePosition.frontLeft, 32),
    _TireReading(_TirePosition.frontRight, 32),
    _TireReading(_TirePosition.rearLeft, 30),
    _TireReading(_TirePosition.rearRight, 30),
  ];

  _TireReading? _selectedTire;
  bool _closing = false;
  bool _ambientInteractionHeld = false;
  Timer? _ambientReleaseTimer;
  bool _nativeTransformFrameScheduled = false;
  bool _nativeTransformInFlight = false;
  bool _nativeTransformQueued = false;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      reverseDuration: const Duration(milliseconds: 160),
    );
    _entrance = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _entranceOffset = Tween<Offset>(
      begin: const Offset(0.012, 0),
      end: Offset.zero,
    ).animate(_entrance);
    _entranceController.forward();
    _ownsController = widget.controller == null;
    _vehicleController = widget.controller ?? Vehicle3DController();
    if (widget.externalNativeView) {
      _vehicleController.setVehicleTapHandler(_handleVehicleTap);
    }
    unawaited(
      _vehicleController.setViewTransform(
        yaw: -0.38,
        pitch: 0.08,
        zoom: _overviewZoom,
      ),
    );
  }

  @override
  void dispose() {
    _releaseAmbientInteraction(settle: false);
    _entranceController.dispose();
    if (widget.externalNativeView) {
      _vehicleController.setDirectBoundsOverride(null);
    }
    if (_ownsController) {
      _vehicleController.setVehicleTapHandler(null);
      _vehicleController.dispose();
    }
    super.dispose();
  }

  Future<void> _requestClose() async {
    if (_closing) return;
    _closing = true;
    await _entranceController.reverse();
    if (!mounted) return;
    (widget.onClose ?? () => Navigator.pop(context))();
  }

  void _syncExternalVehicleBounds() {
    if (!mounted || !widget.externalNativeView) return;
    final box =
        _vehicleTargetKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final origin = box.localToGlobal(Offset.zero);
    final bounds = Rect.fromLTWH(
      origin.dx,
      origin.dy,
      box.size.width,
      box.size.height,
    );
    if (_lastVehicleBounds == bounds) return;
    _lastVehicleBounds = bounds;
    _vehicleController.setDirectBoundsOverride(bounds);
    unawaited(_activateExternalVehicle(bounds));
  }

  Future<void> _activateExternalVehicle(Rect bounds) async {
    // The Linux GtkGLArea is shared with Home. Apply its new allocation first,
    // then explicitly make it visible again. Relying on the old Home visibility
    // state can leave the surface parked at -10000,-10000 on NVIDIA/GTK when
    // the analysis overlay and its first layout arrive in the same frame.
    await _vehicleController.setDirectViewBounds(
      x: bounds.left,
      y: bounds.top,
      width: bounds.width,
      height: bounds.height,
    );
    if (!mounted) return;
    await _vehicleController.setViewTransform(
      yaw: _yaw,
      pitch: _pitch,
      zoom: _zoom,
    );
    if (!mounted) return;
    await _vehicleController.setDirectViewVisible(true);
  }

  void _onScaleStart(ScaleStartDetails details) {
    _ambientReleaseTimer?.cancel();
    _ambientReleaseTimer = null;
    if (!_ambientInteractionHeld) {
      _ambientInteractionHeld = true;
      AmbientMotionControl.beginInteraction();
    }
    _gestureZoomStart = _zoom;
    // Reassert the already-mapped shared surface before the first transform.
    // This is idempotent and also queues a recovery frame if GTK invalidated
    // the backing surface while the overlay was settling.
    unawaited(_vehicleController.setDirectViewVisible(true));
    unawaited(_vehicleController.setInteractionActive(true));
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    _yaw += details.focalPointDelta.dx * 0.008;
    _pitch = (_pitch + details.focalPointDelta.dy * 0.004).clamp(-0.18, 0.42);
    _zoom = (_gestureZoomStart * details.scale).clamp(0.72, 1.55);
    _scheduleNativeTransform();
  }

  void _onScaleEnd(ScaleEndDetails details) {
    // Pointer-up can arrive before the scheduled display frame. Preserve the
    // final coordinates while keeping at most one MethodChannel call active.
    _queueNativeTransform();
    _releaseAmbientInteraction(settle: true);
    unawaited(_vehicleController.setInteractionActive(false));
  }

  void _scheduleNativeTransform() {
    if (_nativeTransformFrameScheduled) return;
    _nativeTransformFrameScheduled = true;
    SchedulerBinding.instance.scheduleFrameCallback((_) {
      _nativeTransformFrameScheduled = false;
      if (mounted) _queueNativeTransform();
    });
  }

  void _queueNativeTransform() {
    if (_nativeTransformInFlight) {
      _nativeTransformQueued = true;
      return;
    }
    unawaited(_flushNativeTransform());
  }

  Future<void> _flushNativeTransform() async {
    _nativeTransformInFlight = true;
    try {
      do {
        _nativeTransformQueued = false;
        final yaw = _yaw;
        final pitch = _pitch;
        final zoom = _zoom;
        await _vehicleController.applyViewTransform(
          yaw: yaw,
          pitch: pitch,
          zoom: zoom,
          focusX: _vehicleController.viewFocusX,
          focusY: _vehicleController.viewFocusY,
        );
      } while (mounted && _nativeTransformQueued);
    } finally {
      _nativeTransformInFlight = false;
    }
  }

  void _releaseAmbientInteraction({required bool settle}) {
    if (!_ambientInteractionHeld) return;
    if (settle) {
      _ambientReleaseTimer?.cancel();
      _ambientReleaseTimer = Timer(const Duration(milliseconds: 120), () {
        _ambientReleaseTimer = null;
        if (!_ambientInteractionHeld) return;
        _ambientInteractionHeld = false;
        AmbientMotionControl.endInteraction();
      });
      return;
    }
    _ambientReleaseTimer?.cancel();
    _ambientReleaseTimer = null;
    _ambientInteractionHeld = false;
    AmbientMotionControl.endInteraction();
  }

  void _handleVehicleTap(Offset position) {
    // On the default three-quarter view, the two visible wheel centers occupy
    // the lower-left and lower-right thirds. Taps elsewhere keep overview.
    if (position.dy < 0.48) {
      _showOverview();
      return;
    }
    _focusTire(
      position.dx < 0.52
          ? _tires[2] // Rear left.
          : _tires[0], // Front left.
    );
  }

  void _showOverview() {
    final wasInspectingTire = _selectedTire != null;
    setState(() => _selectedTire = null);
    // Tire focus is a compositor-only zoom; returning from it should not
    // recompute the mesh. When already in overview, this button still acts as
    // the explicit reset for a user-rotated model.
    if (wasInspectingTire) return;
    _yaw = -0.38;
    _pitch = 0.08;
    _zoom = _overviewZoom;
    unawaited(
      _vehicleController.setViewTransform(
        yaw: -0.38,
        pitch: 0.08,
        zoom: _overviewZoom,
      ),
    );
  }

  void _focusTire(_TireReading tire) {
    setState(() => _selectedTire = tire);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.externalNativeView) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _syncExternalVehicleBounds();
      });
    }
    return ValueListenableBuilder<CarThemeType>(
      valueListenable: CarThemes.currentTheme,
      builder: (context, themeType, _) {
        final theme = CarThemes.getTheme(themeType);
        final accent = themeType == CarThemeType.comfort
            ? const Color(0xFF6CB4FF)
            : theme.accentColor;
        return Scaffold(
          body: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: theme.backgroundGradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              ),
              if (themeType == CarThemeType.futuristic)
                const Positioned.fill(
                  child: FuturisticParticlesBackground(inspectionLayer: true),
                ),
              if (themeType == CarThemeType.retro)
                const Positioned.fill(
                  child: RetroParticlesBackground(inspectionLayer: true),
                ),
              if (themeType == CarThemeType.playful)
                const Positioned.fill(
                  child: PlayfulParticlesBackground(inspectionLayer: true),
                ),
              SafeArea(
                child: Padding(
                  padding: EdgeInsets.all(26.w),
                  child: Column(
                    children: [
                      SlideTransition(
                        position: _entranceOffset,
                        child: _AnalysisHeader(
                          accent: accent,
                          onBack: _requestClose,
                        ),
                      ),
                      SizedBox(height: 20.h),
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(
                              child: _VehicleStage(
                                accent: accent,
                                controller: _vehicleController,
                                onVehicleTap: _handleVehicleTap,
                                onOverview: _showOverview,
                                selectedTire: _selectedTire,
                                externalNativeView: widget.externalNativeView,
                                vehicleTargetKey: _vehicleTargetKey,
                                onScaleStart: _onScaleStart,
                                onScaleUpdate: _onScaleUpdate,
                                onScaleEnd: _onScaleEnd,
                              ),
                            ),
                            SizedBox(width: 22.w),
                            SlideTransition(
                              position: _entranceOffset,
                              child: SizedBox(
                                width: 330.w,
                                child: _TireDiagnosticsPanel(
                                  accent: accent,
                                  tires: _tires,
                                  selected: _selectedTire,
                                  onSelected: _focusTire,
                                ),
                              ),
                            ),
                          ],
                        ),
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
  }
}

class _AnalysisHeader extends StatelessWidget {
  const _AnalysisHeader({required this.accent, required this.onBack});

  final Color accent;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 66.h,
      child: Row(
        children: [
          IconButton.filledTonal(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
          ),
          SizedBox(width: 16.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                AppStrings.choose(
                  id: 'Analisis Kendaraan',
                  en: 'Vehicle Analysis',
                ),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 27.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                AppStrings.choose(
                  id: 'Toyota Veloz · tampilan interaktif',
                  en: 'Toyota Veloz · interactive inspection',
                ),
                style: TextStyle(color: Colors.white60, fontSize: 14.sp),
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 9.h),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18.r),
              border: Border.all(color: accent.withValues(alpha: 0.55)),
            ),
            child: Row(
              children: [
                Icon(Icons.touch_app_rounded, color: accent, size: 19.sp),
                SizedBox(width: 8.w),
                Text(
                  AppStrings.choose(
                    id: 'Sentuh ban untuk memeriksa',
                    en: 'Tap a tire to inspect',
                  ),
                  style: TextStyle(color: accent, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VehicleStage extends StatelessWidget {
  const _VehicleStage({
    required this.accent,
    required this.controller,
    required this.onVehicleTap,
    required this.onOverview,
    required this.selectedTire,
    required this.externalNativeView,
    required this.vehicleTargetKey,
    required this.onScaleStart,
    required this.onScaleUpdate,
    required this.onScaleEnd,
  });

  final Color accent;
  final Vehicle3DController controller;
  final ValueChanged<Offset> onVehicleTap;
  final VoidCallback onOverview;
  final _TireReading? selectedTire;
  final bool externalNativeView;
  final GlobalKey vehicleTargetKey;
  final GestureScaleStartCallback onScaleStart;
  final GestureScaleUpdateCallback onScaleUpdate;
  final GestureScaleEndCallback onScaleEnd;

  @override
  Widget build(BuildContext context) {
    final selected = selectedTire;
    final focusedFront =
        selected?.position == _TirePosition.frontLeft ||
        selected?.position == _TirePosition.frontRight;
    final markerAlignment = focusedFront
        ? const Alignment(0.40, 0.47)
        : const Alignment(-0.46, 0.47);
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(32.r),
        border: Border.all(color: accent.withValues(alpha: 0.36)),
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(22.w, 17.h, 14.w, 0),
            child: Row(
              children: [
                Icon(Icons.view_in_ar_rounded, color: accent),
                SizedBox(width: 10.w),
                Text(
                  selectedTire?.label ??
                      AppStrings.choose(id: 'Ikhtisar 3D', en: '3D Overview'),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: onOverview,
                  icon: const Icon(Icons.center_focus_strong_rounded),
                  label: Text(
                    AppStrings.choose(id: 'Tampilkan semua', en: 'Overview'),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.fromLTRB(18.w, 4.h, 18.w, 12.h),
              child: Center(
                // Raster the model in a bounded inspection viewport instead
                // of at the full 2560x1600 stage resolution. The model remains
                // substantially larger than Home while avoiding a costly
                // full-screen drawVertices surface on Jetson Orin Nano.
                child: SizedBox(
                  width: 780.w,
                  height: 380.h,
                  child: KeyedSubtree(
                    key: vehicleTargetKey,
                    child: externalNativeView
                        ? GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTapUp: (details) {
                              final box =
                                  vehicleTargetKey.currentContext
                                          ?.findRenderObject()
                                      as RenderBox?;
                              if (box == null || !box.hasSize) return;
                              onVehicleTap(
                                Offset(
                                  (details.localPosition.dx / box.size.width)
                                      .clamp(0.0, 1.0),
                                  (details.localPosition.dy / box.size.height)
                                      .clamp(0.0, 1.0),
                                ),
                              );
                            },
                            onScaleStart: onScaleStart,
                            onScaleUpdate: onScaleUpdate,
                            onScaleEnd: onScaleEnd,
                            child: const ColoredBox(color: Colors.transparent),
                          )
                        : Stack(
                            fit: StackFit.expand,
                            children: [
                              // Keep drawVertices on a stable layer. Scaling or
                              // translating this subtree triggers persistent
                              // black frames in the Jetson NVIDIA compositor.
                              // The model is already enlarged on entry; tire
                              // focus is communicated by the animated marker
                              // and diagnostics panel without repainting it.
                              Vehicle3DViewer(
                                controller: controller,
                                showBadge: false,
                                showResetButton: false,
                                onTap: onVehicleTap,
                              ),
                              if (selected != null)
                                IgnorePointer(
                                  child: TweenAnimationBuilder<double>(
                                    key: ValueKey(selected.position),
                                    tween: Tween(begin: 0.72, end: 1),
                                    duration: const Duration(milliseconds: 220),
                                    curve: Curves.easeOutBack,
                                    builder: (context, scale, child) => Align(
                                      alignment: markerAlignment,
                                      child: Transform.scale(
                                        scale: scale,
                                        child: child,
                                      ),
                                    ),
                                    child: Container(
                                      width: 46.w,
                                      height: 46.w,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: accent.withValues(alpha: 0.10),
                                        border: Border.all(
                                          color: accent,
                                          width: 2.5,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: accent.withValues(
                                              alpha: 0.40,
                                            ),
                                            blurRadius: 18,
                                            spreadRadius: 2,
                                          ),
                                        ],
                                      ),
                                      child: Icon(
                                        Icons.tire_repair_rounded,
                                        color: accent,
                                        size: 22.sp,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(bottom: 14.h),
            child: Text(
              AppStrings.choose(
                id: 'Drag untuk memutar · scroll/pinch untuk zoom',
                en: 'Drag to rotate · scroll/pinch to zoom',
              ),
              style: TextStyle(color: Colors.white54, fontSize: 13.sp),
            ),
          ),
        ],
      ),
    );
  }
}

class _TireDiagnosticsPanel extends StatelessWidget {
  const _TireDiagnosticsPanel({
    required this.accent,
    required this.tires,
    required this.selected,
    required this.onSelected,
  });

  final Color accent;
  final List<_TireReading> tires;
  final _TireReading? selected;
  final ValueChanged<_TireReading> onSelected;

  @override
  Widget build(BuildContext context) {
    final active = selected;
    return Container(
      padding: EdgeInsets.all(19.w),
      decoration: BoxDecoration(
        color: const Color(0xE6101720),
        borderRadius: BorderRadius.circular(30.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.tirePressure,
            style: TextStyle(
              color: Colors.white,
              fontSize: 22.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 5.h),
          Text(
            AppStrings.choose(
              id: 'Rentang rekomendasi 30–35 PSI',
              en: 'Recommended range 30–35 PSI',
            ),
            style: TextStyle(color: Colors.white60, fontSize: 13.sp),
          ),
          SizedBox(height: 15.h),
          for (final tire in tires) ...[
            _TireButton(
              tire: tire,
              active: tire.position == active?.position,
              accent: accent,
              onTap: () => onSelected(tire),
            ),
            SizedBox(height: 9.h),
          ],
          const Spacer(),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(15.w),
            decoration: BoxDecoration(
              color: (active?.normal == true ? Colors.greenAccent : accent)
                  .withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(20.r),
            ),
            child: active == null
                ? Text(
                    AppStrings.choose(
                      id: 'Pilih ban pada model atau daftar di atas untuk melihat detail.',
                      en: 'Select a tire on the model or list above to view details.',
                    ),
                    style: const TextStyle(color: Colors.white70),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        active.label,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 5.h),
                      Text(
                        '${active.pressurePsi} PSI · ${AppStrings.normal}',
                        style: TextStyle(
                          color: Colors.greenAccent,
                          fontSize: 22.sp,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
          ),
          SizedBox(height: 12.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline, color: Colors.amberAccent),
              SizedBox(width: 9.w),
              Expanded(
                child: Text(
                  AppStrings.choose(
                    id: 'Data konfigurasi demo. Sensor TPMS belum terhubung ke ESP32.',
                    en: 'Demo configuration data. TPMS sensors are not connected to the ESP32 yet.',
                  ),
                  style: TextStyle(color: Colors.white60, fontSize: 12.sp),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TireButton extends StatelessWidget {
  const _TireButton({
    required this.tire,
    required this.active,
    required this.accent,
    required this.onTap,
  });

  final _TireReading tire;
  final bool active;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(17.r),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: active
              ? accent.withValues(alpha: 0.17)
              : Colors.white.withValues(alpha: 0.045),
          borderRadius: BorderRadius.circular(17.r),
          border: Border.all(
            color: active ? accent : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.tire_repair_rounded,
              color: active ? accent : Colors.white70,
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Text(
                tire.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              '${tire.pressurePsi} PSI',
              style: TextStyle(
                color: tire.normal ? Colors.greenAccent : Colors.orangeAccent,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
