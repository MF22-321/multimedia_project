import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:frontend/features/auth/presentation/widget/profile_setting_panel.dart';
import 'package:frontend/features/auth/presentation/widget/scan_face_button.dart';

class AddDriverPage extends StatelessWidget {
  const AddDriverPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          /// Grey Background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF737373),
                  Color(0xFFBABABA),
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
          ),

          Row(
            children: [
              /// LEFT PANEL (FORM)
              Expanded(
                flex: 1,
                child: Padding(
                  padding: EdgeInsets.all(30.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Profile\nAdd New Driver",
                        style: TextStyle(
                          fontSize: 28.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Divider(
                        color: Colors.white,
                        thickness: 2.h,
                        height: 40.h,
                      ),

                      SizedBox(height: 60.h),

                      Text("Name", style: TextStyle(fontSize: 20.sp, color: Colors.white)),

                      SizedBox(height: 20.h),

                      Container(
                        height: 60.h,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20.r),
                        ),
                      ),

                      SizedBox(height: 60.h),

                      Center(child: const ScanFaceButton()),
                    ],
                  ),
                ),
              ),

              /// RIGHT PANEL (SETTINGS)
              const Expanded(flex: 1, child: ProfileSettingsPanel()),
            ],
          ),
        ],
      ),
    );
  }
}
