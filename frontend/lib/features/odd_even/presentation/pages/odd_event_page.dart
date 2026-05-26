import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:frontend/core/navigation/app_routes.dart';
import 'package:frontend/features/odd_even/presentation/widget/odd_event_button.dart';
import 'package:frontend/features/odd_even/presentation/widget/odd_event_status.dart';
import '../../../boot/presentation/widget/dotted_background.dart';

class OddEvenPage extends StatelessWidget {
  const OddEvenPage({super.key});

  bool isEvenDay() {
    final today = DateTime.now().day;
    return today % 2 == 0;
  }

  @override
  Widget build(BuildContext context) {
    final bool isEven = isEvenDay();

    return Scaffold(
      body: Stack(
        children: [
          /// Background
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                colors: [Color(0xFF111111), Colors.black],
                radius: 0.9,
              ),
            ),
          ),

          const Positioned.fill(child: DottedBackground()),

          /// Content
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "PENGINGAT GANJIL–GENAP",
                  style: TextStyle(
                    fontSize: 50.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),

                SizedBox(height: 40.h),

                Text(
                  "Hari ini merupakan tanggal",
                  style: TextStyle(fontSize: 28.sp, color: Colors.white70),
                ),

                SizedBox(height: 20.h),

                OddEvenStatus(isEven: isEven),

                SizedBox(height: 20.h),

                Text(
                  "Pastikan kendaraan Anda memenuhi aturan\n"
                  "Ganjil–Genap di wilayah tujuan.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22.sp,
                    color: Colors.white60,
                    height: 1.6,
                  ),
                ),

                SizedBox(height: 60.h),

                OddEvenButton(
                  onPressed: () {
                    Navigator.pushReplacementNamed(
                      context,
                      AppRoutes.driverSelect,
                    );
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
