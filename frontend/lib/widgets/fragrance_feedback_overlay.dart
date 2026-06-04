import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:frontend/core/model/fragrance_feedback.dart';

class FragranceFeedbackOverlay extends StatelessWidget {
  const FragranceFeedbackOverlay({
    super.key,
    required this.feedback,
    required this.visible,
  });

  final FragranceFeedback? feedback;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    final data = feedback;

    return Positioned(
      top: 34.h,
      right: 116.w,
      child: IgnorePointer(
        child: AnimatedOpacity(
          opacity: visible && data != null ? 1 : 0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          child: AnimatedScale(
            scale: visible && data != null ? 1 : 0.94,
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            child: data == null ? const SizedBox.shrink() : _Card(data: data),
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.data});

  final FragranceFeedback data;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 360.w,
      padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 16.h),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24.r),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF07131A).withValues(alpha: 0.88),
            const Color(0xFF02070B).withValues(alpha: 0.76),
          ],
        ),
        border: Border.all(
          color: data.accent.withValues(alpha: 0.34),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: data.accent.withValues(alpha: 0.28),
            blurRadius: 34,
            spreadRadius: -8,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.42),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 54.w,
            height: 54.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: data.accent.withValues(alpha: 0.14),
              border: Border.all(color: data.accent.withValues(alpha: 0.34)),
              boxShadow: [
                BoxShadow(
                  color: data.accent.withValues(alpha: 0.28),
                  blurRadius: 18,
                ),
              ],
            ),
            child: Icon(data.icon, color: data.accent, size: 28.sp),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  data.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
                SizedBox(height: 5.h),
                Text(
                  data.message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.68),
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
