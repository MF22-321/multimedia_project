import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:frontend/core/themes/app_colors.dart';

class FragranceCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final int levelPercent;
  final int fillPercent;
  final bool isEnabled;
  final VoidCallback onToggle;

  const FragranceCard({
    super.key,
    required this.title,
    required this.icon,
    required this.levelPercent,
    required this.fillPercent,
    required this.isEnabled,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final int safeLevel = levelPercent.clamp(0, 100);

    return Container(
      width: 340.w,
      height: 370.h,
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(40.r),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(40.r),
        child: Stack(
          children: [
            Positioned(
              left: 10.w,
              top: 18.h,
              bottom: 18.h,
              child: _LeftLevelIndicator(levelPercent: safeLevel),
            ),

            Positioned(
              left: 84.w,
              top: 0,
              right: 0,
              bottom: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.panelDark,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(54.r),
                    topRight: Radius.circular(40.r),
                    bottomRight: Radius.circular(40.r),
                    bottomLeft: Radius.zero,
                  ),
                ),
              ),
            ),

            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 106.w,
                  right: 24.w,
                  top: 22.h,
                  bottom: 18.h,
                ),
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.topLeft,
                      child: Icon(
                        Icons.water_drop_outlined,
                        size: 28.sp,
                        color: Colors.white.withValues(alpha: 0.95),
                      ),
                    ),
                    const Spacer(),
                    Icon(icon, size: 62.sp, color: const Color(0xFFC28A63)),
                    SizedBox(height: 18.h),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textLight,
                        fontSize: 30.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 34.h),
                    Transform.scale(
                      scale: 1.18,
                      child: Switch(
                        value: isEnabled,
                        onChanged: (_) => onToggle(),
                        activeThumbColor: AppColors.whiteSoft,
                        activeTrackColor: AppColors.green,
                        inactiveThumbColor: AppColors.whiteSoft,
                        inactiveTrackColor: Colors.white24,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    SizedBox(height: 8.h),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LeftLevelIndicator extends StatelessWidget {
  final int levelPercent;

  const _LeftLevelIndicator({required this.levelPercent});

  @override
  Widget build(BuildContext context) {
    final double level = levelPercent.clamp(0, 100) / 100.0;

    return SizedBox(
      width: 66.w,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double railTop = 54.h;
          final double railBottom = 54.h;

          final double railHeight =
              constraints.maxHeight - railTop - railBottom;

          final double bubbleTop =
              railTop +
              ((railHeight - 64.h) * (1 - level)).clamp(0.0, railHeight - 64.h);

          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 25.w,
                top: 0,
                child: Text(
                  'F',
                  style: TextStyle(
                    fontSize: 28.sp,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF403B3B),
                  ),
                ),
              ),

              Positioned(
                left: 27.w,
                top: railTop,
                bottom: railBottom,
                child: Container(
                  width: 10.w,
                  decoration: BoxDecoration(
                    color: const Color(0xFF403B3B),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
              ),

              Positioned(
                left: 0,
                top: bubbleTop,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeInOut,
                  width: 64.w,
                  height: 64.w,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF403B3B),
                      width: 2.w,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 6.r,
                        offset: Offset(0, 2.h),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      '$levelPercent%',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF403B3B),
                      ),
                    ),
                  ),
                ),
              ),

              Positioned(
                left: 25.w,
                bottom: 0,
                child: Text(
                  'E',
                  style: TextStyle(
                    fontSize: 28.sp,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF403B3B),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
