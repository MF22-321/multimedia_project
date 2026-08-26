import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class Vehicle3DController extends ChangeNotifier {
  Vehicle3DController({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(_channelName);

  static const String _channelName = 'com.multimedia.vehicle3d/control';
  final MethodChannel _channel;

  int? textureId;
  bool available = false;
  bool loading = false;
  String renderer = 'fallback_png';
  String model = 'assets/images/veloz.png';
  String? error;
  int viewRevision = 0;
  double viewYaw = -0.38;
  double viewPitch = 0.08;
  double viewZoom = 1.16;
  double viewFocusX = 0;
  double viewFocusY = 0;
  Rect? directBoundsOverride;
  ValueChanged<Offset>? _vehicleTapHandler;

  void setDirectBoundsOverride(Rect? bounds) {
    if (directBoundsOverride == bounds) return;
    directBoundsOverride = bounds;
    notifyListeners();
  }

  Future<dynamic> _handleNativeMethod(MethodCall call) {
    if (call.method != 'vehicleTapped') return Future<dynamic>.value(null);
    final arguments = call.arguments;
    if (arguments is! Map) return Future<dynamic>.value(null);
    final x = (arguments['x'] as num?)?.toDouble() ?? 0.5;
    final y = (arguments['y'] as num?)?.toDouble() ?? 0.5;
    final position = Offset(x, y);
    // Acknowledge the native method call before opening Vehicle Analysis.
    // Opening it synchronously sends bounds/transform messages back over the
    // same channel while its vehicleTapped response is still pending.
    Timer.run(() => _vehicleTapHandler?.call(position));
    return Future<dynamic>.value(null);
  }

  void setVehicleTapHandler(ValueChanged<Offset>? handler) {
    _vehicleTapHandler = handler;
    _channel.setMethodCallHandler(handler == null ? null : _handleNativeMethod);
  }

  Future<bool> initializeDirectView() async {
    if (!Platform.isLinux) return false;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'initializeDirectView',
      );
      available = result?['available'] == true;
      renderer = result?['renderer']?.toString() ?? 'gtk_gl_area_zbuffer';
      model = result?['model']?.toString() ?? 'toyota_veloz_2022_glb_hd';
      if (!available) error = result?['message']?.toString();
    } on MissingPluginException catch (exception) {
      available = false;
      error = exception.message;
    } on PlatformException catch (exception) {
      available = false;
      error = exception.message;
    } catch (exception) {
      available = false;
      error = exception.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
    return available;
  }

  Future<void> setDirectViewBounds({
    required double x,
    required double y,
    required double width,
    required double height,
  }) async {
    if (!available) return;
    try {
      await _channel.invokeMethod<void>(
        'setDirectViewBounds',
        <String, dynamic>{
          'x': x.round(),
          'y': y.round(),
          'width': width.round(),
          'height': height.round(),
        },
      );
    } on PlatformException catch (exception) {
      error = exception.message;
    } on MissingPluginException catch (exception) {
      available = false;
      error = exception.message;
    } catch (exception) {
      error = exception.toString();
    }
  }

  Future<void> setDirectViewVisible(bool visible) async {
    if (!available) return;
    try {
      await _channel.invokeMethod<void>(
        'setDirectViewVisible',
        <String, dynamic>{'visible': visible},
      );
    } on PlatformException catch (exception) {
      error = exception.message;
    } on MissingPluginException catch (exception) {
      available = false;
      error = exception.message;
    } catch (exception) {
      error = exception.toString();
    }
  }

  Future<bool> initialize({
    int width = 960,
    int height = 540,
    bool autoRotate = false,
  }) async {
    if (!Platform.isLinux) {
      available = false;
      renderer = 'fallback_png';
      notifyListeners();
      return false;
    }
    loading = true;
    error = null;
    notifyListeners();
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'initialize',
        <String, dynamic>{
          'width': width,
          'height': height,
          'autoRotate': autoRotate,
        },
      );
      textureId = (result?['textureId'] as num?)?.toInt();
      available = result?['available'] == true && textureId != null;
      renderer = result?['renderer']?.toString() ?? 'native_opengl';
      model = result?['model']?.toString() ?? 'vehicle_3d';
      if (!available) error = result?['message']?.toString();
    } on MissingPluginException catch (exception) {
      available = false;
      renderer = 'fallback_png';
      error = exception.message;
    } on PlatformException catch (exception) {
      available = false;
      renderer = 'fallback_png';
      error = exception.message;
    } catch (exception) {
      available = false;
      renderer = 'fallback_png';
      error = exception.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
    return available;
  }

  Future<void> setTransform({
    required double yaw,
    required double pitch,
    required double zoom,
  }) async {
    if (!available) return;
    try {
      await _channel.invokeMethod<void>('setTransform', <String, dynamic>{
        'yaw': yaw,
        'pitch': pitch,
        'zoom': zoom,
      });
    } on PlatformException catch (exception) {
      error = exception.message;
    } on MissingPluginException catch (exception) {
      available = false;
      error = exception.message;
    } catch (exception) {
      error = exception.toString();
    }
  }

  Future<void> setViewTransform({
    required double yaw,
    required double pitch,
    required double zoom,
    double focusX = 0,
    double focusY = 0,
  }) async {
    viewYaw = yaw;
    viewPitch = pitch;
    viewZoom = zoom;
    viewFocusX = focusX;
    viewFocusY = focusY;
    viewRevision++;
    notifyListeners();
    await applyViewTransform(
      yaw: yaw,
      pitch: pitch,
      zoom: zoom,
      focusX: focusX,
      focusY: focusY,
    );
  }

  /// Applies a stored view without notifying Flutter listeners. This is used
  /// while the native overlay is being restored after a tab/route transition;
  /// rebuilding Flutter in the same compositor frame as GtkGLArea is shown can
  /// produce a full black frame on NVIDIA/GTK.
  Future<void> applyViewTransform({
    required double yaw,
    required double pitch,
    required double zoom,
    double focusX = 0,
    double focusY = 0,
  }) async {
    if (!available) return;
    try {
      await _channel.invokeMethod<void>('setViewTransform', <String, dynamic>{
        'yaw': yaw,
        'pitch': pitch,
        'zoom': zoom,
        'focusX': focusX,
        'focusY': focusY,
      });
    } on PlatformException catch (exception) {
      error = exception.message;
    } on MissingPluginException catch (exception) {
      available = false;
      error = exception.message;
    } catch (exception) {
      error = exception.toString();
    }
  }

  Future<void> setInteractionActive(bool active) async {
    if (!available) return;
    try {
      await _channel.invokeMethod<void>(
        'setInteractionActive',
        <String, dynamic>{'active': active},
      );
    } on PlatformException catch (exception) {
      error = exception.message;
    } on MissingPluginException catch (exception) {
      available = false;
      error = exception.message;
    } catch (exception) {
      error = exception.toString();
    }
  }

  Future<void> setAutoRotate(bool enabled) async {
    if (!available) return;
    try {
      await _channel.invokeMethod<void>('setAutoRotate', <String, dynamic>{
        'enabled': enabled,
      });
    } on PlatformException catch (exception) {
      error = exception.message;
    } on MissingPluginException catch (exception) {
      available = false;
      error = exception.message;
    } catch (exception) {
      error = exception.toString();
    }
  }

  Future<void> setActive(bool active) async {
    if (!available) return;
    try {
      await _channel.invokeMethod<void>('setActive', <String, dynamic>{
        'active': active,
      });
    } on PlatformException catch (exception) {
      error = exception.message;
    } on MissingPluginException catch (exception) {
      available = false;
      error = exception.message;
    } catch (exception) {
      error = exception.toString();
    }
  }

  Future<void> reset() async {
    if (!available) return;
    try {
      await _channel.invokeMethod<void>('reset');
    } on PlatformException catch (exception) {
      error = exception.message;
    } on MissingPluginException catch (exception) {
      available = false;
      error = exception.message;
    } catch (exception) {
      error = exception.toString();
    }
  }
}
