import 'dart:math';
import 'package:flutter/material.dart';

class PlayfulParticlesBackground extends StatefulWidget {
  const PlayfulParticlesBackground({super.key});

  @override
  State<PlayfulParticlesBackground> createState() =>
      _PlayfulParticlesBackgroundState();
}

class _PlayfulParticlesBackgroundState extends State<PlayfulParticlesBackground>
    with SingleTickerProviderStateMixin {

  late AnimationController controller;

  final Random random = Random();

  final List<_Bubble> bubbles = [];

  @override
  void initState() {
    super.initState();

    for (int i = 0; i < 35; i++) {
      bubbles.add(
        _Bubble(
          x: random.nextDouble(),
          y: random.nextDouble(),
          size: random.nextDouble() * 40 + 20,
          speed: random.nextDouble() * 0.0005 + 0.0003,
          opacity: random.nextDouble() * 0.25 + 0.05,
        ),
      );
    }

    controller = AnimationController(
      vsync: this,
      duration: const Duration(days: 1),
    )
      ..addListener(updateBubbles)
      ..repeat();
  }

  void updateBubbles() {

    for (final b in bubbles) {

      b.y -= b.speed;

      if (b.y < -0.1) {
        b.y = 1.1;
        b.x = random.nextDouble();
      }
    }

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _PlayfulPainter(bubbles),
      size: Size.infinite,
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}

class _Bubble {

  double x;
  double y;
  double size;
  double speed;
  double opacity;

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

  _PlayfulPainter(this.bubbles);

  @override
  void paint(Canvas canvas, Size size) {

    final paint = Paint();

    for (final b in bubbles) {

      final x = b.x * size.width;
      final y = b.y * size.height;

      paint.color = const Color(0xFFFFB8A8).withOpacity(b.opacity);

      canvas.drawCircle(
        Offset(x, y),
        b.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}