import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:frontend/features/projection/data/projection_backend.dart';
import 'package:frontend/features/projection/domain/projection_models.dart';

class ProjectionController extends ChangeNotifier {
  ProjectionController({
    required ProjectionBackend backend,
    this.pollInterval = const Duration(milliseconds: 500),
  }) : _backend = backend;

  final ProjectionBackend _backend;
  final Duration pollInterval;

  ProjectionStatus status = const ProjectionStatus.idle();
  bool busy = false;
  Timer? _pollTimer;
  bool _refreshing = false;
  bool _disposed = false;

  Future<void> initialize() async {
    await _run(() => _backend.initialize());
    _startPolling();
  }

  Future<void> connect(
    ProjectionTarget target, {
    ProjectionTransport transport = ProjectionTransport.wiredUsb,
  }) {
    return _run(() => _backend.start(target, transport: transport));
  }

  Future<void> disconnect() {
    return _run(_backend.disconnect);
  }

  Future<void> suspend() {
    return _run(_backend.suspend);
  }

  Future<void> resume() {
    return _run(_backend.resume);
  }

  Future<void> refresh() async {
    if (_refreshing || _disposed) return;
    _refreshing = true;
    try {
      status = await _backend.getStatus();
      _notifySafely();
    } catch (error) {
      status = status.copyWith(
        state: ProjectionConnectionState.error,
        clearTexture: true,
        message: 'Projection bridge error: $error',
      );
      _notifySafely();
    } finally {
      _refreshing = false;
    }
  }

  Future<void> sendTouch({
    required double x,
    required double y,
    required String action,
  }) async {
    if (!status.isActive || status.textureId == null) return;
    await _backend.sendTouch(x: x, y: y, action: action);
  }

  Future<void> _run(Future<ProjectionStatus> Function() operation) async {
    if (busy || _disposed) return;
    busy = true;
    _notifySafely();
    try {
      status = await operation();
    } catch (error) {
      status = status.copyWith(
        state: ProjectionConnectionState.error,
        clearTexture: true,
        message: 'Projection bridge error: $error',
      );
    } finally {
      busy = false;
      _notifySafely();
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(pollInterval, (_) => unawaited(refresh()));
  }

  void _notifySafely() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _pollTimer?.cancel();
    super.dispose();
  }
}
