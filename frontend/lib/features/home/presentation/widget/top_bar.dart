import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class TopBar extends StatelessWidget {
  const TopBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [

        Row(
          children: [
            CircleAvatar(radius: 25.r),
            SizedBox(width: 15.w),
            Text(
              "Hello, User",
              style: TextStyle(color: Colors.white, fontSize: 22.sp),
            ),
          ],
        ),

        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text("22.22", style: TextStyle(color: Colors.white, fontSize: 20.sp)),
            Text("Monday, 17th Nov 2025",
                style: TextStyle(color: Colors.white70, fontSize: 16.sp)),
          ],
        )
      ],
    );
  }
}