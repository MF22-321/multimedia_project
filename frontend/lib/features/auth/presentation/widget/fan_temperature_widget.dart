import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class FanTemperatureSection extends StatelessWidget {
  final int fanLevel;
  final int temperature;
  final VoidCallback onFanPlus;
  final VoidCallback onFanMinus;
  final VoidCallback onTempPlus;
  final VoidCallback onTempMinus;

  const FanTemperatureSection({
    super.key,
    required this.fanLevel,
    required this.temperature,
    required this.onFanPlus,
    required this.onFanMinus,
    required this.onTempPlus,
    required this.onTempMinus,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 30.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFA7A7A7), Color(0xFF747474)],
          stops: [0.0, 0.70],
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Fan & Temperature Control",
            style: TextStyle(fontSize: 20.sp, color: Colors.white),
          ),

          SizedBox(height: 20.h),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              /// FAN
              Row(
                children: [
                  Image.asset(
                    "assets/images/fan.png",
                    width: 50.w,
                    color: Colors.white,
                  ),

                  SizedBox(width: 20.w),

                  Row(
                    children: List.generate(5, (index) {
                      final active = index < fanLevel;

                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: EdgeInsets.symmetric(horizontal: 4.w),
                        width: 12.w,
                        height: (20 + (index * 10)).h,
                        decoration: BoxDecoration(
                          color: active ? Colors.blue : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(5.r),
                        ),
                      );
                    }),
                  ),

                  Column(
                    children: [
                      IconButton(
                        onPressed: onFanPlus,
                        icon: Icon(Icons.add, size: 30.sp, color: Colors.white),
                      ),
                      IconButton(
                        onPressed: onFanMinus,
                        icon: Icon(
                          Icons.remove,
                          size: 30.sp,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              /// TEMPERATURE
              Row(
                children: [
                  Image.asset(
                    "assets/images/ac.png",
                    width: 50.w,
                    color: Colors.white,
                  ),

                  SizedBox(width: 10.w),

                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 20.w,
                      vertical: 10.h,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade200,
                      borderRadius: BorderRadius.circular(15.r),
                    ),
                    child: Text(
                      "$temperature°",
                      style: TextStyle(
                        fontSize: 22.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  Column(
                    children: [
                      IconButton(
                        onPressed: onTempPlus,
                        icon: Icon(Icons.add, size: 30.sp, color: Colors.white),
                      ),
                      IconButton(
                        onPressed: onTempMinus,
                        icon: Icon(
                          Icons.remove,
                          size: 30.sp,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
