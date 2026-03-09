import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class SideMenu extends StatelessWidget {
  const SideMenu({super.key});

  Widget buildButton(IconData icon, String label, {bool active = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 15.h),
      child: Column(
        children: [
          Container(
            width: 70.w,
            height: 70.w,
            decoration: BoxDecoration(
              color: active ? Colors.blue : Colors.grey,
              borderRadius: BorderRadius.circular(20.r),
            ),
            child: Icon(icon, color: Colors.white, size: 30.sp),
          ),
          SizedBox(height: 5.h),
          Text(
            label,
            style: TextStyle(color: Colors.white70, fontSize: 14.sp),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120.w,
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.15)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          buildButton(Icons.music_note, "Music"),
          buildButton(Icons.phone, "Phone"),
          buildButton(Icons.home, "Home", active: true),
          buildButton(Icons.menu, "Menu"),
          buildButton(Icons.settings, "Settings"),
        ],
      ),
    );
  }
}
