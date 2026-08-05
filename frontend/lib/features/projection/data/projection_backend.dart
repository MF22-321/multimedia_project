import 'package:flutter/services.dart';
import 'package:frontend/features/projection/domain/projection_models.dart';

abstract class ProjectionBackend {
  Future<ProjectionStatus> initialize();

  Future<ProjectionStatus> start(
    ProjectionTarget target, {
    ProjectionTransport transport = ProjectionTransport.wiredUsb,
  });

  Future<ProjectionStatus> disconnect();

  Future<ProjectionStatus> suspend();

  Future<ProjectionStatus> resume();

  Future<ProjectionStatus> getStatus();

  Future<void> sendTouch({
    required double x,
    required double y,
    required String action,
  });
}

class NativeProjectionBackend implements ProjectionBackend {
  NativeProjectionBackend({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(_channelName);

  static const String _channelName = 'com.multimedia.projection/control';
  final MethodChannel _channel;

  @override
  Future<ProjectionStatus> initialize() => _invokeStatus('initialize');

  @override
  Future<ProjectionStatus> start(
    ProjectionTarget target, {
    ProjectionTransport transport = ProjectionTransport.wiredUsb,
  }) {
    return _invokeStatus('start', {
      'target': target.wireName,
      'transport': transport.wireName,
    });
  }

  @override
  Future<ProjectionStatus> disconnect() => _invokeStatus('disconnect');

  @override
  Future<ProjectionStatus> suspend() => _invokeStatus('suspend');

  @override
  Future<ProjectionStatus> resume() => _invokeStatus('resume');

  @override
  Future<ProjectionStatus> getStatus() => _invokeStatus('getStatus');

  @override
  Future<void> sendTouch({
    required double x,
    required double y,
    required String action,
  }) {
    return _channel.invokeMethod<void>('sendTouch', {
      'x': x.clamp(0.0, 1.0),
      'y': y.clamp(0.0, 1.0),
      'action': action,
    });
  }

  Future<ProjectionStatus> _invokeStatus(
    String method, [
    Map<String, Object?>? arguments,
  ]) async {
    final result = await _channel.invokeMapMethod<Object?, Object?>(
      method,
      arguments,
    );
    if (result == null) {
      throw StateError('Native projection bridge returned no status');
    }
    return ProjectionStatus.fromMap(result);
  }
}
