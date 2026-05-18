import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:frontend/core/themes/car_theme.dart';

class CarInfoContent extends StatefulWidget {
  const CarInfoContent({super.key});

  @override
  State<CarInfoContent> createState() => _CarInfoPageState();
}

class _CarInfoPageState extends State<CarInfoContent>
    with SingleTickerProviderStateMixin {

  int selectedDriveMode = 0;

  late AnimationController _floatingController;

  late Timer timer;

  DateTime now = DateTime.now();

  @override
  void initState() {
    super.initState();

    _floatingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    /// REALTIME CLOCK
    timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {

        setState(() {
          now = DateTime.now();
        });
      },
    );
  }

  @override
  void dispose() {

    _floatingController.dispose();

    timer.cancel();

    super.dispose();
  }

  /// ===============================
  /// ACCENT COLOR
  /// ===============================
  Color getAccentColor(
    CarThemeType type,
    CarThemeData theme,
  ) {

    switch (type) {

      case CarThemeType.comfort:
        return const Color(0xFF6CB4FF);

      case CarThemeType.sport:
        return Colors.redAccent;

      case CarThemeType.futuristic:
        return const Color(0xFF00E5FF);

      case CarThemeType.retro:
        return const Color(0xFFFF2BC2);

      case CarThemeType.playful:
        return const Color(0xFFC6A883);

      case CarThemeType.custom:
        return theme.buttonColor;
    }
  }

  @override
  Widget build(BuildContext context) {

    final currentTheme =
        CarThemes.currentTheme.value;

    final theme =
        CarThemes.getTheme(currentTheme);

    final accent =
        getAccentColor(
          currentTheme,
          theme,
        );

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

        child: Stack(
          children: [

            /// =========================
            /// AMBIENT GLOW
            /// =========================
            Positioned(
              right: -120.w,
              top: 120.h,

              child: Container(
                width: 420.w,
                height: 420.w,

                decoration: BoxDecoration(
                  shape: BoxShape.circle,

                  color: accent.withOpacity(0.18),
                ),
              ),
            ),

            Positioned(
              left: -80.w,
              bottom: 50.h,

              child: Container(
                width: 320.w,
                height: 320.w,

                decoration: BoxDecoration(
                  shape: BoxShape.circle,

                  color: accent.withOpacity(0.08),
                ),
              ),
            ),

            /// =========================
            /// BLUR
            /// =========================
            BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: 30,
                sigmaY: 30,
              ),

              child: Container(
                color: Colors.black.withOpacity(
                  0.1,
                ),
              ),
            ),

            SafeArea(
              child: Padding(
                padding: EdgeInsets.all(24.w),

                child: Column(
                  children: [

                    /// =====================
                    /// TOP BAR
                    /// =====================
                    Container(
                      height: 90.h,

                      padding: EdgeInsets.symmetric(
                        horizontal: 28.w,
                      ),

                      decoration: BoxDecoration(
                        borderRadius:
                            BorderRadius.circular(
                              30.r,
                            ),

                        color: Colors.white
                            .withOpacity(0.05),

                        border: Border.all(
                          color: Colors.white
                              .withOpacity(0.08),
                        ),
                      ),

                      child: Row(
                        mainAxisAlignment:
                            MainAxisAlignment
                                .spaceBetween,

                        children: [

                          /// =================
                          /// LEFT
                          /// =================
                          Row(
                            children: [

                              /// BACK BUTTON
                              GestureDetector(
                                onTap: () {
                                  Navigator.pop(
                                    context,
                                  );
                                },

                                child: Container(
                                  width: 52.w,
                                  height: 52.w,

                                  decoration: BoxDecoration(
                                    shape:
                                        BoxShape.circle,

                                    color: Colors.white
                                        .withOpacity(
                                          0.06,
                                        ),

                                    border: Border.all(
                                      color: Colors
                                          .white
                                          .withOpacity(
                                            0.08,
                                          ),
                                    ),
                                  ),

                                  child: Icon(
                                    Icons
                                        .arrow_back_ios_new,

                                    color: accent,

                                    size: 22.sp,
                                  ),
                                ),
                              ),

                              SizedBox(width: 18.w),

                              /// CAR ICON
                              Container(
                                width: 52.w,
                                height: 52.w,

                                decoration: BoxDecoration(
                                  shape:
                                      BoxShape.circle,

                                  color: accent,
                                ),

                                child: Icon(
                                  Icons
                                      .directions_car,

                                  color: Colors.white,

                                  size: 28.sp,
                                ),
                              ),

                              SizedBox(width: 16.w),

                              /// VEHICLE INFO
                              Column(
                                mainAxisAlignment:
                                    MainAxisAlignment
                                        .center,

                                crossAxisAlignment:
                                    CrossAxisAlignment
                                        .start,

                                children: [

                                  Text(
                                    'Toyota Veloz',

                                    style: TextStyle(
                                      color:
                                          Colors.white,

                                      fontSize: 24.sp,

                                      fontWeight:
                                          FontWeight
                                              .bold,
                                    ),
                                  ),

                                  SizedBox(
                                    height: 4.h,
                                  ),

                                  Text(
                                    'Connected Vehicle',

                                    style: TextStyle(
                                      color: Colors
                                          .white60,

                                      fontSize: 14.sp,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),

                          /// =================
                          /// RIGHT
                          /// =================
                          Row(
                            children: [

                              _topBarIcon(
                                Icons.bluetooth,
                                accent,
                              ),

                              SizedBox(width: 16.w),

                              _topBarIcon(
                                Icons.wifi,
                                accent,
                              ),

                              SizedBox(width: 24.w),

                              /// REALTIME CLOCK
                              Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment
                                        .end,

                                mainAxisAlignment:
                                    MainAxisAlignment
                                        .center,

                                children: [

                                  Text(
                                    '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',

                                    style: TextStyle(
                                      color:
                                          Colors.white,

                                      fontSize: 28.sp,

                                      fontWeight:
                                          FontWeight
                                              .bold,
                                    ),
                                  ),

                                  SizedBox(
                                    height: 4.h,
                                  ),

                                  Text(
                                    '${now.day}/${now.month}/${now.year}',

                                    style: TextStyle(
                                      color: Colors
                                          .white60,

                                      fontSize: 13.sp,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 24.h),

                    /// =====================
                    /// MAIN CONTENT
                    /// =====================
                    Expanded(
                      child: Row(
                        children: [

                          /// =================
                          /// LEFT PANEL
                          /// =================
                          Container(
                            width: 330.w,

                            padding: EdgeInsets.all(
                              24.w,
                            ),

                            decoration: BoxDecoration(
                              borderRadius:
                                  BorderRadius.circular(
                                    38.r,
                                  ),

                              color: Colors.white
                                  .withOpacity(0.05),

                              border: Border.all(
                                color: Colors.white
                                    .withOpacity(
                                      0.08,
                                    ),
                              ),
                            ),

                            child: SingleChildScrollView(
                              physics:
                                  const BouncingScrollPhysics(),

                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment
                                        .start,

                                children: [

                                  /// TITLE
                                  Text(
                                    'Vehicle Status',

                                    style: TextStyle(
                                      color:
                                          Colors.white,

                                      fontSize: 26.sp,

                                      fontWeight:
                                          FontWeight
                                              .bold,
                                    ),
                                  ),

                                  SizedBox(
                                    height: 28.h,
                                  ),

                                  /// DRIVE MODE
                                  _glassCard(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment
                                              .start,

                                      children: [

                                        Text(
                                          'Drive Mode',

                                          style:
                                              TextStyle(
                                                color:
                                                    Colors
                                                        .white,

                                                fontSize:
                                                    18.sp,

                                                fontWeight:
                                                    FontWeight
                                                        .bold,
                                              ),
                                        ),

                                        SizedBox(
                                          height: 18.h,
                                        ),

                                        Wrap(
                                          spacing: 10.w,
                                          runSpacing:
                                              10.h,

                                          children: [

                                            _modeChip(
                                              title:
                                                  'Comfort',

                                              index: 0,

                                              accent:
                                                  accent,
                                            ),

                                            _modeChip(
                                              title:
                                                  'Eco',

                                              index: 1,

                                              accent:
                                                  accent,
                                            ),

                                            _modeChip(
                                              title:
                                                  'Sport',

                                              index: 2,

                                              accent:
                                                  accent,
                                            ),

                                            _modeChip(
                                              title:
                                                  'Custom',

                                              index: 3,

                                              accent:
                                                  accent,
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),

                                  SizedBox(
                                    height: 20.h,
                                  ),

                                  /// VEHICLE STATUS
                                  _glassCard(
                                    child: Column(
                                      children: [

                                        _statusTile(
                                          icon: Icons
                                              .local_gas_station,

                                          title: 'Fuel',

                                          value: '78%',

                                          accent:
                                              accent,
                                        ),

                                        SizedBox(
                                          height: 18.h,
                                        ),

                                        _statusTile(
                                          icon: Icons
                                              .battery_charging_full,

                                          title:
                                              'Battery',

                                          value:
                                              'Healthy',

                                          accent:
                                              accent,
                                        ),

                                        SizedBox(
                                          height: 18.h,
                                        ),

                                        _statusTile(
                                          icon: Icons
                                              .speed,

                                          title:
                                              'Engine',

                                          value:
                                              'Normal',

                                          accent:
                                              accent,
                                        ),
                                      ],
                                    ),
                                  ),

                                  SizedBox(
                                    height: 20.h,
                                  ),

                                  /// TIRE PRESSURE
                                  _glassCard(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment
                                              .start,

                                      children: [

                                        Text(
                                          'Tire Pressure',

                                          style:
                                              TextStyle(
                                                color:
                                                    Colors
                                                        .white,

                                                fontSize:
                                                    18.sp,

                                                fontWeight:
                                                    FontWeight
                                                        .bold,
                                              ),
                                        ),

                                        SizedBox(
                                          height: 18.h,
                                        ),

                                        _tireTile(
                                          'Front Left',
                                          '32 PSI',
                                        ),

                                        SizedBox(
                                          height: 12.h,
                                        ),

                                        _tireTile(
                                          'Front Right',
                                          '32 PSI',
                                        ),

                                        SizedBox(
                                          height: 12.h,
                                        ),

                                        _tireTile(
                                          'Rear Left',
                                          '30 PSI',
                                        ),

                                        SizedBox(
                                          height: 12.h,
                                        ),

                                        _tireTile(
                                          'Rear Right',
                                          '30 PSI',
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          SizedBox(width: 24.w),

                          /// =================
                          /// CENTER VEHICLE
                          /// =================
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius:
                                    BorderRadius.circular(
                                      38.r,
                                    ),

                                color: Colors.white
                                    .withOpacity(0.05),

                                border: Border.all(
                                  color: Colors.white
                                      .withOpacity(
                                        0.08,
                                      ),
                                ),
                              ),

                              child: Column(
                                children: [

                                  /// =================
                                  /// VEHICLE CONTENT
                                  /// =================
                                  Expanded(
                                    child:
                                        SingleChildScrollView(
                                          physics:
                                              const BouncingScrollPhysics(),

                                          child: Center(
                                            child:
                                                AnimatedBuilder(
                                                  animation:
                                                      _floatingController,

                                                  builder: (
                                                    context,
                                                    child,
                                                  ) {

                                                    return Transform.translate(
                                                      offset:
                                                          Offset(
                                                            0,

                                                            _floatingController
                                                                    .value *
                                                                -12,
                                                          ),

                                                      child:
                                                          child,
                                                    );
                                                  },

                                                  child:
                                                      Column(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .center,

                                                        children: [

                                                          SizedBox(
                                                            height:
                                                                40.h,
                                                          ),

                                                          /// VEHICLE
                                                          Container(
                                                            width:
                                                                620.w,

                                                            height:
                                                                340.h,

                                                            decoration:
                                                                BoxDecoration(
                                                                  boxShadow: [
                                                                    BoxShadow(
                                                                      color: accent.withOpacity(
                                                                        0.35,
                                                                      ),

                                                                      blurRadius:
                                                                          80,

                                                                      spreadRadius:
                                                                          8,
                                                                    ),
                                                                  ],
                                                                ),

                                                            child:
                                                                Image.asset(
                                                                  "assets/images/veloz.png",

                                                                  fit:
                                                                      BoxFit.contain,
                                                                ),
                                                          ),

                                                          SizedBox(
                                                            height:
                                                                10.h,
                                                          ),

                                                          /// TITLE
                                                          Text(
                                                            'Toyota Veloz 2026',

                                                            style:
                                                                TextStyle(
                                                                  color:
                                                                      Colors.white,

                                                                  fontSize:
                                                                      34.sp,

                                                                  fontWeight:
                                                                      FontWeight.bold,
                                                                ),
                                                          ),

                                                          SizedBox(
                                                            height:
                                                                10.h,
                                                          ),

                                                          /// SUBTITLE
                                                          Text(
                                                            'Modern Connected Vehicle',

                                                            style:
                                                                TextStyle(
                                                                  color:
                                                                      Colors.white60,

                                                                  fontSize:
                                                                      18.sp,
                                                                ),
                                                          ),

                                                          SizedBox(
                                                            height:
                                                                40.h,
                                                          ),
                                                        ],
                                                      ),
                                                ),
                                          ),
                                        ),
                                  ),

                                  /// =================
                                  /// BOTTOM MENU
                                  /// =================
                                  Padding(
                                    padding:
                                        EdgeInsets.all(
                                          24.w,
                                        ),

                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment
                                              .spaceEvenly,

                                      children: [

                                        _bottomButton(
                                          Icons.ac_unit,
                                          'Climate',
                                          accent,
                                        ),

                                        _bottomButton(
                                          Icons.lightbulb,
                                          'Lights',
                                          accent,
                                        ),

                                        _bottomButton(
                                          Icons.lock,
                                          'Lock',
                                          accent,
                                        ),

                                        _bottomButton(
                                          Icons.camera_alt,
                                          'Camera',
                                          accent,
                                        ),

                                        _bottomButton(
                                          Icons.car_repair,
                                          'Service',
                                          accent,
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
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ===============================
  /// TOP BAR ICON
  /// ===============================
  Widget _topBarIcon(
    IconData icon,
    Color accent,
  ) {
    return Container(
      width: 48.w,
      height: 48.w,

      decoration: BoxDecoration(
        shape: BoxShape.circle,

        color: Colors.white.withOpacity(0.06),

        border: Border.all(
          color: Colors.white.withOpacity(0.08),
        ),
      ),

      child: Icon(
        icon,
        color: accent,
        size: 24.sp,
      ),
    );
  }

  /// ===============================
  /// GLASS CARD
  /// ===============================
  Widget _glassCard({
    required Widget child,
  }) {
    return Container(
      width: double.infinity,

      padding: EdgeInsets.all(20.w),

      decoration: BoxDecoration(
        borderRadius:
            BorderRadius.circular(28.r),

        color: Colors.white.withOpacity(0.05),

        border: Border.all(
          color: Colors.white.withOpacity(0.06),
        ),
      ),

      child: child,
    );
  }

  /// ===============================
  /// MODE CHIP
  /// ===============================
  Widget _modeChip({
    required String title,
    required int index,
    required Color accent,
  }) {

    final active =
        selectedDriveMode == index;

    return GestureDetector(
      onTap: () {

        setState(() {
          selectedDriveMode = index;
        });
      },

      child: AnimatedContainer(
        duration: const Duration(
          milliseconds: 250,
        ),

        padding: EdgeInsets.symmetric(
          horizontal: 18.w,
          vertical: 12.h,
        ),

        decoration: BoxDecoration(
          borderRadius:
              BorderRadius.circular(20.r),

          color: active
              ? accent
              : Colors.white.withOpacity(0.06),

          boxShadow: active
              ? [
                  BoxShadow(
                    color:
                        accent.withOpacity(0.35),

                    blurRadius: 18,
                  ),
                ]
              : [],
        ),

        child: Text(
          title,

          style: TextStyle(
            color: active
                ? Colors.black
                : Colors.white,

            fontSize: 15.sp,

            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  /// ===============================
  /// STATUS TILE
  /// ===============================
  Widget _statusTile({
    required IconData icon,
    required String title,
    required String value,
    required Color accent,
  }) {
    return Row(
      children: [

        Container(
          width: 48.w,
          height: 48.w,

          decoration: BoxDecoration(
            shape: BoxShape.circle,

            color: accent.withOpacity(0.18),
          ),

          child: Icon(
            icon,
            color: accent,
            size: 24.sp,
          ),
        ),

        SizedBox(width: 14.w),

        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,

            children: [

              Text(
                title,

                style: TextStyle(
                  color: Colors.white70,

                  fontSize: 14.sp,
                ),
              ),

              SizedBox(height: 4.h),

              Text(
                value,

                style: TextStyle(
                  color: Colors.white,

                  fontSize: 18.sp,

                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// ===============================
  /// TIRE TILE
  /// ===============================
  Widget _tireTile(
    String title,
    String value,
  ) {
    return Row(
      mainAxisAlignment:
          MainAxisAlignment.spaceBetween,

      children: [

        Text(
          title,

          style: TextStyle(
            color: Colors.white70,

            fontSize: 15.sp,
          ),
        ),

        Text(
          value,

          style: TextStyle(
            color: Colors.white,

            fontSize: 16.sp,

            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  /// ===============================
  /// BOTTOM BUTTON
  /// ===============================
  Widget _bottomButton(
    IconData icon,
    String title,
    Color accent,
  ) {
    return Container(
      width: 120.w,
      height: 88.h,

      decoration: BoxDecoration(
        borderRadius:
            BorderRadius.circular(28.r),

        color: Colors.white.withOpacity(0.05),

        border: Border.all(
          color: Colors.white.withOpacity(0.08),
        ),
      ),

      child: Column(
        mainAxisAlignment:
            MainAxisAlignment.center,

        children: [

          Icon(
            icon,
            color: accent,
            size: 28.sp,
          ),

          SizedBox(height: 10.h),

          Text(
            title,

            style: TextStyle(
              color: Colors.white,

              fontSize: 15.sp,

              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}