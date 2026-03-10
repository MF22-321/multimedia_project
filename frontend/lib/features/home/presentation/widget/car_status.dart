import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class CarStatusCard extends StatelessWidget {
  const CarStatusCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 287.h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30.r),
        gradient: LinearGradient(
          colors: [
            Colors.grey.shade300,
            Colors.grey.shade500,
            Colors.black,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Stack(
        children: [

          /// CAR IMAGE
          Padding(
            padding: const EdgeInsets.only(bottom: 60).r,
            child: Center(
              child: Image.asset(
                "assets/images/yaris_cross.png",
                width: 450.w,
                fit: BoxFit.contain,
              ),
            ),
          ),

          /// BOTTOM MENU
          Positioned(
            bottom: 15.h,
            left: 20.w,
            right: 20.w,
            child: Container(
              height: 40.h,
              padding: EdgeInsets.symmetric(horizontal: 10.w),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(30.r),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [

                  /// ECO
                  _iconButton(
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10.w,
                        vertical: 4.h,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(6.r),
                      ),
                      child: const Text(
                        "eco",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  /// RACE / PERFORMANCE
                  _iconButton(
                    child: Icon(
                      Icons.flag,
                      size: 26.sp,
                      color: Colors.black,
                    ),
                  ),

                  /// CAR INFO
                  _iconButton(
                    child: Icon(
                      Icons.directions_car,
                      size: 28.sp,
                      color: Colors.black,
                    ),
                  ),

                  /// DRIVER PROFILE (ACTIVE)
                  Container(
                    width: 50.w,
                    height: 50.w,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.blue,
                    ),
                    child: Icon(
                      Icons.person,
                      color: Colors.white,
                      size: 28.sp,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconButton({required Widget child}) {
    return Container(
      width: 45.w,
      height: 45.w,
      alignment: Alignment.center,
      child: child,
    );
  }
}