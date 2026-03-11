import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:frontend/features/personalize/presentation/page/personalize_page.dart';
import 'package:intl/intl.dart';

class TopBar extends StatefulWidget {
  const TopBar({super.key});

  @override
  State<TopBar> createState() => _TopBarState();
}

class _TopBarState extends State<TopBar> {
  late Timer _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _now = DateTime.now();
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final time = DateFormat("HH:mm").format(_now);
    final date = DateFormat("EEEE, d MMMM yyyy").format(_now);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        /// PROFILE BUTTON
        InkWell(
          borderRadius: BorderRadius.circular(40.r),
          onTap: () {
            Navigator.of(context).push(
              PageRouteBuilder(
                opaque: false,
                transitionDuration: const Duration(milliseconds: 450),
                pageBuilder: (context, animation, secondaryAnimation) {
                  return const PersonalizePage();
                },
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) {
                      final fade = Tween(
                        begin: 0.0,
                        end: 1.0,
                      ).animate(animation);

                      final scale = Tween(begin: 0.95, end: 1.0).animate(
                        CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOutCubic,
                        ),
                      );

                      return FadeTransition(
                        opacity: fade,
                        child: ScaleTransition(scale: scale, child: child),
                      );
                    },
              ),
            );
          },
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(40.r),
            ),
            child: Row(
              children: [
                /// AVATAR
                CircleAvatar(
                  radius: 22.r,
                  backgroundColor: Colors.grey.shade700,
                  child: Icon(Icons.person, color: Colors.white, size: 22.sp),
                ),

                SizedBox(width: 12.w),

                /// TEXT
                Text(
                  "Hello, User",
                  style: TextStyle(color: Colors.white, fontSize: 22.sp),
                ),
              ],
            ),
          ),
        ),

        /// TIME + DATE
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              time,
              style: TextStyle(
                color: Colors.white,
                fontSize: 22.sp,
                fontWeight: FontWeight.bold,
              ),
            ),

            Text(
              date,
              style: TextStyle(color: Colors.white70, fontSize: 16.sp),
            ),
          ],
        ),
      ],
    );
  }
}
