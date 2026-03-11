import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:frontend/core/themes/car_theme.dart';

class MediaCard extends StatefulWidget {
  const MediaCard({super.key});

  @override
  State<MediaCard> createState() => _MediaCardState();
}

class _MediaCardState extends State<MediaCard> {

  bool isPlaying = true;

  @override
  Widget build(BuildContext context) {

    return ValueListenableBuilder(
      valueListenable: CarThemes.currentTheme,
      builder: (context, themeType, _) {

       final theme = CarThemes.getTheme(themeType);

        /// Play button color khusus comfort
        final Color playButtonColor =
            themeType == CarThemeType.comfort
                ? Colors.grey.shade600
                : theme.buttonColor;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          height: 130.h,
          padding: EdgeInsets.symmetric(horizontal: 20.w),

          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(25.r),

            gradient: LinearGradient(
              colors: [
                theme.backgroundGradient.last.withOpacity(0.9),
                Colors.black.withOpacity(0.6),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),

            border: Border.all(
              color: theme.accentColor.withOpacity(0.4),
              width: 2,
            ),

            boxShadow: [
              BoxShadow(
                color: theme.accentColor.withOpacity(0.25),
                blurRadius: 20,
                offset: const Offset(0, 10),
              )
            ],
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

              /// SONG INFO + PROGRESS
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    /// SONG TITLE
                    Text(
                      "Blinding Lights",
                      style: TextStyle(
                        color: theme.textColor,
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    SizedBox(height: 4.h),

                    /// ARTIST
                    Text(
                      "The Weeknd",
                      style: TextStyle(
                        color: theme.textColor.withOpacity(0.7),
                        fontSize: 14.sp,
                      ),
                    ),

                    SizedBox(height: 12.h),

                    /// PROGRESS BAR
                    Container(
                      height: 4.h,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10.r),
                      ),

                      child: FractionallySizedBox(
                        widthFactor: 0.4,
                        child: Container(
                          decoration: BoxDecoration(
                            color: theme.accentColor,
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              /// CONTROLS
              Row(
                children: [

                  Icon(
                    Icons.skip_previous,
                    color: theme.textColor,
                    size: 30.sp,
                  ),

                  SizedBox(width: 10.w),

                  /// PLAY BUTTON
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        isPlaying = !isPlaying;
                      });
                    },

                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: 50.w,
                      height: 50.w,

                      decoration: BoxDecoration(
                        color: playButtonColor,
                        shape: BoxShape.circle,

                        boxShadow: [
                          BoxShadow(
                            color: playButtonColor.withOpacity(0.4),
                            blurRadius: 12,
                          )
                        ],
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

                  Icon(
                    Icons.skip_next,
                    color: theme.textColor,
                    size: 30.sp,
                  ),
                ],
              )
            ],
          ),
        );
      },
    );
  }
}