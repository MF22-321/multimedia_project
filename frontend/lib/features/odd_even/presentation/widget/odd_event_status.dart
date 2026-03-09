import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class OddEvenStatus extends StatelessWidget {
  final bool isEven;

  const OddEvenStatus({super.key, required this.isEven});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10.w,
          height: 10.w,
          decoration: BoxDecoration(
            color: isEven ? Colors.cyanAccent : Colors.orangeAccent,
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(width: 12.w),
        Text(
          isEven ? "GENAP" : "GANJIL",
          style: TextStyle(
            fontSize: 40.sp,
            fontWeight: FontWeight.bold,
            color: isEven ? Colors.cyanAccent : Colors.orangeAccent,
          ),
        ),
      ],
    );
  }
}