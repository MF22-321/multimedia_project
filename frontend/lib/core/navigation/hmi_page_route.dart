import 'package:flutter/material.dart';
import 'package:frontend/core/themes/ambient_motion_control.dart';

const Duration _hmiForwardDuration = Duration(milliseconds: 230);
const Duration _hmiReverseDuration = Duration(milliseconds: 190);
const Duration _hmiFrameBudgetHold = Duration(milliseconds: 300);

/// A lightweight head-unit transition that stays on the compositor thread.
///
/// Full-screen fades create a large offscreen opacity layer at 2560x1600.
/// A small translation gives the same navigation cue while keeping the page
/// raster stable and typically costs only a composited transform per frame.
class HmiPageRoute<T> extends PageRouteBuilder<T> {
  HmiPageRoute({
    required WidgetBuilder builder,
    super.settings,
    super.fullscreenDialog,
  }) : super(
         opaque: true,
         transitionDuration: _hmiForwardDuration,
         reverseTransitionDuration: _hmiReverseDuration,
         pageBuilder: (context, animation, secondaryAnimation) =>
             builder(context),
         transitionsBuilder: _buildHmiTransition,
       );
}

/// Pauses decorative animation while Navigator is compositing two routes.
/// This also covers named routes, which do not instantiate [HmiPageRoute].
final NavigatorObserver hmiNavigationObserver = _HmiNavigationObserver();

class _HmiNavigationObserver extends NavigatorObserver {
  void _reserveFrameBudget() {
    AmbientMotionControl.suspendFor(_hmiFrameBudgetHold);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _reserveFrameBudget();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _reserveFrameBudget();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _reserveFrameBudget();
  }
}

class HmiPageTransitionsBuilder extends PageTransitionsBuilder {
  const HmiPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return _buildHmiTransition(context, animation, secondaryAnimation, child);
  }
}

Widget _buildHmiTransition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  final incomingPosition =
      Tween<Offset>(begin: const Offset(0.014, 0), end: Offset.zero).animate(
        CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        ),
      );
  final outgoingPosition =
      Tween<Offset>(begin: Offset.zero, end: const Offset(-0.005, 0)).animate(
        CurvedAnimation(
          parent: secondaryAnimation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        ),
      );

  return ClipRect(
    child: SlideTransition(
      position: outgoingPosition,
      child: SlideTransition(
        position: incomingPosition,
        child: RepaintBoundary(child: child),
      ),
    ),
  );
}
