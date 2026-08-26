import 'dart:math';
import 'package:flutter/material.dart';
import 'package:frontend/core/themes/ambient_motion_control.dart';

class FuturisticParticlesBackground extends StatefulWidget {
  const FuturisticParticlesBackground({
    super.key,
    this.inspectionLayer = false,
  });

  final bool inspectionLayer;

  @override
  State<FuturisticParticlesBackground> createState() =>
      _FuturisticParticlesBackgroundState();
}

class _FuturisticParticlesBackgroundState
    extends State<FuturisticParticlesBackground> {
  late final AmbientFrameClock controller;

  final List<_Particle> particles = [];
  bool initialized = false;

  @override
  void initState() {
    super.initState();

    // Home can be inserted while its cached navigation stack still reports a
    // disabled TickerMode during the login transition. AmbientFrameClock has
    // its own lifecycle and interaction pause gates, so enable it for the
    // lifetime of this visible background instead of inheriting that stale
    // navigation value.
    controller = AmbientFrameClock(inspectionLayer: widget.inspectionLayer)
      ..enabled = true;
  }

  void _generateParticles(Size size) {
    final random = Random(10);

    // Keep the field visibly alive on a 2560x1600 display without forcing more
    // than a few hundred decorative draw calls per ambient frame.
    const gridSpacing = 64.0;

    for (double x = 0; x < size.width; x += gridSpacing) {
      for (double y = 0; y < size.height; y += gridSpacing) {
        if (random.nextDouble() > 0.35) continue;

        particles.add(_Particle(Offset(x, y), random.nextDouble()));
      }
    }

    initialized = true;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);

        if (!initialized) {
          _generateParticles(size);
        }

        return RepaintBoundary(
          child: CustomPaint(
            painter: _DigitalParticlePainter(particles, controller),
            size: Size.infinite,
            isComplex: true,
            willChange: controller.motionEnabled,
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}

class _Particle {
  final Offset position;
  final double phase;

  _Particle(this.position, this.phase);
}

class _DigitalParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final AmbientFrameClock animation;

  _DigitalParticlePainter(this.particles, this.animation)
    : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    const particleColor = Color(0xFF00E5FF);

    final paint = Paint()..style = PaintingStyle.fill;

    for (final p in particles) {
      final brightness = (sin(animation.value * 2 * pi + p.phase * 6) + 1) / 2;

      paint.color = particleColor.withValues(alpha: 0.18 + brightness * 0.55);

      canvas.drawRect(
        Rect.fromCenter(center: p.position, width: 3, height: 3),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DigitalParticlePainter oldDelegate) =>
      oldDelegate.particles != particles || oldDelegate.animation != animation;
}
