import 'dart:math';
import 'package:flutter/material.dart';
import 'package:frontend/core/themes/ambient_motion_control.dart';

class RetroParticlesBackground extends StatefulWidget {
  const RetroParticlesBackground({super.key, this.inspectionLayer = false});

  final bool inspectionLayer;

  @override
  State<RetroParticlesBackground> createState() =>
      _RetroParticlesBackgroundState();
}

class _RetroParticlesBackgroundState extends State<RetroParticlesBackground> {
  late final AmbientFrameClock controller;

  final List<_RetroParticle> particles = [];
  final Random random = Random(27);

  @override
  void initState() {
    super.initState();

    /// generate particles sekali
    for (int i = 0; i < 70; i++) {
      particles.add(
        _RetroParticle(
          x: random.nextDouble(),
          y: random.nextDouble(),
          // Normalized screen distance per second. Motion is time-based so it
          // keeps the same speed at 60 Hz and never jumps after a slow frame.
          speed: random.nextDouble() * 0.072 + 0.036,
          height: random.nextDouble() * 12 + 4,
          opacity: random.nextDouble() * 0.6 + 0.3,
          color: [
            const Color(0xFFFF00FF),
            const Color(0xFFFF2BC2),
            const Color(0xFFB517FF),
          ][random.nextInt(3)],
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
        painter: _RetroPainter(
          particles,
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

class _RetroParticle {
  final double x;
  final double y;
  final double speed;
  final double height;
  final double opacity;
  final Color color;

  _RetroParticle({
    required this.x,
    required this.y,
    required this.speed,
    required this.height,
    required this.opacity,
    required this.color,
  });
}

class _RetroPainter extends CustomPainter {
  final List<_RetroParticle> particles;
  final AmbientFrameClock animation;

  _RetroPainter(
    this.particles, {
    required this.animation,
    required Listenable repaint,
  }) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (final p in particles) {
      final x = p.x * size.width;
      final normalizedY = (p.y + animation.elapsedSeconds * p.speed) % 1.04;
      final y = (normalizedY - 0.02) * size.height;

      paint.color = p.color.withValues(alpha: p.opacity);

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, 2, p.height),
          const Radius.circular(2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RetroPainter oldDelegate) =>
      oldDelegate.particles != particles;
}
