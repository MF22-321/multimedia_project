import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class SpeedControlCard extends StatelessWidget {
  final int speedLevel;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;
  final Color accentColor;
  final Color textColor;

  const SpeedControlCard({
    super.key,
    required this.speedLevel,
    required this.onIncrease,
    required this.onDecrease,
    required this.accentColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final int clampedLevel = speedLevel.clamp(1, 3);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 220.w,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Icon(Icons.air, size: 42.sp, color: textColor.withValues(alpha: 0.78)),
              SizedBox(width: 18.w),
              _SpeedBars(level: clampedLevel, accentColor: accentColor),
              SizedBox(width: 18.w),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _AnimatedActionButton(
                    icon: Icons.add,
                    enabled: clampedLevel < 3,
                    onTap: onIncrease,
                    accentColor: accentColor,
                    textColor: textColor,
                  ),
                  SizedBox(height: 12.h),
                  _AnimatedActionButton(
                    icon: Icons.remove,
                    enabled: clampedLevel > 1,
                    onTap: onDecrease,
                    accentColor: accentColor,
                    textColor: textColor,
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: 16.h),
        Text(
          'Speed',
          style: TextStyle(
            fontSize: 22.sp,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
      ],
    );
  }
}

class _SpeedBars extends StatelessWidget {
  final int level;
  final Color accentColor;

  const _SpeedBars({required this.level, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _SpeedBar(height: 48.h, isActive: level >= 1, accentColor: accentColor),
        SizedBox(width: 8.w),
        _SpeedBar(height: 70.h, isActive: level >= 2, accentColor: accentColor),
        SizedBox(width: 8.w),
        _SpeedBar(height: 92.h, isActive: level >= 3, accentColor: accentColor),
      ],
    );
  }
}

class _SpeedBar extends StatelessWidget {
  final double height;
  final bool isActive;
  final Color accentColor;

  const _SpeedBar({
    required this.height,
    required this.isActive,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeInOut,
      width: 24.w,
      height: height,
      decoration: BoxDecoration(
        color: isActive
            ? accentColor
            : Colors.white.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(8.r),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.28),
                  blurRadius: 10.r,
                  offset: Offset(0, 4.h),
                ),
              ]
            : [],
      ),
    );
  }
}

class _AnimatedActionButton extends StatefulWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  final Color accentColor;
  final Color textColor;

  const _AnimatedActionButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
    required this.accentColor,
    required this.textColor,
  });

  @override
  State<_AnimatedActionButton> createState() => _AnimatedActionButtonState();
}

class _AnimatedActionButtonState extends State<_AnimatedActionButton> {
  bool _isPressed = false;

  void _setPressed(bool value) {
    if (!widget.enabled) return;
    if (_isPressed == value) return;
    setState(() {
      _isPressed = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isEnabled = widget.enabled;

    final Color backgroundColor = !isEnabled
        ? Colors.white.withValues(alpha: 0.08)
        : _isPressed
        ? widget.accentColor
        : Colors.white.withValues(alpha: 0.18);

    final Color borderColor = !isEnabled
        ? Colors.white.withValues(alpha: 0.12)
        : _isPressed
        ? widget.accentColor
        : Colors.white.withValues(alpha: 0.28);

    final Color iconColor = !isEnabled
        ? widget.textColor.withValues(alpha: 0.32)
        : widget.textColor;

    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: isEnabled ? widget.onTap : null,
      child: AnimatedScale(
        scale: _isPressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeInOut,
          width: 42.w,
          height: 42.w,
          decoration: BoxDecoration(
            color: backgroundColor,
            shape: BoxShape.circle,
            border: Border.all(color: borderColor, width: 1.3.w),
            boxShadow: _isPressed
                ? [
                    BoxShadow(
                      color: widget.accentColor.withValues(alpha: 0.35),
                      blurRadius: 14.r,
                      offset: Offset(0, 4.h),
                    ),
                  ]
                : [],
          ),
          child: Icon(widget.icon, color: iconColor, size: 24.sp),
        ),
      ),
    );
  }
}
