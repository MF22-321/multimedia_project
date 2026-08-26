import 'package:flutter/material.dart';

/// Keeps the direct Linux GPU overlay synchronized with Flutter routes.
///
/// A GtkGLArea is composited above FlView, so Flutter routes cannot visually
/// cover it. RouteAware viewers hide it before a page or dialog is pushed and
/// restore it when that route is popped.
final RouteObserver<ModalRoute<void>> vehicle3DRouteObserver =
    RouteObserver<ModalRoute<void>>();
