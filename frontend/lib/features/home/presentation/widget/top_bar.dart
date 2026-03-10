import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
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

        /// LEFT PROFILE
        Row(
          children: [
            CircleAvatar(radius: 25.r),
            SizedBox(width: 15.w),

            Text(
              "Hello, User",
              style: TextStyle(
                color: Colors.white,
                fontSize: 22.sp,
              ),
            ),
          ],
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
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16.sp,
              ),
            ),
          ],
        )
      ],
    );
  }
}