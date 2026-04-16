import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:frontend/core/themes/car_theme.dart';

class DrowsinessAlertPage extends StatelessWidget {
  final VoidCallback onYes;
  final VoidCallback onNo;
  final VoidCallback onDisable;

  const DrowsinessAlertPage({
    super.key,
    required this.onYes,
    required this.onNo,
    required this.onDisable,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withOpacity(0.7),

      body: ValueListenableBuilder(
        valueListenable: CarThemes.currentTheme,
        builder: (context, themeType, _) {
          final theme = CarThemes.getTheme(themeType);

          return Stack(
            children: [
              /// 🔥 BACKGROUND BLUR / DIM
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.6),
                ),
              ),

              /// 🔥 CARD CENTER
              Center(
                child: Container(
                  width: 900.w,
                  padding: EdgeInsets.all(30.w),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30.r),
                    gradient: LinearGradient(
                      colors: theme.backgroundGradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: theme.accentColor.withOpacity(0.4),
                        blurRadius: 30,
                      )
                    ],
                  ),

                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      /// 🔥 TITLE
                      Text(
                        "Hati-hati Anda sedang mengantuk!",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 28.sp,
                          fontWeight: FontWeight.bold,
                          color: theme.textColor,
                        ),
                      ),

                      SizedBox(height: 20.h),

                      /// 🔥 ICON
                      Icon(
                        Icons.airline_seat_recline_normal,
                        size: 120.sp,
                        color: theme.accentColor,
                      ),

                      SizedBox(height: 20.h),

                      /// 🔥 QUESTION
                      Text(
                        "Mau mengaktifkan Smart Fragrance\nuntuk mengurangi kantuk Anda?",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18.sp,
                          color: Colors.white70,
                        ),
                      ),

                      SizedBox(height: 30.h),

                      /// 🔥 BUTTONS
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          /// YES
                          GestureDetector(
                            onTap: onYes,
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 40.w, vertical: 16.h),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(30.r),
                              ),
                              child: Text(
                                "YA",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),

                          SizedBox(width: 20.w),

                          /// NO
                          GestureDetector(
                            onTap: onNo,
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 40.w, vertical: 16.h),
                              decoration: BoxDecoration(
                                color: Colors.grey,
                                borderRadius: BorderRadius.circular(30.r),
                              ),
                              child: Text(
                                "TIDAK",
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 18.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),

                          SizedBox(width: 20.w),

                          /// DISABLE
                          GestureDetector(
                            onTap: onDisable,
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 20.w, vertical: 16.h),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.white54),
                                borderRadius: BorderRadius.circular(30.r),
                              ),
                              child: Text(
                                "Nonaktifkan\nDrowsiness Detection",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12.sp,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}