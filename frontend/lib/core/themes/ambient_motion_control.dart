import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Gives foreground interactions priority over decorative ambient motion.
class AmbientMotionControl {
  const AmbientMotionControl._();

  static final ValueNotifier<bool> paused = ValueNotifier<bool>(false);
  static final ValueNotifier<bool> inspectionActive = ValueNotifier<bool>(
    false,
  );
  static int _interactionHolds = 0;
  static bool _temporarilySuspended = false;
  static Timer? _resumeTimer;

  static void beginInteraction() {
    _interactionHolds++;
    _sync();
  }

  static void endInteraction() {
    if (_interactionHolds > 0) _interactionHolds--;
    _sync();
  }

  static void suspendFor(Duration duration) {
    _temporarilySuspended = true;
    _resumeTimer?.cancel();
    _resumeTimer = Timer(duration, () {
      _temporarilySuspended = false;
      _sync();
    });
    _sync();
  }

  static void _sync() {
    final next = _interactionHolds > 0 || _temporarilySuspended;
    if (paused.value != next) paused.value = next;
  }
}

/// Display-synchronised clock shared by decorative backgrounds.
///
/// It stops completely when the app/route is inactive and follows Flutter's
/// actual frame cadence while active. This avoids the uneven pacing caused by
/// a wall-clock [Timer.periodic] competing with the compositor's vsync.
class AmbientFrameClock extends ChangeNotifier with WidgetsBindingObserver {
  AmbientFrameClock({
    Duration? interval,
    this.cycle = const Duration(seconds: 4),
    this.inspectionLayer = false,
  }) : interval = interval ?? _defaultInterval() {
    _resumed =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    AmbientMotionControl.paused.addListener(_syncTimer);
    AmbientMotionControl.inspectionActive.addListener(_syncTimer);
  }

  final Duration interval;
  final Duration cycle;
  final bool inspectionLayer;
  bool _enabled = false;
  bool _resumed = true;
  bool _disposed = false;
  bool _frameScheduled = false;
  int? _lastFrameTimestampMicros;
  int? _lastEmissionActiveMicros;
  int _activeElapsedMicros = 0;
  double value = 0;

  double get elapsedSeconds => _activeElapsedMicros / 1000000;

  bool get motionEnabled => interval > Duration.zero;

  set enabled(bool value) {
    if (_enabled == value) return;
    _enabled = value;
    _syncFrames();
  }

  bool get _shouldRun =>
      !_disposed &&
      interval > Duration.zero &&
      _enabled &&
      _resumed &&
      !AmbientMotionControl.paused.value &&
      (inspectionLayer
          ? AmbientMotionControl.inspectionActive.value
          : !AmbientMotionControl.inspectionActive.value);

  void _syncFrames() {
    if (!_shouldRun) {
      _lastFrameTimestampMicros = null;
      _lastEmissionActiveMicros = null;
      return;
    }
    _scheduleFrame();
  }

  void _scheduleFrame() {
    if (_frameScheduled || !_shouldRun) return;
    _frameScheduled = true;
    SchedulerBinding.instance.scheduleFrameCallback(_handleFrame);
  }

  void _handleFrame(Duration timestamp) {
    _frameScheduled = false;
    if (!_shouldRun) {
      _lastFrameTimestampMicros = null;
      return;
    }
    final frameMicros = timestamp.inMicroseconds;
    final previousFrame = _lastFrameTimestampMicros;
    if (previousFrame != null) {
      _activeElapsedMicros += math.max(frameMicros - previousFrame, 0);
    }
    _lastFrameTimestampMicros = frameMicros;
    final previousEmission = _lastEmissionActiveMicros;
    // A small tolerance prevents a nominal 60 Hz stream (16,666.7 us) from
    // being accidentally reduced to 30 Hz by integer rounding/jitter.
    if (previousEmission == null ||
        _activeElapsedMicros - previousEmission >=
            interval.inMicroseconds - 1000) {
      _lastEmissionActiveMicros = _activeElapsedMicros;
      _emitFrame();
    }
    _scheduleFrame();
  }

  // Kept as a listener target so route/interaction changes can immediately
  // start or stop the vsync chain.
  void _syncTimer() => _syncFrames();

  static Duration _defaultInterval() {
    final configured = int.tryParse(
      Platform.environment['AMBIENT_MOTION_FPS'] ?? '',
    );
    // Match the 60 Hz HMI display by default. The environment override remains
    // useful for thermal diagnostics or non-production software rendering.
    final fps = configured ?? 60;
    if (fps <= 0) return Duration.zero;
    return Duration(microseconds: 1000000 ~/ fps.clamp(1, 60));
  }

  void _emitFrame() {
    if (_disposed) return;
    final cycleMicros = cycle.inMicroseconds;
    value = cycleMicros <= 0
        ? 0
        : (_activeElapsedMicros % cycleMicros) / cycleMicros;
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _resumed = state == AppLifecycleState.resumed;
    _syncFrames();
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    AmbientMotionControl.paused.removeListener(_syncTimer);
    AmbientMotionControl.inspectionActive.removeListener(_syncTimer);
    super.dispose();
  }
}
