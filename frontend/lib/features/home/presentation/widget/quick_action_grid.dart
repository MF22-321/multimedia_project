import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:frontend/core/themes/car_theme.dart';

class QuickActionGrid extends StatelessWidget {
  const QuickActionGrid({super.key});

  @override
  Widget build(BuildContext context) {

    final actions = [
      _ActionItem("M-Toyota", Icons.car_rental),
      _ActionItem("Music", Icons.play_circle_fill),
      _ActionItem("Radio", Icons.radio),
      _ActionItem("Bluetooth", Icons.bluetooth),
      _ActionItem("Car Status", Icons.directions_car),
      _ActionItem("Screen Cast", Icons.cast),
      _ActionItem("USB", Icons.usb),
      _ActionItem("Info", Icons.info),
    ];

    return ValueListenableBuilder(
      valueListenable: CarThemes.currentTheme,
      builder: (context, themeType, _) {

       final theme = CarThemes.getTheme(themeType);

        return Expanded(
          child: GridView.builder(
            itemCount: actions.length,

            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 20.h,
              crossAxisSpacing: 20.w,
              childAspectRatio: 1,
            ),

            itemBuilder: (context, index) {

              final item = actions[index];

              return GestureDetector(
                onTap: () {},

                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 400),

                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22.r),

                    gradient: LinearGradient(
                      colors: [
                        theme.backgroundGradient.last.withOpacity(0.85),
                        Colors.black.withOpacity(0.35),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),

                    border: Border.all(
                      color: theme.accentColor.withOpacity(0.4),
                      width: 1.5,
                    ),

                    boxShadow: [
                      BoxShadow(
                        color: theme.accentColor.withOpacity(0.25),
                        blurRadius: 12,
                        offset: const Offset(0, 5),
                      )
                    ],
                  ),

                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [

                      Icon(
                        item.icon,
                        size: 40.sp,
                        color: theme.accentColor,
                      ),

                      SizedBox(height: 8.h),

                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: theme.textColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _ActionItem {

  final String label;
  final IconData icon;

  _ActionItem(this.label, this.icon);
}