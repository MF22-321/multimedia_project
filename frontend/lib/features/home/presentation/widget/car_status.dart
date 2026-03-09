import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class CarStatusCard extends StatelessWidget {
  const CarStatusCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 250.h,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.blue, Colors.blueAccent],
        ),
        borderRadius: BorderRadius.circular(25.r),
      ),
      child: const Center(
        child: Text("CAR IMAGE PLACEHOLDER",
            style: TextStyle(color: Colors.white)),
      ),
    );
  }
}