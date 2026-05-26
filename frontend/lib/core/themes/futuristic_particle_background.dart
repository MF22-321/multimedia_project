import 'dart:math';
import 'package:flutter/material.dart';

class FuturisticParticlesBackground extends StatefulWidget {
  const FuturisticParticlesBackground({super.key});

  @override
  State<FuturisticParticlesBackground> createState() =>
      _FuturisticParticlesBackgroundState();
}

class _FuturisticParticlesBackgroundState
    extends State<FuturisticParticlesBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController controller;

  final List<_Particle> particles = [];
  bool initialized = false;

  @override
  void initState() {
    super.initState();

    controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  void _generateParticles(Size size) {
    final random = Random(10);

    const gridSpacing = 18.0;

    for (double x = 0; x < size.width; x += gridSpacing) {
      for (double y = 0; y < size.height; y += gridSpacing) {
        if (random.nextDouble() > 0.7) continue;

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

        return AnimatedBuilder(
          animation: controller,
          builder: (context, child) {
            return CustomPaint(
              painter: _DigitalParticlePainter(particles, controller.value),
              size: Size.infinite,
            );
          },
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
  final double animation;

  _DigitalParticlePainter(this.particles, this.animation);

  @override
  void paint(Canvas canvas, Size size) {
    const particleColor = Color(0xFF00E5FF);

    final paint = Paint()..style = PaintingStyle.fill;

    for (final p in particles) {
      final brightness = (sin(animation * 2 * pi + p.phase * 6) + 1) / 2;

      paint.color = particleColor.withValues(alpha: brightness);

      canvas.drawRect(
        Rect.fromCenter(center: p.position, width: 3, height: 3),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
