import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class MultimediaThemeSection extends StatelessWidget {
  final int selectedTheme;
  final Function(int) onThemeChanged;
  final List<List<Color>> themes;

  const MultimediaThemeSection({
    super.key,
    required this.selectedTheme,
    required this.onThemeChanged,
    required this.themes,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFA7A7A7), Color(0xFF747474)],
          stops: [0.0, 0.50],
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Multimedia Theme Settings",
            style: TextStyle(fontSize: 20.sp, color: Colors.white),
          ),

          SizedBox(height: 10.h),

          CarouselSlider.builder(
            itemCount: themes.length,
            options: CarouselOptions(
              height: 140.h,
              enlargeCenterPage: true,
              viewportFraction: 0.38,
              enableInfiniteScroll: false,
              onPageChanged: (index, reason) {
                onThemeChanged(index);
              },
            ),
            itemBuilder: (context, index, realIndex) {
              bool selected = selectedTheme == index;

              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: EdgeInsets.symmetric(vertical: 8.h),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(25.r),
                  gradient: LinearGradient(colors: themes[index]),
                  border: Border.all(
                    color: selected ? Colors.white : Colors.transparent,
                    width: 3,
                  ),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: Colors.white.withOpacity(0.35),
                            blurRadius: 20,
                          ),
                        ]
                      : [],
                ),
                child: Stack(
                  children: [
                    /// CHECK ICON
                    if (selected)
                      Positioned(
                        top: 10.h,
                        right: 10.w,
                        child: Container(
                          padding: EdgeInsets.all(6.r),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.check,
                            size: 16.sp,
                            color: Colors.black,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),

          SizedBox(height: 10.h),

          Center(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 40.w, vertical: 10.h),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25.r),
              ),
              child: Text(
                "Custom Theme",
                style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
