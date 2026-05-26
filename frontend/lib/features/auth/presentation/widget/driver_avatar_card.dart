import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class DriverAvatarCard extends StatefulWidget {
  final String name;
  final VoidCallback onTap;
  final bool isAddButton;

  const DriverAvatarCard({
    super.key,
    required this.name,
    required this.onTap,
    this.isAddButton = false,
  });

  @override
  State<DriverAvatarCard> createState() => _DriverAvatarCardState();
}

class _DriverAvatarCardState extends State<DriverAvatarCard> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: MouseRegion(
        onEnter: (_) => setState(() => isHovered = true),
        onExit: (_) => setState(() => isHovered = false),
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 140.w,
              height: 140.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isHovered ? Colors.white : Colors.white54,
                  width: 2,
                ),
                color: Colors.black,
                boxShadow: isHovered
                    ? [
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.3),
                          blurRadius: 20,
                        ),
                      ]
                    : [],
              ),
              child: Icon(
                widget.isAddButton ? Icons.add : Icons.person,
                color: Colors.white,
                size: 60.sp,
              ),
            ),

            SizedBox(height: 20.h),

            Text(
              widget.name,
              style: TextStyle(fontSize: 22.sp, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
