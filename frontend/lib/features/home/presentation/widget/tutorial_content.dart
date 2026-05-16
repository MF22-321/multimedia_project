import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:frontend/core/themes/car_theme.dart';

class TutorialPage extends StatefulWidget {
  const TutorialPage({super.key});

  @override
  State<TutorialPage> createState() => _TutorialPageState();
}

class _TutorialPageState extends State<TutorialPage> {
  late Timer timer;

  DateTime now = DateTime.now();

  final List<Map<String, dynamic>> tutorials = [
    {
      'title': 'Buka Kap Mobil',

      'image': 'https://images.unsplash.com/photo-1503376780353-7e6692767b70',
    },

    {
      'title': 'Buka Tutup Tangki',

      'image': 'https://images.unsplash.com/photo-1492144534655-ae79c964c9d7',
    },

    {
      'title': 'Pair Bluetooth',

      'image': 'https://images.unsplash.com/photo-1511919884226-fd3cad34687c',
    },

    {
      'title': 'Voice Assistant',

      'image': 'https://images.unsplash.com/photo-1489824904134-891ab64532f1',
    },
  ];

  @override
  void initState() {
    super.initState();

    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        now = DateTime.now();
      });
    });
  }

  @override
  void dispose() {
    timer.cancel();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentTheme = CarThemes.currentTheme.value;

    final theme = CarThemes.getTheme(currentTheme);

    final accentColor = currentTheme == CarThemeType.comfort
        ? const Color(0xFF6CB4FF)
        : theme.accentColor;

    return Scaffold(
      backgroundColor: Colors.black,

      body: Container(
        width: double.infinity,
        height: double.infinity,

        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,

            end: Alignment.bottomRight,

            colors: theme.backgroundGradient,
          ),
        ),

        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(24.w),

            child: Row(
              children: [
                /// =========================
                /// CONTENT
                /// =========================
                Expanded(
                  child: Container(
                    padding: EdgeInsets.all(28.w),

                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(40.r),

                      color: Colors.white.withOpacity(0.05),

                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                    ),

                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [
                        /// =========================
                        /// TOP BAR
                        /// =========================
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,

                          children: [
                            /// USER
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 18.w,

                                vertical: 14.h,
                              ),

                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(22.r),

                                color: Colors.white.withOpacity(0.06),
                              ),

                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 20.r,

                                    backgroundColor: accentColor,

                                    child: Icon(
                                      Icons.person,

                                      color: Colors.white,

                                      size: 22.sp,
                                    ),
                                  ),

                                  SizedBox(width: 12.w),

                                  Text(
                                    'Hello, User',

                                    style: TextStyle(
                                      color: Colors.white,

                                      fontSize: 18.sp,

                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            /// TIME
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,

                              children: [
                                Text(
                                  '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',

                                  style: TextStyle(
                                    color: Colors.white,

                                    fontSize: 26.sp,

                                    fontWeight: FontWeight.bold,
                                  ),
                                ),

                                SizedBox(height: 4.h),

                                Text(
                                  '${now.day}/${now.month}/${now.year}',

                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.6),

                                    fontSize: 14.sp,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),

                        SizedBox(height: 34.h),

                        /// =========================
                        /// HEADER
                        /// =========================
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () {
                                Navigator.pop(context);
                              },

                              child: Container(
                                width: 60.w,
                                height: 60.w,

                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,

                                  color: Colors.white.withOpacity(0.08),
                                ),

                                child: Icon(
                                  Icons.arrow_back_ios_new,

                                  color: accentColor,

                                  size: 24.sp,
                                ),
                              ),
                            ),

                            SizedBox(width: 20.w),

                            Text('Video Tutorial', 

                              style: TextStyle(
                                color: Colors.white,

                                fontSize: 15.sp,

                                
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: 36.h),

                        /// =========================
                        /// VIDEO GRID
                        /// =========================
                        Expanded(
                          child: GridView.builder(
                            physics: const BouncingScrollPhysics(),

                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,

                                  crossAxisSpacing: 24.w,

                                  mainAxisSpacing: 24.h,

                                  childAspectRatio: 2.2,
                                ),

                            itemCount: tutorials.length,

                            itemBuilder: (context, index) {
                              final item = tutorials[index];

                              return GestureDetector(
                                onTap: () {
                                  /// PLAY VIDEO
                                },

                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 250),

                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(30.r),

                                    color: Colors.white.withOpacity(0.05),

                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.08),
                                    ),

                                    boxShadow: [
                                      BoxShadow(
                                        color: accentColor.withOpacity(0.08),

                                        blurRadius: 24,
                                      ),
                                    ],
                                  ),

                                  child: Row(
                                    children: [
                                      /// IMAGE
                                      Expanded(
                                        flex: 5,

                                        child: ClipRRect(
                                          borderRadius: BorderRadius.only(
                                            topLeft: Radius.circular(30.r),

                                            bottomLeft: Radius.circular(30.r),
                                          ),

                                          child: Stack(
                                            fit: StackFit.expand,

                                            children: [
                                              Image.network(
                                                item['image'],

                                                fit: BoxFit.cover,
                                              ),

                                              Container(
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    begin: Alignment.topCenter,

                                                    end: Alignment.bottomCenter,

                                                    colors: [
                                                      Colors.black.withOpacity(
                                                        0.05,
                                                      ),

                                                      Colors.black.withOpacity(
                                                        0.55,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),

                                              Center(
                                                child: Container(
                                                  width: 70.w,

                                                  height: 70.w,

                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,

                                                    color: Colors.white,

                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: accentColor
                                                            .withOpacity(0.35),

                                                        blurRadius: 25,
                                                      ),
                                                    ],
                                                  ),

                                                  child: Icon(
                                                    Icons.play_arrow_rounded,

                                                    color: accentColor,

                                                    size: 42.sp,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),

                                      /// TEXT
                                      Expanded(
                                        flex: 4,

                                        child: Padding(
                                          padding: EdgeInsets.all(24.w),

                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,

                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,

                                            children: [
                                              Text(
                                                item['title'],

                                                style: TextStyle(
                                                  color: Colors.white,

                                                  fontSize: 28.sp,

                                                  fontWeight: FontWeight.bold,

                                                  height: 1.3,
                                                ),
                                              ),

                                              SizedBox(height: 14.h),

                                              Text(
                                                'Pelajari langkah penggunaan fitur kendaraan dengan mudah.',

                                                style: TextStyle(
                                                  color: Colors.white
                                                      .withOpacity(0.55),

                                                  fontSize: 15.sp,

                                                  height: 1.5,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
