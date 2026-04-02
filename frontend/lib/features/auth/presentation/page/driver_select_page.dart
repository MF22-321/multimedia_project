import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:frontend/features/auth/presentation/widget/driver_avatar_card.dart';
import 'package:frontend/features/auth/presentation/widget/guest_button.dart';
import '../../../boot/presentation/widget/dotted_background.dart';


class DriverSelectPage extends StatelessWidget {
  const DriverSelectPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [

          /// Background
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  Color(0xFF111111),
                  Colors.black,
                ],
                radius: 0.9,
              ),
            ),
          ),

          const Positioned.fill(
            child: DottedBackground(),
          ),

          /// Content
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [

                Text(
                  "Siapa yang mengemudi hari ini?",
                  style: TextStyle(
                    fontSize: 40.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),

                SizedBox(height: 60.h),

                /// Driver Options
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [

                    DriverAvatarCard(
                      name: "Raihan",
                      onTap: () {
                        Navigator.pushReplacementNamed(context, "/home");
                      },
                    ),

                    SizedBox(width: 60.w),

                    DriverAvatarCard(
                      name: "Febrian",
                      onTap: () {
                        Navigator.pushReplacementNamed(context, "/home");
                      },
                    ),

                    SizedBox(width: 60.w),

                    DriverAvatarCard(
                      name: "Tambah Akun",
                      isAddButton: true,
                      onTap: () {
                        // nanti bisa ke halaman register
                        Navigator.pushNamed(context, "/add-driver");
                      },
                    ),
                  ],
                ),

                SizedBox(height: 80.h),

                GuestButton(
                  onTap: () {
                    Navigator.pushReplacementNamed(context, "/home");
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}