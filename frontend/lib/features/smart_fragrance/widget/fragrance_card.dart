import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class FragranceCard extends StatelessWidget {
  final String title;
  final String slotNumber;
  final IconData icon;
  final int levelPercent;
  final int fillPercent;
  final bool isEnabled;
  final VoidCallback onToggle;
  final Color accentColor;
  final Color textColor;
  final Color panelColor;
  final Color panelDarkColor;

  const FragranceCard({
    super.key,
    required this.title,
    this.slotNumber = '',
    required this.icon,
    required this.levelPercent,
    required this.fillPercent,
    required this.isEnabled,
    required this.onToggle,
    required this.accentColor,
    required this.textColor,
    required this.panelColor,
    required this.panelDarkColor,
  });

  @override
  Widget build(BuildContext context) {
    final int safeLevel = levelPercent.clamp(0, 100);

    return Container(
      width: 340.w,
      height: 370.h,
      decoration: BoxDecoration(
        color: panelColor,
        borderRadius: BorderRadius.circular(40.r),
        border: Border.all(color: accentColor.withValues(alpha: 0.28)),
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
                  color: panelDarkColor,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(54.r),
                    topRight: Radius.circular(40.r),
                    bottomRight: Radius.circular(40.r),
                    bottomLeft: Radius.zero,
                  ),
                ),
              ),
            ),

            // Watermark nomor slot di pojok kanan atas
            if (slotNumber.isNotEmpty)
              Positioned(
                right: 16.w,
                top: 10.h,
                child: Text(
                  slotNumber,
                  style: TextStyle(
                    fontSize: 64.sp,
                    fontWeight: FontWeight.w900,
                    color: accentColor.withValues(alpha: 0.08),
                    height: 1,
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Icon(
                          Icons.water_drop_outlined,
                          size: 28.sp,
                          color: textColor.withValues(alpha: 0.9),
                        ),
                        if (slotNumber.isNotEmpty)
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8.w,
                              vertical: 3.h,
                            ),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8.r),
                              border: Border.all(
                                color: accentColor.withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              'SLOT $slotNumber',
                              style: TextStyle(
                                fontSize: 10.sp,
                                fontWeight: FontWeight.w800,
                                color: accentColor,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const Spacer(),
                    Container(
                      width: 80.w,
                      height: 80.w,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: accentColor.withValues(
                          alpha: isEnabled ? 0.18 : 0.07,
                        ),
                        border: Border.all(
                          color: accentColor.withValues(
                            alpha: isEnabled ? 0.45 : 0.15,
                          ),
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        icon,
                        size: 40.sp,
                        color: accentColor.withValues(
                          alpha: isEnabled ? 1.0 : 0.4,
                        ),
                      ),
                    ),
                    SizedBox(height: 14.h),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 22.sp,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      isEnabled ? 'ACTIVE' : 'STANDBY',
                      style: TextStyle(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w600,
                        color: isEnabled
                            ? accentColor
                            : textColor.withValues(alpha: 0.35),
                        letterSpacing: 1.5,
                      ),
                    ),
                    SizedBox(height: 18.h),
                    Transform.scale(
                      scale: 1.18,
                      child: Switch(
                        value: isEnabled,
                        onChanged: (_) => onToggle(),
                        activeThumbColor: Colors.white,
                        activeTrackColor: accentColor,
                        inactiveThumbColor: Colors.white,
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
