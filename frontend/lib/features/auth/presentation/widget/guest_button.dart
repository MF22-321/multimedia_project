import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class GuestButton extends StatelessWidget {
  final VoidCallback onTap;

  const GuestButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 300.w,
      height: 60.h,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Colors.white70),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30.r),
          ),
        ),
        onPressed: onTap,
        icon: const Icon(Icons.person_outline, color: Colors.white),
        label: Text(
          "Masuk sebagai tamu",
          style: TextStyle(
            fontSize: 22.sp,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}