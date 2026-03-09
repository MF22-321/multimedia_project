import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class WarningButton extends StatefulWidget {
  final VoidCallback onPressed;

  const WarningButton({
    super.key,
    required this.onPressed,
  });

  @override
  State<WarningButton> createState() => _WarningButtonState();
}

class _WarningButtonState extends State<WarningButton>
    with SingleTickerProviderStateMixin {

  late AnimationController _controller;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 4, end: 12).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return SizedBox(
          width: 220.w,
          height: 65.h,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.white70),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(40.r),
              ),
              backgroundColor: Colors.black,
            ),
            onPressed: widget.onPressed,
            child: Text(
              "Oke",
              style: TextStyle(
                fontSize: 24.sp,
                color: Colors.white,
                shadows: [
                  Shadow(
                    blurRadius: _glowAnimation.value,
                    color: Colors.white.withOpacity(0.6),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}