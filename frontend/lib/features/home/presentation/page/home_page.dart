import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:frontend/features/home/presentation/widget/car_status.dart';
import 'package:frontend/features/home/presentation/widget/map_card.dart';
import 'package:frontend/features/home/presentation/widget/media_card.dart';
import 'package:frontend/features/home/presentation/widget/quick_action_grid.dart';
import 'package:frontend/features/home/presentation/widget/side_menu.dart';
import 'package:frontend/features/home/presentation/widget/top_bar.dart';
import '../../../boot/presentation/widget/dotted_background.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          /// Background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFCACACA), // 0%
                  Color(0xFFBABABA), // 48%
                  Color(0xFFF2F2F2),
                ],
                stops: [0.0, 0.48, 1.0],
              ),
            ),
          ),
          const Positioned.fill(child: DottedBackground()),

          Row(
            children: [
              /// Sidebar
              const SideMenu(),

              /// Main Content
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(30.w),
                  child: Column(
                    children: [
                      const TopBar(),

                      SizedBox(height: 30.h),

                      Expanded(
                        child: Row(
                          children: [
                            /// LEFT SIDE
                            Expanded(
                              flex: 2,
                              child: Column(
                                children: [
                                  const MapCard(),

                                  SizedBox(height: 25.h),

                                  const MediaCard(),
                                ],
                              ),
                            ),

                            SizedBox(width: 30.w),

                            /// RIGHT SIDE
                            Expanded(
                              flex: 2,
                              child: Column(
                                children: [
                                  const CarStatusCard(),

                                  SizedBox(height: 25.h),

                                  const QuickActionGrid(),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
