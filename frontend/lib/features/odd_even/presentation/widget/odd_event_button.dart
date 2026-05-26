import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class OddEvenButton extends StatelessWidget {
  final VoidCallback onPressed;

  const OddEvenButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200.w,
      height: 60.h,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Colors.white70),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30.r),
          ),
        ),
        onPressed: onPressed,
        child: Text(
          "Oke",
          style: TextStyle(fontSize: 22.sp, color: Colors.white),
        ),
      ),
    );
  }
}
