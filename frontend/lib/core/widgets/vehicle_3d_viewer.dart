import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:frontend/core/models/vehicle_3d_mesh.dart';
import 'package:frontend/core/navigation/app_navigation.dart';
import 'package:frontend/core/navigation/vehicle_3d_route_observer.dart';
import 'package:frontend/core/navigation/vehicle_3d_surface_control.dart';
import 'package:frontend/core/services/vehicle_3d_controller.dart';
import 'package:frontend/core/themes/ambient_motion_control.dart';
import 'package:frontend/core/widgets/vehicle_3d_scene_painter.dart';

class Vehicle3DViewer extends StatefulWidget {
  const Vehicle3DViewer({
    super.key,
    this.width,
    this.height,
    this.modelScale = 1,
    this.fallbackAsset = 'assets/images/veloz.png',
    this.modelAsset = 'assets/models/toyota_veloz_2022_source.sdtmesh',
    this.autoRotate = false,
    this.useNativeView = false,
    // External pixel-buffer Texture updates corrupt some frames on
    // Flutter Linux/NVIDIA. Home opts into the persistent GtkGLArea path;
    // Canvas remains the portable fallback.
    this.useNativeTexture = false,
    this.interactive = true,
    this.showBadge = true,
    this.showResetButton = true,
    this.controller,
    this.onTap,
  });

  final double? width;
  final double? height;
  final double modelScale;
  final String fallbackAsset;
  final String modelAsset;
  final bool autoRotate;
  final bool useNativeView;
  final bool useNativeTexture;
  final bool interactive;
  final bool showBadge;
  final bool showResetButton;
  final Vehicle3DController? controller;
  final ValueChanged<Offset>? onTap;

  @override
  State<Vehicle3DViewer> createState() => _Vehicle3DViewerState();
}

