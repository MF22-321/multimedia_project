import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class ToyotaLogoAnimation extends StatefulWidget {
  const ToyotaLogoAnimation({super.key});

  @override
  State<ToyotaLogoAnimation> createState() => _ToyotaLogoAnimationState();
}

class _ToyotaLogoAnimationState extends State<ToyotaLogoAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Text(
          "TOYOTA",
          style: TextStyle(
            fontSize: 90.sp,
            fontWeight: FontWeight.bold,
            color: Colors.red.shade700,
            letterSpacing: 8.w,
            shadows: [Shadow(blurRadius: 40.r, color: Colors.red.shade900)],
          ),
        ),
      ),
    );
  }
}
