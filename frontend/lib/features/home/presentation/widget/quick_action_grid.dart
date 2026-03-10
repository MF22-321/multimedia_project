import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class QuickActionGrid extends StatelessWidget {
  const QuickActionGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final actions = [
      _ActionItem("M-Toyota", Icons.car_rental),
      _ActionItem("Music", Icons.play_circle_fill),
      _ActionItem("Radio", Icons.radio),
      _ActionItem("Bluetooth", Icons.bluetooth),
      _ActionItem("Car Status", Icons.directions_car),
      _ActionItem("Screen Cast", Icons.cast),
      _ActionItem("USB", Icons.usb),
      _ActionItem("Info", Icons.info),
    ];

    return Expanded(
      child: GridView.builder(
        itemCount: actions.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisSpacing: 20.h,
          crossAxisSpacing: 20.w,
          childAspectRatio: 1,
        ),
        itemBuilder: (context, index) {
          final item = actions[index];

          return GestureDetector(
            onTap: () {},
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22.r),
                gradient: LinearGradient(
                  colors: [
                    Colors.grey.shade200,
                    Colors.grey.shade400,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  )
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [

                  Icon(
                    item.icon,
                    size: 40.sp,
                    color: Colors.black,
                  ),

                  SizedBox(height: 8.h),

                  Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ActionItem {
  final String label;
  final IconData icon;

  _ActionItem(this.label, this.icon);
}