import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:frontend/features/warning/presentation/widget/warning_button.dart';
import '../../../boot/presentation/widget/dotted_background.dart';

class WarningPage extends StatelessWidget {
  const WarningPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          /// Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                colors: [Color(0xFF111111), Colors.black],
                radius: 0.9,
                center: Alignment.center,
              ),
            ),
          ),

          /// Dotted Pattern
          const Positioned.fill(child: DottedBackground()),

          /// Content
          Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 200.w),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  /// Title
                  Text(
                    "PERINGATAN",
                    style: TextStyle(
                      fontSize: 60.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 4.w,
                    ),
                  ),

                  SizedBox(height: 40.h),

                  /// Body Text
                  Text(
                    "Berkendaralah dengan aman dan patuhi peraturan lalu lintas.\n"
                    "Melihat layar ini dan melakukan pengaturan saat kendaraan sedang\n"
                    "berjalan dapat menyebabkan kecelakaan serius. Sebagian data peta\n"
                    "atau informasi batas kecepatan mungkin tidak akurat. Silakan baca\n"
                    "petunjuk keselamatan pada Buku Panduan Pemilik kendaraan Anda.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22.sp,
                      color: Colors.white70,
                      height: 1.6,
                    ),
                  ),

                  SizedBox(height: 60.h),

                  /// Button
                  WarningButton(
                    onPressed: () {
                      Navigator.pushReplacementNamed(context, "/odd-even");
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
