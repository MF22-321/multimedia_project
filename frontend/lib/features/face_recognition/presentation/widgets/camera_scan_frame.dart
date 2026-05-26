import 'package:flutter/material.dart';

class CameraScanFrame extends StatelessWidget {
  final Widget child;
  final double progress; // 0.0 - 1.0
  final bool isScanning;
  final int secondsLeft;
  final double width;
  final double height;
  final double radius;

  const CameraScanFrame({
    super.key,
    required this.child,
    required this.progress,
    required this.isScanning,
    required this.secondsLeft,
    this.width = 300,
    this.height = 300,
    this.radius = 20,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(width, height),
            painter: _RoundedRectProgressPainter(
              progress: progress,
              radius: radius,
              baseColor: Colors.grey.shade300,
              progressColor: Colors.deepPurple,
              strokeWidth: 6,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(radius),
              child: child,
            ),
          ),
          if (isScanning)
            Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(radius),
              ),
            ),
          if (isScanning)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "$secondsLeft",
                  style: const TextStyle(
                    fontSize: 44,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  "Scanning...",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _RoundedRectProgressPainter extends CustomPainter {
  final double progress;
  final double radius;
  final Color baseColor;
  final Color progressColor;
  final double strokeWidth;

  _RoundedRectProgressPainter({
    required this.progress,
    required this.radius,
    required this.baseColor,
    required this.progressColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(strokeWidth / 2),
      Radius.circular(radius),
    );

    final basePaint = Paint()
      ..color = baseColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawRRect(rrect, basePaint);

    final path = Path()..addRRect(rrect);

    for (final metric in path.computeMetrics()) {
      final extracted = metric.extractPath(
        0,
        metric.length * progress.clamp(0.0, 1.0),
      );
      canvas.drawPath(extracted, progressPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RoundedRectProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.baseColor != baseColor ||
        oldDelegate.progressColor != progressColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
