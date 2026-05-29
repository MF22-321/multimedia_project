import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:frontend/core/model/auto_interval_option.dart';

class MainControlPanel extends StatelessWidget {
  final bool isPowerOn;
  final bool isAutoMode;
  final AutoIntervalOption selectedAutoInterval;
  final VoidCallback onTogglePower;
  final VoidCallback onToggleAuto;
  final ValueChanged<AutoIntervalOption> onSelectAutoInterval;
  final VoidCallback onSave;
  final Color accentColor;
  final Color textColor;
  final Color panelColor;
  final Color surfaceColor;
  final Color surfaceTextColor;

  const MainControlPanel({
    super.key,
    required this.isPowerOn,
    required this.isAutoMode,
    required this.selectedAutoInterval,
    required this.onTogglePower,
    required this.onToggleAuto,
    required this.onSelectAutoInterval,
    required this.onSave,
    required this.accentColor,
    required this.textColor,
    required this.panelColor,
    required this.surfaceColor,
    required this.surfaceTextColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 320.w,
          padding: EdgeInsets.symmetric(horizontal: 22.w, vertical: 22.h),
          decoration: BoxDecoration(
            color: panelColor,
            border: Border.all(
              color: accentColor.withValues(alpha: 0.42),
              width: 2.w,
            ),
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
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(42.r),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.power_settings_new,
                      size: 72.sp,
                      color: isPowerOn ? accentColor : surfaceTextColor,
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
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(42.r),
                    border: Border.all(
                      color: isAutoMode ? accentColor : Colors.transparent,
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
                            ? surfaceTextColor
                            : surfaceTextColor.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 22.h),
              _AutoIntervalSegment(
                selected: selectedAutoInterval,
                onSelected: onSelectAutoInterval,
                accentColor: accentColor,
                surfaceColor: surfaceColor,
                surfaceTextColor: surfaceTextColor,
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
              backgroundColor: panelColor,
              foregroundColor: textColor,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28.r),
                side: BorderSide(
                  color: accentColor.withValues(alpha: 0.42),
                  width: 1.w,
                ),
              ),
            ),
            child: Text(
              'Save',
              style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.w500),
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
  final Color accentColor;
  final Color surfaceColor;
  final Color surfaceTextColor;

  const _AutoIntervalSegment({
    required this.selected,
    required this.onSelected,
    required this.accentColor,
    required this.surfaceColor,
    required this.surfaceTextColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60.h,
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(30.r),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.28),
          width: 1.w,
        ),
      ),
      child: Row(
        children: [
          _SegmentItem(
            label: '10s',
            isSelected: selected == AutoIntervalOption.s10,
            onTap: () => onSelected(AutoIntervalOption.s10),
            accentColor: accentColor,
            surfaceTextColor: surfaceTextColor,
          ),
          _SegmentItem(
            label: '1m',
            isSelected: selected == AutoIntervalOption.m1,
            onTap: () => onSelected(AutoIntervalOption.m1),
            accentColor: accentColor,
            surfaceTextColor: surfaceTextColor,
          ),
          _SegmentItem(
            label: '5m',
            isSelected: selected == AutoIntervalOption.m5,
            onTap: () => onSelected(AutoIntervalOption.m5),
            accentColor: accentColor,
            surfaceTextColor: surfaceTextColor,
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
  final Color accentColor;
  final Color surfaceTextColor;

  const _SegmentItem({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.accentColor,
    required this.surfaceTextColor,
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
            color: isSelected ? accentColor : Colors.transparent,
            borderRadius: BorderRadius.circular(24.r),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? ThemeData.estimateBrightnessForColor(accentColor) ==
                              Brightness.dark
                          ? Colors.white
                          : Colors.black
                    : surfaceTextColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
