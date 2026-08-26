import 'dart:math';
import 'package:flutter/material.dart';
import 'package:frontend/core/themes/ambient_motion_control.dart';

class PlayfulParticlesBackground extends StatefulWidget {
  const PlayfulParticlesBackground({super.key, this.inspectionLayer = false});

  final bool inspectionLayer;

  @override
  State<PlayfulParticlesBackground> createState() =>
      _PlayfulParticlesBackgroundState();
}

class _PlayfulParticlesBackgroundState
    extends State<PlayfulParticlesBackground> {
  late final AmbientFrameClock controller;

  final Random random = Random(43);

  final List<_Bubble> bubbles = [];

  @override
  void initState() {
    super.initState();

    for (int i = 0; i < 24; i++) {
      bubbles.add(
        _Bubble(
          x: random.nextDouble(),
          y: random.nextDouble(),
          size: random.nextDouble() * 40 + 20,
          // Normalized screen distance per second, matching the old visual
          // speed while allowing display-synchronised 60 Hz animation.
          speed: random.nextDouble() * 0.018 + 0.0108,
          opacity: random.nextDouble() * 0.25 + 0.05,
        ),
      );
    }

    controller = AmbientFrameClock(
      cycle: const Duration(days: 1),
      inspectionLayer: widget.inspectionLayer,
    )..enabled = true;
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _PlayfulPainter(
          bubbles,
          animation: controller,
          repaint: controller,
        ),
        size: Size.infinite,
        isComplex: true,
        willChange: controller.motionEnabled,
      ),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}

class _Bubble {
  final double x;
  final double y;
  final double size;
  final double speed;
  final double opacity;

  _Bubble({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.opacity,
  });
}

class _PlayfulPainter extends CustomPainter {
  final List<_Bubble> bubbles;
  final AmbientFrameClock animation;

  _PlayfulPainter(
    this.bubbles, {
    required this.animation,
    required Listenable repaint,
  }) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();

    for (final b in bubbles) {
      final x = b.x * size.width;
      final travel = (b.y - animation.elapsedSeconds * b.speed + 0.1) % 1.2;
      final y = (travel - 0.1) * size.height;

      paint.color = const Color(0xFFFFB8A8).withValues(alpha: b.opacity);

      canvas.drawCircle(Offset(x, y), b.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _PlayfulPainter oldDelegate) =>
      oldDelegate.bubbles != bubbles;
}
