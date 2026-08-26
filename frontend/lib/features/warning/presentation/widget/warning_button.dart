import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class WarningButton extends StatelessWidget {
  final VoidCallback onPressed;

  const WarningButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
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
        onPressed: onPressed,
        child: Text(
          "Oke",
          style: TextStyle(
            fontSize: 24.sp,
            color: Colors.white,
            shadows: [
              Shadow(blurRadius: 8, color: Colors.white.withValues(alpha: 0.6)),
            ],
          ),
        ),
      ),
    );
  }
}
