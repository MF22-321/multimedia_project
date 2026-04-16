import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:frontend/core/model/auto_interval_option.dart';
import 'package:frontend/core/themes/app_colors.dart';

class MainControlPanel extends StatelessWidget {
  final bool isPowerOn;
  final bool isAutoMode;
  final AutoIntervalOption selectedAutoInterval;
  final VoidCallback onTogglePower;
  final VoidCallback onToggleAuto;
  final ValueChanged<AutoIntervalOption> onSelectAutoInterval;
  final VoidCallback onSave;

  const MainControlPanel({
    super.key,
    required this.isPowerOn,
    required this.isAutoMode,
    required this.selectedAutoInterval,
    required this.onTogglePower,
    required this.onToggleAuto,
    required this.onSelectAutoInterval,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 320.w,
          padding: EdgeInsets.symmetric(horizontal: 22.w, vertical: 22.h),
          decoration: BoxDecoration(
            color: AppColors.panel,
            border: Border.all(color: AppColors.border, width: 2.w),
            borderRadius: BorderRadius.circular(28.r),
          ),
          child: Column(
            children: [
              GestureDetector(
                onTap: onTogglePower,
                child: Container(
                  width: double.infinity,
                  height: 120.h,
                  decoration: BoxDecoration(
                    color: AppColors.whiteSoft,
                    borderRadius: BorderRadius.circular(42.r),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.power_settings_new,
                      size: 72.sp,
                      color: isPowerOn ? AppColors.green : Colors.black,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 22.h),
              GestureDetector(
                onTap: onToggleAuto,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: double.infinity,
                  height: 120.h,
                  decoration: BoxDecoration(
                    color: AppColors.whiteSoft,
                    borderRadius: BorderRadius.circular(42.r),
                    border: Border.all(
                      color: isAutoMode
                          ? const Color(0xFF1E73F1)
                          : Colors.transparent,
                      width: 2.w,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      'Auto',
                      style: TextStyle(
                        fontSize: 30.sp,
                        fontWeight: FontWeight.w700,
                        color: isAutoMode
                            ? AppColors.textDark
                            : AppColors.textDark.withOpacity(0.8),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 22.h),
              _AutoIntervalSegment(
                selected: selectedAutoInterval,
                onSelected: onSelectAutoInterval,
              ),
            ],
          ),
        ),
        SizedBox(height: 18.h),
        SizedBox(
          width: 320.w,
          height: 56.h,
          child: ElevatedButton(
            onPressed: onSave,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.panel,
              foregroundColor: AppColors.textDark,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28.r),
                side: BorderSide(color: const Color(0xFFB0B0B0), width: 1.w),
              ),
            ),
            child: Text(
              'Save',
              style: TextStyle(
                fontSize: 22.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AutoIntervalSegment extends StatelessWidget {
  final AutoIntervalOption selected;
  final ValueChanged<AutoIntervalOption> onSelected;

  const _AutoIntervalSegment({
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60.h,
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: AppColors.whiteSoft,
        borderRadius: BorderRadius.circular(30.r),
        border: Border.all(color: const Color(0xFFBDBDBD), width: 1.w),
      ),
      child: Row(
        children: [
          _SegmentItem(
            label: '10s',
            isSelected: selected == AutoIntervalOption.s10,
            onTap: () => onSelected(AutoIntervalOption.s10),
          ),
          _SegmentItem(
            label: '1m',
            isSelected: selected == AutoIntervalOption.m1,
            onTap: () => onSelected(AutoIntervalOption.m1),
          ),
          _SegmentItem(
            label: '5m',
            isSelected: selected == AutoIntervalOption.m5,
            onTap: () => onSelected(AutoIntervalOption.m5),
          ),
        ],
      ),
    );
  }
}

class _SegmentItem extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SegmentItem({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeInOut,
          margin: EdgeInsets.symmetric(horizontal: 2.w),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF1E73F1) : Colors.transparent,
            borderRadius: BorderRadius.circular(24.r),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.textDark,
              ),
            ),
          ),
        ),
      ),
    );
  }
}