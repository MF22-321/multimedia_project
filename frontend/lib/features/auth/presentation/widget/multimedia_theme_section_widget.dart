import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:frontend/core/localization/app_strings.dart';
import 'package:frontend/core/themes/car_theme.dart';
import 'package:frontend/features/personalize/presentation/page/custom_theme_page.dart';

class MultimediaThemeSection extends StatelessWidget {
  final int selectedTheme;
  final Function(int) onThemeChanged;
  final List<String> themeImages;

  const MultimediaThemeSection({
    super.key,
    required this.selectedTheme,
    required this.onThemeChanged,
    required this.themeImages,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: CarThemes.currentTheme,
      builder: (context, themeType, _) {
        final theme = CarThemes.getTheme(themeType);

        return AnimatedContainer(
          duration: const Duration(milliseconds: 400),

          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),

          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: theme.backgroundGradient,
              begin: Alignment.centerRight,
              end: Alignment.centerLeft,
            ),
          ),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// TITLE
              Text(
                AppStrings.multimediaThemeSettings,
                style: TextStyle(
                  fontSize: 20.sp,
                  color: theme.textColor,
                  fontWeight: FontWeight.w600,
                ),
              ),

              SizedBox(height: 15.h),

              /// CAROUSEL
              CarouselSlider.builder(
                itemCount: themeImages.length,
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
                  final bool selected = selectedTheme == index;

                  return GestureDetector(
                    onTap: () => onThemeChanged(index),

                    child: AnimatedScale(
                      scale: selected ? 1.05 : 1.0,
                      duration: const Duration(milliseconds: 200),

                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: EdgeInsets.symmetric(vertical: 8.h),

                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20.r),

                          border: Border.all(
                            color: selected
                                ? theme.accentColor
                                : Colors.transparent,
                            width: 3,
                          ),

                          boxShadow: selected
                              ? [
                                  BoxShadow(
                                    color: theme.accentColor.withValues(
                                      alpha: 0.5,
                                    ),
                                    blurRadius: 20,
                                  ),
                                ]
                              : [],
                        ),

                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18.r),

                          child: Stack(
                            children: [
                              /// IMAGE
                              Positioned.fill(
                                child: Image.asset(
                                  themeImages[index],
                                  fit: BoxFit.cover,
                                ),
                              ),

                              /// CHECK ICON
                              if (selected)
                                Positioned(
                                  top: 10.h,
                                  right: 10.w,
                                  child: Container(
                                    padding: EdgeInsets.all(6.r),
                                    decoration: BoxDecoration(
                                      color: theme.accentColor,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.check,
                                      size: 16.sp,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),

              SizedBox(height: 15.h),

              /// CUSTOM THEME BUTTON
              Center(
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CustomThemePage(),
                      ),
                    );
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 40.w,
                      vertical: 10.h,
                    ),
                    decoration: BoxDecoration(
                      color: theme.buttonColor,
                      borderRadius: BorderRadius.circular(25.r),
                    ),
                    child: Text(
                      AppStrings.customTheme,
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                        color:
                            themeType == CarThemeType.comfort ||
                                themeType == CarThemeType.futuristic
                            ? Colors.black
                            : Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
