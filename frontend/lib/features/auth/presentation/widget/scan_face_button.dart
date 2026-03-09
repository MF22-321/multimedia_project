import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class ScanFaceButton extends StatelessWidget {
  const ScanFaceButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180.w,
      height: 180.w,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30.r),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.face, size: 60.sp, color: Colors.grey),
          SizedBox(height: 10.h),
          Text("Scan Face", style: TextStyle(fontSize: 18.sp, color: Colors.grey))
        ],
      ),
    );
  }
}