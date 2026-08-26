import 'package:flutter/foundation.dart';

/// Coordinates the native GtkGLArea with full-screen Flutter overlays.
///
/// Navigator routes are handled by the 3D route observer, but voice-driven
/// SOP playback uses an OverlayEntry and therefore never changes routes. This
/// explicit ownership flag prevents the native surface (which is composited
/// above Flutter) from leaking through video and other full-screen content.
class Vehicle3DSurfaceControl {
  const Vehicle3DSurfaceControl._();

  static final ValueNotifier<bool> fullScreenContentActive =
      ValueNotifier<bool>(false);
}
