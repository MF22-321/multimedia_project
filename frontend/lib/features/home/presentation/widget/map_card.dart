import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class MapCard extends StatelessWidget {
  const MapCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 400.h,
      decoration: BoxDecoration(
        color: Colors.grey.shade800,
        borderRadius: BorderRadius.circular(25.r),
      ),
      child: const Center(
        child: Text("MAP PLACEHOLDER", style: TextStyle(color: Colors.white)),
      ),
    );
  }
}