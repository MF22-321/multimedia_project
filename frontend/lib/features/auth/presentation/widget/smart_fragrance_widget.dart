import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class SmartFragranceSection extends StatelessWidget {
  final int selectedCartridge;
  final Function(int) onSelect;

  const SmartFragranceSection({
    super.key,
    required this.selectedCartridge,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 30.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFA7A7A7), Color(0xFF747474)],
          stops: [0.0, 0.96],
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                "Smart Fragrance Control",
                style: TextStyle(fontSize: 20.sp, color: Colors.white),
              ),

              const Spacer(),

              Text(
                "Select\nCartridge",
                style: TextStyle(fontSize: 12.sp, color: Colors.white),
              ),

              SizedBox(width: 20.w),

              _cartridgeButton("1", 1),
              SizedBox(width: 10.w),
              _cartridgeButton("2", 2),
            ],
          ),

          SizedBox(height: 12.h),

          Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 30.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.7),
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: Text(
                "Custom Settings",
                style: TextStyle(fontSize: 14.sp, color: Colors.black),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cartridgeButton(String text, int value) {
    final bool selected = selectedCartridge == value;

    return GestureDetector(
      onTap: () => onSelect(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 60.w,
        height: 60.w,
        decoration: BoxDecoration(
          color: selected ? Colors.grey.shade300 : Colors.transparent,
          borderRadius: BorderRadius.circular(15.r),
          border: Border.all(
            color: selected ? Colors.white : Colors.grey,
            width: 4,
          ),
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold, color: selected ? Colors.black : Colors.white  ),
          ),
        ),
      ),
    );
  }
}
