import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class MediaCard extends StatefulWidget {
  const MediaCard({super.key});

  @override
  State<MediaCard> createState() => _MediaCardState();
}

class _MediaCardState extends State<MediaCard> {

  bool isPlaying = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 130.h,
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(25.r),
        gradient: LinearGradient(
          colors: [
            Colors.grey.shade900,
            Colors.grey.shade800,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [

          /// ALBUM COVER
          Container(
            width: 90.w,
            height: 90.w,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15.r),
              image: const DecorationImage(
                image: AssetImage("assets/images/weekend.png"),
                fit: BoxFit.cover,
              ),
            ),
          ),

          SizedBox(width: 20.w),

          /// SONG INFO + CONTROLS
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                /// SONG TITLE
                Text(
                  "Blinding Lights",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                SizedBox(height: 4.h),

                /// ARTIST
                Text(
                  "The Weeknd",
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 14.sp,
                  ),
                ),

                SizedBox(height: 12.h),

                /// PROGRESS BAR
                Container(
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade700,
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: FractionallySizedBox(
                    widthFactor: 0.4,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          /// CONTROLS
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [

              Row(
                children: [

                  Icon(Icons.skip_previous,
                      color: Colors.white, size: 30.sp),

                  SizedBox(width: 10.w),

                  GestureDetector(
                    onTap: () {
                      setState(() {
                        isPlaying = !isPlaying;
                      });
                    },
                    child: Container(
                      width: 50.w,
                      height: 50.w,
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isPlaying
                            ? Icons.pause
                            : Icons.play_arrow,
                        color: Colors.white,
                        size: 28.sp,
                      ),
                    ),
                  ),

                  SizedBox(width: 10.w),

                  Icon(Icons.skip_next,
                      color: Colors.white, size: 30.sp),
                ],
              )
            ],
          )
        ],
      ),
    );
  }
}