class _Vehicle3DViewerState extends State<Vehicle3DViewer>
    with WidgetsBindingObserver, RouteAware {
  late final Vehicle3DController _controller;
  late final bool _ownsController;
  Timer? _transformThrottle;
  Timer? _resumeRotationTimer;
  Timer? _directShowTimer;
  double _yaw = -0.38;
  double _pitch = 0.08;
  double _zoom = 1.16;
  double _gestureZoomStart = 1.16;
  double _focusX = 0;
  double _focusY = 0;
  int _appliedViewRevision = 0;
  Vehicle3DMesh? _mesh;
  Vehicle3DRenderCache? _renderCache;
  final GlobalKey _viewerKey = GlobalKey();
  bool _directViewReady = false;
  bool _directViewInitializationComplete = false;
  Rect? _lastDirectBounds;
  bool _directBoundsScheduled = false;
  bool _showDirectViewAfterBounds = false;
  bool? _lastDirectVisibility;
  ModalRoute<void>? _route;
  Animation<double>? _routeAnimation;
  Animation<double>? _routeSecondaryAnimation;
  bool _appResumed = true;
  bool _transformInFlight = false;
  bool _transformQueued = false;
  bool _nativeTransformFrameScheduled = false;
  bool _canvasRepaintFrameScheduled = false;
  bool _ambientInteractionHeld = false;
  Timer? _ambientReleaseTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? Vehicle3DController();
    _yaw = _controller.viewYaw;
    _pitch = _controller.viewPitch;
    _zoom = _controller.viewZoom;
    _focusX = _controller.viewFocusX;
    _focusY = _controller.viewFocusY;
    _appliedViewRevision = _controller.viewRevision;
    _controller.addListener(_onControllerChanged);
    if (widget.useNativeView) {
      AppNavigation.currentIndex.addListener(_syncDirectVisibility);
      Vehicle3DSurfaceControl.fullScreenContentActive.addListener(
        _syncDirectVisibility,
      );
      unawaited(_initializeDirectView());
    } else if (widget.useNativeTexture) {
      unawaited(
        _controller.initialize(
          width: 960,
          height: 540,
          autoRotate: widget.autoRotate,
        ),
      );
    } else {
      unawaited(_loadImportedMesh());
    }
  }

  Future<void> _initializeDirectView() async {
    final ready = await _controller.initializeDirectView();
    if (!mounted) return;
    setState(() {
      _directViewReady = ready;
      _directViewInitializationComplete = true;
    });
    if (ready) {
      // The GtkGLArea outlives this widget while Home is replaced by another
      // tab. Reset its retained transform before showing it again, otherwise
      // the previous angle flashes and then jumps on the first new gesture.
      await _controller.setTransform(yaw: _yaw, pitch: _pitch, zoom: _zoom);
      if (!mounted) return;
      _syncDirectVisibility();
    } else {
      unawaited(_loadImportedMesh());
    }
  }

  bool get _shouldShowDirectView =>
      _appResumed &&
      !Vehicle3DSurfaceControl.fullScreenContentActive.value &&
      AppNavigation.currentIndex.value == 2 &&
      _route?.isCurrent == true &&
      _routeAnimation?.status == AnimationStatus.completed &&
      _routeSecondaryAnimation?.status == AnimationStatus.dismissed;

  bool get _directViewBorrowed => _controller.directBoundsOverride != null;

  Future<void> _setDirectVisibility(bool visible) async {
    // Vehicle Analysis borrows the same GtkGLArea without pushing a route.
    // A late lifecycle/route callback from the cached Home viewer must not
    // park that surface while it is being dragged in Tire Pressure.
    if (!visible && _directViewBorrowed) {
      if (!Vehicle3DSurfaceControl.fullScreenContentActive.value) return;
      // Full-screen SOP must hide the borrowed surface, but Tire Pressure
      // still owns its native tap callback. Preserve that callback so closing
      // the video restores a fully interactive car, not merely its pixels.
      if (_lastDirectVisibility == false) return;
      _lastDirectVisibility = false;
      await _controller.setDirectViewVisible(false);
      return;
    }
    if (!visible) _directShowTimer?.cancel();
    if (_lastDirectVisibility == visible) return;
    _lastDirectVisibility = visible;
    _controller.setVehicleTapHandler(
      visible && widget.onTap != null ? _onNativeVehicleTap : null,
    );
    await _controller.setDirectViewVisible(visible);
  }

  void _onNativeVehicleTap(Offset position) {
    if (!mounted || !_shouldShowDirectView) return;
    widget.onTap?.call(position);
  }

  void _syncDirectVisibility() {
    if (!_directViewReady) return;
    if (Vehicle3DSurfaceControl.fullScreenContentActive.value) {
      unawaited(_setDirectVisibility(false));
      return;
    }
    if (_directViewBorrowed) {
      // Tire Pressure owns bounds and tap handling while it borrows the
      // surface. Restore only visibility after a full-screen SOP closes;
      // never replace its native tap callback with Home's callback.
      _lastDirectVisibility = true;
      unawaited(_controller.setDirectViewVisible(true));
      return;
    }
    final visible = _shouldShowDirectView;
    if (!visible) {
      _showDirectViewAfterBounds = false;
      unawaited(_setDirectVisibility(false));
      return;
    }

    // The GtkGLArea is above FlView. Always position it before showing it so
    // its old/default bounds cannot flash over Driver Select or a route
    // transition for one compositor frame.
    _lastDirectBounds = null;
    unawaited(
      _controller.applyViewTransform(
        yaw: _yaw,
        pitch: _pitch,
        zoom: _zoom,
        focusX: _focusX,
        focusY: _focusY,
      ),
    );
    _scheduleDirectBounds(showWhenReady: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!widget.useNativeView) return;
    final route = ModalRoute.of<void>(context);
    if (route == _route) return;
    if (_route != null) vehicle3DRouteObserver.unsubscribe(this);
    _routeAnimation?.removeStatusListener(_onRouteAnimationStatus);
    _routeSecondaryAnimation?.removeStatusListener(_onRouteAnimationStatus);
    _route = route;
    _routeAnimation = route?.animation;
    _routeSecondaryAnimation = route?.secondaryAnimation;
    _routeAnimation?.addStatusListener(_onRouteAnimationStatus);
    _routeSecondaryAnimation?.addStatusListener(_onRouteAnimationStatus);
    if (route != null) vehicle3DRouteObserver.subscribe(this, route);
    _syncDirectVisibility();
  }

  void _onRouteAnimationStatus(AnimationStatus _) => _syncDirectVisibility();

  void _setRouteVisibility(bool _) => _syncDirectVisibility();

  @override
  void didPush() => _setRouteVisibility(true);

  @override
  void didPushNext() => _setRouteVisibility(false);

  @override
  void didPopNext() => _setRouteVisibility(true);

  @override
  void didPop() => _setRouteVisibility(false);

  void _scheduleDirectBounds({bool showWhenReady = false}) {
    _showDirectViewAfterBounds |= showWhenReady;
    if (_directBoundsScheduled) return;
    _directBoundsScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _directBoundsScheduled = false;
      final showAfterBounds = _showDirectViewAfterBounds;
      _showDirectViewAfterBounds = false;
      if (!mounted || !_directViewReady || !_shouldShowDirectView) return;
      final overrideBounds = _controller.directBoundsOverride;
      final Rect bounds;
      if (overrideBounds != null) {
        bounds = Rect.fromLTWH(
          overrideBounds.left.roundToDouble(),
          overrideBounds.top.roundToDouble(),
          overrideBounds.width.roundToDouble(),
          overrideBounds.height.roundToDouble(),
        );
      } else {
        final box = _viewerKey.currentContext?.findRenderObject() as RenderBox?;
        if (box == null || !box.hasSize) return;
        final origin = box.localToGlobal(Offset.zero);
        bounds = Rect.fromLTWH(
          origin.dx.roundToDouble(),
          origin.dy.roundToDouble(),
          box.size.width.roundToDouble(),
          box.size.height.roundToDouble(),
        );
      }
      if (_lastDirectBounds != bounds) {
        _lastDirectBounds = bounds;
        await _controller.setDirectViewBounds(
          x: bounds.left,
          y: bounds.top,
          width: bounds.width,
          height: bounds.height,
        );
        if (!showAfterBounds && mounted && _shouldShowDirectView) {
          // The same GtkGLArea is moved between Home and Tire Pressure.
          // Reassert visibility only after the new bounds have reached GTK;
          // this also refreshes the surface when returning to Home even though
          // this widget's cached visibility state was already `true`.
          await _controller.setDirectViewVisible(true);
        }
      }
      if (showAfterBounds && mounted && _shouldShowDirectView) {
        // GtkGLArea must not be mapped in the same compositor frame that
        // replaces Driver Select or a cached tab. NVIDIA/GTK can otherwise
        // present a persistent black surface until the native view is hidden
        // again. Let Flutter paint several ambient frames first.
        _directShowTimer?.cancel();
        _directShowTimer = Timer(const Duration(milliseconds: 220), () {
          if (mounted && _shouldShowDirectView) {
            unawaited(_setDirectVisibility(true));
          }
        });
      }
    });
    // A tab/lifecycle notification can arrive while Flutter is idle. A
    // post-frame callback alone does not request a new frame in that state.
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  Future<void> _loadImportedMesh() async {
    try {
      final mesh = await Vehicle3DMeshRepository.load(widget.modelAsset);
      if (mounted) {
        setState(() {
          _mesh = mesh;
          _renderCache = Vehicle3DRenderCache.forMesh(mesh);
        });
      }
    } catch (error) {
      debugPrint('Vehicle GLB mesh fallback: $error');
    }
  }

  void _onControllerChanged() {
    if (!mounted) return;
    if (_appliedViewRevision != _controller.viewRevision) {
      _appliedViewRevision = _controller.viewRevision;
      _yaw = _controller.viewYaw;
      _pitch = _controller.viewPitch;
      _zoom = _controller.viewZoom;
      _focusX = _controller.viewFocusX;
      _focusY = _controller.viewFocusY;
    }
    setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appResumed = state == AppLifecycleState.resumed;
    if (widget.useNativeView) {
      _syncDirectVisibility();
    }
    if (widget.useNativeTexture) {
      unawaited(_controller.setActive(state == AppLifecycleState.resumed));
    }
  }

  void _onScaleStart(ScaleStartDetails details) {
    if (!widget.interactive) return;
    _ambientReleaseTimer?.cancel();
    _ambientReleaseTimer = null;
    if (!_ambientInteractionHeld) {
      _ambientInteractionHeld = true;
      AmbientMotionControl.beginInteraction();
    }
    _gestureZoomStart = _zoom;
    _resumeRotationTimer?.cancel();
    if (widget.useNativeView) {
      unawaited(_controller.setInteractionActive(true));
    }
    if (widget.useNativeTexture) {
      unawaited(_controller.setAutoRotate(false));
    }
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (!widget.interactive) return;
    _yaw += details.focalPointDelta.dx * 0.008;
    _pitch = (_pitch + details.focalPointDelta.dy * 0.004).clamp(-0.18, 0.42);
    _zoom = (_gestureZoomStart * details.scale).clamp(0.72, 1.55);
    if (widget.useNativeTexture || widget.useNativeView) {
      _scheduleTransform();
    } else {
      _scheduleCanvasRepaint();
    }
  }

  void _scheduleCanvasRepaint() {
    if (_canvasRepaintFrameScheduled) return;
    _canvasRepaintFrameScheduled = true;
    // Coalesce all pointer samples into the next compositor frame. A fixed
    // 16 ms Timer drifts against a 16.67 ms display cadence and periodically
    // produces a short/long frame pair that feels like a hitch.
    SchedulerBinding.instance.scheduleFrameCallback((_) {
      _canvasRepaintFrameScheduled = false;
      if (mounted) setState(() {});
    });
  }

  void _scheduleTransform() {
    if (widget.useNativeView) {
      if (_nativeTransformFrameScheduled) return;
      _nativeTransformFrameScheduled = true;
      // Align native updates with Flutter's display frame instead of a 24 ms
      // wall-clock timer. This gives stable 60 Hz frame pacing on the Jetson
      // display while still coalescing every pointer event within one frame.
      SchedulerBinding.instance.scheduleFrameCallback((_) {
        _nativeTransformFrameScheduled = false;
        if (mounted) _queueNativeTransform();
      });
      return;
    }
    if (_transformThrottle?.isActive == true) return;
    // The legacy external texture performs a GPU-to-CPU readback, so it stays
    // capped at 30 FPS. Home uses the frame-synchronised direct renderer above.
    _transformThrottle = Timer(const Duration(milliseconds: 33), () {
      _queueNativeTransform();
    });
  }

  void _queueNativeTransform() {
    if (_transformInFlight) {
      _transformQueued = true;
      return;
    }
    unawaited(_flushNativeTransform());
  }

  Future<void> _flushNativeTransform() async {
    _transformInFlight = true;
    try {
      do {
        _transformQueued = false;
        final yaw = _yaw;
        final pitch = _pitch;
        final zoom = _zoom;
        await _controller.setTransform(yaw: yaw, pitch: pitch, zoom: zoom);
      } while (mounted && _transformQueued);
    } finally {
      _transformInFlight = false;
    }
  }

  void _onScaleEnd(ScaleEndDetails details) {
    _releaseAmbientInteraction(settle: true);
    if (widget.useNativeView) {
      unawaited(_controller.setInteractionActive(false));
    }
    if (widget.useNativeTexture || widget.useNativeView) {
      _transformThrottle?.cancel();
      _queueNativeTransform();
    } else if (mounted) {
      // Commit the last coalesced transform even when pointer-up arrives
      // before the scheduled display frame.
      setState(() {});
    }
    if (!widget.useNativeTexture || !widget.interactive || !widget.autoRotate) {
      return;
    }
    _resumeRotationTimer?.cancel();
    _resumeRotationTimer = Timer(const Duration(seconds: 4), () {
      unawaited(_controller.setAutoRotate(true));
    });
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

  Future<void> _resetView() async {
    setState(() {
      _yaw = -0.38;
      _pitch = 0.08;
      _zoom = 1.16;
      _focusX = 0;
      _focusY = 0;
    });
    if (widget.useNativeTexture) {
      await _controller.reset();
    } else if (widget.useNativeView) {
      await _controller.setViewTransform(yaw: _yaw, pitch: _pitch, zoom: _zoom);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _transformThrottle?.cancel();
    _resumeRotationTimer?.cancel();
    _directShowTimer?.cancel();
    _releaseAmbientInteraction(settle: false);
    if (widget.useNativeView && _directViewReady) {
      unawaited(_controller.setInteractionActive(false));
      _controller.setVehicleTapHandler(null);
    }
    if (_route != null) vehicle3DRouteObserver.unsubscribe(this);
    _routeAnimation?.removeStatusListener(_onRouteAnimationStatus);
    _routeSecondaryAnimation?.removeStatusListener(_onRouteAnimationStatus);
    if (widget.useNativeView) {
      AppNavigation.currentIndex.removeListener(_syncDirectVisibility);
      Vehicle3DSurfaceControl.fullScreenContentActive.removeListener(
        _syncDirectVisibility,
      );
    }
    _controller.removeListener(_onControllerChanged);
    if (widget.useNativeView) {
      unawaited(_setDirectVisibility(false));
    }
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nativeReady =
        widget.useNativeTexture &&
        _controller.available &&
        _controller.textureId != null;
    final useCanvasRenderer =
        !widget.useNativeTexture &&
        (!widget.useNativeView ||
            (_directViewInitializationComplete && !_directViewReady));
    final canvasMeshReady = _mesh != null && _renderCache != null;
    if (_directViewReady && _shouldShowDirectView) _scheduleDirectBounds();
    return SizedBox(
      key: _viewerKey,
      width: widget.width,
      height: widget.height,
      child: RepaintBoundary(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Never paint the lightweight procedural car while the direct
            // native Veloz is initializing. That temporary renderer caused a
            // visibly smaller car to flash before the real model appeared.
            if (widget.useNativeView && !_directViewInitializationComplete)
              const ColoredBox(
                key: ValueKey('vehicle-3d-direct-pending'),
                color: Colors.transparent,
              ),
            if (useCanvasRenderer && canvasMeshReady)
              GestureDetector(
                key: const ValueKey('vehicle-3d-canvas'),
                behavior: HitTestBehavior.opaque,
                onTapUp: widget.onTap == null
                    ? null
                    : (details) {
                        final box =
                            _viewerKey.currentContext?.findRenderObject()
                                as RenderBox?;
                        if (box == null || !box.hasSize) return;
                        widget.onTap!(
                          Offset(
                            (details.localPosition.dx / box.size.width)
                                .clamp(0.0, 1.0)
                                .toDouble(),
                            (details.localPosition.dy / box.size.height)
                                .clamp(0.0, 1.0)
                                .toDouble(),
                          ),
                        );
                      },
                onScaleStart: _onScaleStart,
                onScaleUpdate: _onScaleUpdate,
                onScaleEnd: _onScaleEnd,
                child: CustomPaint(
                  painter: Vehicle3DScenePainter(
                    yaw: _yaw,
                    pitch: _pitch,
                    zoom: _zoom,
                    focusX: _focusX,
                    focusY: _focusY,
                    modelScale: widget.modelScale,
                    mesh: _mesh,
                    renderCache: _renderCache,
                  ),
                  isComplex: true,
                  // Jetson's NVIDIA/GTK compositor is more stable when this
                  // large drawVertices layer is not promoted to a raster-cache
                  // texture. Gesture updates are already throttled separately.
                  willChange: widget.interactive,
                ),
              ),
            if (useCanvasRenderer && !canvasMeshReady)
              Image.asset(
                widget.fallbackAsset,
                key: const ValueKey('vehicle-3d-fallback'),
                fit: BoxFit.contain,
                filterQuality: FilterQuality.medium,
              ),
            if (widget.useNativeView && _directViewReady)
              GestureDetector(
                key: const ValueKey('vehicle-3d-direct-input'),
                behavior: HitTestBehavior.opaque,
                onTapUp: widget.onTap == null
                    ? null
                    : (details) {
                        final box =
                            _viewerKey.currentContext?.findRenderObject()
                                as RenderBox?;
                        if (box == null || !box.hasSize) return;
                        widget.onTap!(
                          Offset(
                            (details.localPosition.dx / box.size.width)
                                .clamp(0.0, 1.0)
                                .toDouble(),
                            (details.localPosition.dy / box.size.height)
                                .clamp(0.0, 1.0)
                                .toDouble(),
                          ),
                        );
                      },
                onScaleStart: _onScaleStart,
                onScaleUpdate: _onScaleUpdate,
                onScaleEnd: _onScaleEnd,
                child: const ColoredBox(color: Colors.transparent),
              ),
            // External GPU textures should not be cross-faded through an
            // OpacityLayer. Switching directly avoids transient black layers
            // on the Linux OpenGL compositor while the first frame arrives.
            if (nativeReady)
              GestureDetector(
                key: const ValueKey('vehicle-3d-native'),
                behavior: HitTestBehavior.opaque,
                onScaleStart: _onScaleStart,
                onScaleUpdate: _onScaleUpdate,
                onScaleEnd: _onScaleEnd,
                child: Transform.flip(
                  // glReadPixels preserves OpenGL's bottom-left origin;
                  // Flutter's pixel buffer uses a top-left visual origin.
                  flipY: true,
                  child: Texture(
                    textureId: _controller.textureId!,
                    filterQuality: FilterQuality.low,
                  ),
                ),
              )
            else if (widget.useNativeTexture)
              Image.asset(
                widget.fallbackAsset,
                key: const ValueKey('vehicle-3d-fallback'),
                fit: BoxFit.contain,
              ),
            if (widget.useNativeTexture && _controller.loading)
              const Center(
                child: SizedBox.square(
                  dimension: 28,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            if ((!widget.useNativeTexture || nativeReady) && widget.showBadge)
              Positioned(
                top: 8,
                left: 8,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.42),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.cyanAccent.withValues(alpha: 0.55),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    child: Text(
                      _mesh == null
                          ? '3D · DRAG / PINCH'
                          : 'VELOZ GLB · DRAG / PINCH',
                      style: const TextStyle(
                        color: Colors.cyanAccent,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.7,
                      ),
                    ),
                  ),
                ),
              ),
            if ((!widget.useNativeTexture || nativeReady) &&
                widget.interactive &&
                widget.showResetButton)
              Positioned(
                top: 7,
                right: 7,
                child: IconButton(
                  tooltip: 'Reset 3D view',
                  visualDensity: VisualDensity.compact,
                  onPressed: _resetView,
                  icon: const Icon(Icons.threesixty, color: Colors.white70),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
