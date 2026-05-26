import 'dart:math';
import 'package:flutter/material.dart';

class RetroParticlesBackground extends StatefulWidget {
  const RetroParticlesBackground({super.key});

  @override
  State<RetroParticlesBackground> createState() =>
      _RetroParticlesBackgroundState();
}

class _RetroParticlesBackgroundState extends State<RetroParticlesBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController controller;

  final List<_RetroParticle> particles = [];
  final Random random = Random();

  @override
  void initState() {
    super.initState();

    /// generate particles sekali
    for (int i = 0; i < 120; i++) {
      particles.add(
        _RetroParticle(
          x: random.nextDouble(),
          y: random.nextDouble(),
          speed: random.nextDouble() * 0.002 + 0.001,
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

    controller =
        AnimationController(
            vsync: this,
            duration: const Duration(days: 1), // hampir infinite
          )
          ..addListener(updateParticles)
          ..repeat();
  }

  void updateParticles() {
    for (final p in particles) {
      p.y += p.speed;

      /// kalau sudah keluar layar spawn lagi dari atas
      if (p.y > 1) {
        p.y = -0.02;
        p.x = random.nextDouble();
      }
    }

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _RetroPainter(particles), size: Size.infinite);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}

class _RetroParticle {
  double x;
  double y;
  double speed;
  double height;
  double opacity;
  Color color;

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

  _RetroPainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (final p in particles) {
      final x = p.x * size.width;
      final y = p.y * size.height;

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
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
