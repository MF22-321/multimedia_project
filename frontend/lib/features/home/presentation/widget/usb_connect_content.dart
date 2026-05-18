import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:frontend/core/themes/car_theme.dart';

class UsbConnectContent extends StatefulWidget {
  const UsbConnectContent({super.key});

  @override
  State<UsbConnectContent> createState() =>
      _UsbConnectContentState();
}

class _UsbConnectContentState
    extends State<UsbConnectContent> {

  late Timer timer;

  DateTime now = DateTime.now();

  bool usbConnected = true;

  bool usbAudioConnected = true;

  bool isScanning = false;

  String deviceName = "Samsung S24 Ultra";

  String androidVersion = "Android 16";

  String storage = "256 GB";

  String mountPath =
      "/media/febrian/S24";

  String audioCodec = "AAC";

  String sampleRate = "48 kHz";

  String usbMode = "USB Audio";

  String adbStatus = "Connected";

  @override
  void initState() {
    super.initState();

    /// REALTIME CLOCK
    timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {

        setState(() {
          now = DateTime.now();
        });
      },
    );

    /// OPTIONAL AUTO CHECK USB
    checkUsbConnection();
  }

  @override
  void dispose() {

    timer.cancel();

    super.dispose();
  }

  /// ===============================
  /// CHECK USB DEVICE
  /// ===============================
  Future<void> checkUsbConnection() async {

    try {

      final result =
          await Process.run(
            'adb',
            ['devices'],
          );

      final output =
          result.stdout.toString();

      setState(() {

        usbConnected =
            output.contains(
              'device',
            );

        adbStatus =
            usbConnected
            ? "Connected"
            : "Disconnected";
      });

    } catch (e) {

      debugPrint(
        e.toString(),
      );
    }
  }

  /// ===============================
  /// CONNECT USB AUDIO
  /// ===============================
  Future<void> connectUsbAudio() async {

    setState(() {
      isScanning = true;
    });

    await Future.delayed(
      const Duration(
        seconds: 2,
      ),
    );

    setState(() {

      usbAudioConnected = true;

      isScanning = false;
    });

    /// OPTIONAL:
    /// USE pactl / pipewire here
  }

  /// ===============================
  /// DISCONNECT
  /// ===============================
  void disconnectUsb() {

    setState(() {

      usbConnected = false;

      usbAudioConnected = false;

      adbStatus = "Disconnected";
    });
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
        return const Color(
          0xFF6CB4FF,
        );

      case CarThemeType.sport:
        return Colors.redAccent;

      case CarThemeType.futuristic:
        return const Color(
          0xFF00E5FF,
        );

      case CarThemeType.retro:
        return const Color(
          0xFFFF2BC2,
        );

      case CarThemeType.playful:
        return const Color(
          0xFFC6A883,
        );

      case CarThemeType.custom:
        return theme.buttonColor;
    }
  }

  @override
  Widget build(BuildContext context) {

    final currentTheme =
        CarThemes.currentTheme.value;

    final theme =
        CarThemes.getTheme(
          currentTheme,
        );

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

            colors:
                theme.backgroundGradient,
          ),
        ),

        child: Stack(
          children: [

            /// =========================
            /// AMBIENT GLOW
            /// =========================
            Positioned(
              right: -120.w,
              top: 80.h,

              child: Container(
                width: 420.w,
                height: 420.w,

                decoration: BoxDecoration(
                  shape: BoxShape.circle,

                  color: accent.withOpacity(
                    0.16,
                  ),
                ),
              ),
            ),

            Positioned(
              left: -80.w,
              bottom: -50.h,

              child: Container(
                width: 320.w,
                height: 320.w,

                decoration: BoxDecoration(
                  shape: BoxShape.circle,

                  color: accent.withOpacity(
                    0.08,
                  ),
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
                color: Colors.black
                    .withOpacity(
                      0.12,
                    ),
              ),
            ),

            SafeArea(
              child: Padding(
                padding: EdgeInsets.all(
                  24.w,
                ),

                child: Column(
                  children: [

                    /// =====================
                    /// TOP BAR
                    /// =====================
                    Container(
                      height: 90.h,

                      padding:
                          EdgeInsets.symmetric(
                            horizontal: 28.w,
                          ),

                      decoration: BoxDecoration(
                        borderRadius:
                            BorderRadius.circular(
                              30.r,
                            ),

                        color: Colors.white
                            .withOpacity(
                              0.05,
                            ),

                        border: Border.all(
                          color: Colors.white
                              .withOpacity(
                                0.08,
                              ),
                        ),
                      ),

                      child: Row(
                        mainAxisAlignment:
                            MainAxisAlignment
                                .spaceBetween,

                        children: [

                          /// LEFT
                          Row(
                            children: [

                              GestureDetector(
                                onTap: () {
                                  Navigator.pop(
                                    context,
                                  );
                                },

                                child: Container(
                                  width: 52.w,
                                  height: 52.w,

                                  decoration:
                                      BoxDecoration(
                                        shape:
                                            BoxShape
                                                .circle,

                                        color: Colors
                                            .white
                                            .withOpacity(
                                              0.06,
                                            ),

                                        border:
                                            Border.all(
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

                              SizedBox(
                                width: 18.w,
                              ),

                              Container(
                                width: 52.w,
                                height: 52.w,

                                decoration:
                                    BoxDecoration(
                                      shape:
                                          BoxShape
                                              .circle,

                                      color: accent,
                                    ),

                                child: Icon(
                                  Icons.usb,

                                  color: Colors.white,

                                  size: 28.sp,
                                ),
                              ),

                              SizedBox(
                                width: 16.w,
                              ),

                              Column(
                                mainAxisAlignment:
                                    MainAxisAlignment
                                        .center,

                                crossAxisAlignment:
                                    CrossAxisAlignment
                                        .start,

                                children: [

                                  Text(
                                    'USB Connect',

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
                                    'USB Audio Hub',

                                    style: TextStyle(
                                      color: Colors
                                          .white60,

                                      fontSize:
                                          14.sp,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),

                          /// RIGHT
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
                                  color: Colors.white,

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
                                  color:
                                      Colors.white60,

                                  fontSize:
                                      13.sp,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    SizedBox(
                      height: 24.h,
                    ),

                    /// =====================
                    /// MAIN CONTENT
                    /// =====================
                    Expanded(
                      child: SingleChildScrollView(
                        physics:
                            const BouncingScrollPhysics(),

                        child: Column(
                          children: [

                            /// =================
                            /// HERO CARD
                            /// =================
                            Container(
                              width: double.infinity,

                              padding:
                                  EdgeInsets.all(
                                    28.w,
                                  ),

                              decoration:
                                  BoxDecoration(
                                    borderRadius:
                                        BorderRadius.circular(
                                          40.r,
                                        ),

                                    color: Colors
                                        .white
                                        .withOpacity(
                                          0.05,
                                        ),

                                    border:
                                        Border.all(
                                          color: Colors
                                              .white
                                              .withOpacity(
                                                0.08,
                                              ),
                                        ),

                                    boxShadow: [
                                      BoxShadow(
                                        color: accent
                                            .withOpacity(
                                              0.14,
                                            ),

                                        blurRadius:
                                            30,
                                      ),
                                    ],
                                  ),

                              child: Row(
                                children: [

                                  /// DEVICE IMAGE
                                  Container(
                                    width: 180.w,
                                    height: 180.w,

                                    decoration:
                                        BoxDecoration(
                                          shape:
                                              BoxShape
                                                  .circle,

                                          color: Colors
                                              .white
                                              .withOpacity(
                                                0.05,
                                              ),

                                          boxShadow: [
                                            BoxShadow(
                                              color: accent
                                                  .withOpacity(
                                                    0.35,
                                                  ),

                                              blurRadius:
                                                  40,
                                            ),
                                          ],
                                        ),

                                    child: Icon(
                                      Icons
                                          .phone_android,

                                      color: accent,

                                      size: 80.sp,
                                    ),
                                  ),

                                  SizedBox(
                                    width: 30.w,
                                  ),

                                  /// INFO
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment
                                              .start,

                                      children: [

                                        Text(
                                          deviceName,

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

                                        Text(
                                          'USB Audio Connected',

                                          style:
                                              TextStyle(
                                                color:
                                                    Colors.white70,

                                                fontSize:
                                                    18.sp,
                                              ),
                                        ),

                                        SizedBox(
                                          height:
                                              24.h,
                                        ),

                                        Wrap(
                                          spacing:
                                              12.w,
                                          runSpacing:
                                              12.h,

                                          children: [

                                            _statusChip(
                                              Icons.usb,
                                              usbMode,
                                              accent,
                                            ),

                                            _statusChip(
                                              Icons.storage,
                                              storage,
                                              accent,
                                            ),

                                            _statusChip(
                                              Icons
                                                  .developer_mode,
                                              adbStatus,
                                              accent,
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            SizedBox(
                              height: 24.h,
                            ),

                            /// =================
                            /// GRID
                            /// =================
                            GridView(
                              shrinkWrap: true,

                              physics:
                                  const NeverScrollableScrollPhysics(),

                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount:
                                        2,

                                    crossAxisSpacing:
                                        24.w,

                                    mainAxisSpacing:
                                        24.h,

                                    childAspectRatio:
                                        1.45,
                                  ),

                              children: [

                                /// USB AUDIO
                                _glassCard(
                                  title:
                                      'USB Audio',

                                  accent:
                                      accent,

                                  child: Column(
                                    children: [

                                      _infoTile(
                                        Icons.music_note,
                                        'Codec',
                                        audioCodec,
                                        accent,
                                      ),

                                      SizedBox(
                                        height:
                                            18.h,
                                      ),

                                      _infoTile(
                                        Icons
                                            .graphic_eq,
                                        'Sample Rate',
                                        sampleRate,
                                        accent,
                                      ),

                                      SizedBox(
                                        height:
                                            18.h,
                                      ),

                                      _infoTile(
                                        Icons
                                            .speaker,
                                        'Output',
                                        'Car Speaker',
                                        accent,
                                      ),
                                    ],
                                  ),
                                ),

                                /// DEVICE INFO
                                _glassCard(
                                  title:
                                      'Device Information',

                                  accent:
                                      accent,

                                  child: Column(
                                    children: [

                                      _infoTile(
                                        Icons
                                            .smartphone,
                                        'Device',
                                        deviceName,
                                        accent,
                                      ),

                                      SizedBox(
                                        height:
                                            18.h,
                                      ),

                                      _infoTile(
                                        Icons
                                            .android,
                                        'Version',
                                        androidVersion,
                                        accent,
                                      ),

                                      SizedBox(
                                        height:
                                            18.h,
                                      ),

                                      _infoTile(
                                        Icons
                                            .folder,
                                        'Mount',
                                        mountPath,
                                        accent,
                                      ),
                                    ],
                                  ),
                                ),

                                /// STORAGE
                                _glassCard(
                                  title:
                                      'Storage Information',

                                  accent:
                                      accent,

                                  child: Column(
                                    children: [

                                      _storageBar(
                                        'Music',
                                        0.72,
                                        accent,
                                      ),

                                      SizedBox(
                                        height:
                                            20.h,
                                      ),

                                      _storageBar(
                                        'Videos',
                                        0.38,
                                        accent,
                                      ),

                                      SizedBox(
                                        height:
                                            20.h,
                                      ),

                                      _storageBar(
                                        'Photos',
                                        0.54,
                                        accent,
                                      ),
                                    ],
                                  ),
                                ),

                                /// CONNECTION STATUS
                                _glassCard(
                                  title:
                                      'Connection Status',

                                  accent:
                                      accent,

                                  child: Column(
                                    children: [

                                      _connectionTile(
                                        'USB Connected',
                                        usbConnected,
                                        accent,
                                      ),

                                      SizedBox(
                                        height:
                                            18.h,
                                      ),

                                      _connectionTile(
                                        'ADB Connected',
                                        usbConnected,
                                        accent,
                                      ),

                                      SizedBox(
                                        height:
                                            18.h,
                                      ),

                                      _connectionTile(
                                        'USB Audio Ready',
                                        usbAudioConnected,
                                        accent,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            SizedBox(
                              height: 24.h,
                            ),

                            /// =================
                            /// ACTION BUTTONS
                            /// =================
                            Row(
                              children: [

                                Expanded(
                                  child:
                                      _actionButton(
                                        title:
                                            'Connect Audio',

                                        icon:
                                            Icons
                                                .headphones,

                                        accent:
                                            accent,

                                        loading:
                                            isScanning,

                                        onTap:
                                            connectUsbAudio,
                                      ),
                                ),

                                SizedBox(
                                  width: 24.w,
                                ),

                                Expanded(
                                  child:
                                      _actionButton(
                                        title:
                                            'Open Music',

                                        icon:
                                            Icons
                                                .music_note,

                                        accent:
                                            accent,

                                        onTap:
                                            () {},
                                      ),
                                ),

                                SizedBox(
                                  width: 24.w,
                                ),

                                Expanded(
                                  child:
                                      _actionButton(
                                        title:
                                            'Disconnect USB',

                                        icon:
                                            Icons
                                                .usb_off,

                                        accent:
                                            Colors.redAccent,

                                        onTap:
                                            disconnectUsb,
                                      ),
                                ),
                              ],
                            ),

                            SizedBox(
                              height: 30.h,
                            ),
                          ],
                        ),
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
  /// GLASS CARD
  /// ===============================
  Widget _glassCard({
    required String title,
    required Widget child,
    required Color accent,
  }) {

    return Container(
      padding: EdgeInsets.all(
        24.w,
      ),

      decoration: BoxDecoration(
        borderRadius:
            BorderRadius.circular(
              34.r,
            ),

        color: Colors.white
            .withOpacity(0.05),

        border: Border.all(
          color: Colors.white
              .withOpacity(0.08),
        ),
      ),

      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        mainAxisSize:
            MainAxisSize.min,

        children: [

          Row(
            children: [

              Container(
                width: 10.w,
                height: 10.w,

                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent,
                ),
              ),

              SizedBox(
                width: 10.w,
              ),

              Text(
                title,

                style: TextStyle(
                  color: Colors.white,

                  fontSize: 22.sp,

                  fontWeight:
                      FontWeight.bold,
                ),
              ),
            ],
          ),

          SizedBox(height: 24.h),

          child,
        ],
      ),
    );
  }

  /// ===============================
  /// STATUS CHIP
  /// ===============================
  Widget _statusChip(
    IconData icon,
    String title,
    Color accent,
  ) {

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 16.w,
        vertical: 12.h,
      ),

      decoration: BoxDecoration(
        borderRadius:
            BorderRadius.circular(
              20.r,
            ),

        color: Colors.white
            .withOpacity(0.06),
      ),

      child: Row(
        mainAxisSize:
            MainAxisSize.min,

        children: [

          Icon(
            icon,
            color: accent,
            size: 18.sp,
          ),

          SizedBox(width: 8.w),

          Text(
            title,

            style: TextStyle(
              color: Colors.white,

              fontSize: 14.sp,

              fontWeight:
                  FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// ===============================
  /// INFO TILE
  /// ===============================
  Widget _infoTile(
    IconData icon,
    String title,
    String value,
    Color accent,
  ) {

    return Row(
      children: [

        Container(
          width: 52.w,
          height: 52.w,

          decoration: BoxDecoration(
            shape: BoxShape.circle,

            color: accent.withOpacity(
              0.18,
            ),
          ),

          child: Icon(
            icon,
            color: accent,
            size: 24.sp,
          ),
        ),

        SizedBox(width: 16.w),

        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment
                    .start,

            children: [

              Text(
                title,

                style: TextStyle(
                  color:
                      Colors.white70,

                  fontSize: 14.sp,
                ),
              ),

              SizedBox(height: 4.h),

              Text(
                value,

                overflow:
                    TextOverflow.ellipsis,

                style: TextStyle(
                  color: Colors.white,

                  fontSize: 18.sp,

                  fontWeight:
                      FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// ===============================
  /// STORAGE BAR
  /// ===============================
  Widget _storageBar(
    String title,
    double value,
    Color accent,
  ) {

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,

      children: [

        Row(
          mainAxisAlignment:
              MainAxisAlignment
                  .spaceBetween,

          children: [

            Text(
              title,

              style: TextStyle(
                color: Colors.white,

                fontSize: 16.sp,

                fontWeight:
                    FontWeight.w600,
              ),
            ),

            Text(
              '${(value * 100).toInt()}%',

              style: TextStyle(
                color: accent,

                fontSize: 15.sp,

                fontWeight:
                    FontWeight.bold,
              ),
            ),
          ],
        ),

        SizedBox(height: 12.h),

        ClipRRect(
          borderRadius:
              BorderRadius.circular(
                30.r,
              ),

          child: LinearProgressIndicator(
            value: value,

            minHeight: 8.h,

            backgroundColor:
                Colors.white12,

            valueColor:
                AlwaysStoppedAnimation(
                  accent,
                ),
          ),
        ),
      ],
    );
  }

  /// ===============================
  /// CONNECTION TILE
  /// ===============================
  Widget _connectionTile(
    String title,
    bool active,
    Color accent,
  ) {

    return Row(
      children: [

        Container(
          width: 14.w,
          height: 14.w,

          decoration: BoxDecoration(
            shape: BoxShape.circle,

            color: active
                ? Colors.greenAccent
                : Colors.redAccent,

            boxShadow: [
              BoxShadow(
                color: active
                    ? Colors.greenAccent
                    : Colors.redAccent,

                blurRadius: 12,
              ),
            ],
          ),
        ),

        SizedBox(width: 16.w),

        Expanded(
          child: Text(
            title,

            style: TextStyle(
              color: Colors.white,

              fontSize: 16.sp,

              fontWeight:
                  FontWeight.w600,
            ),
          ),
        ),

        Text(
          active
              ? 'Active'
              : 'Offline',

          style: TextStyle(
            color:
                active
                ? accent
                : Colors.redAccent,

            fontSize: 15.sp,

            fontWeight:
                FontWeight.bold,
          ),
        ),
      ],
    );
  }

  /// ===============================
  /// ACTION BUTTON
  /// ===============================
  Widget _actionButton({
    required String title,
    required IconData icon,
    required Color accent,
    required VoidCallback onTap,
    bool loading = false,
  }) {

    return GestureDetector(
      onTap: loading
          ? null
          : onTap,

      child: AnimatedContainer(
        duration: const Duration(
          milliseconds: 250,
        ),

        height: 82.h,

        decoration: BoxDecoration(
          borderRadius:
              BorderRadius.circular(
                28.r,
              ),

          color: Colors.white
              .withOpacity(0.05),

          border: Border.all(
            color: accent.withOpacity(
              0.25,
            ),
          ),

          boxShadow: [
            BoxShadow(
              color: accent.withOpacity(
                0.14,
              ),

              blurRadius: 20,
            ),
          ],
        ),

        child: Row(
          mainAxisAlignment:
              MainAxisAlignment.center,

          children: [

            loading
                ? SizedBox(
                    width: 24.w,
                    height: 24.w,

                    child:
                        CircularProgressIndicator(
                          strokeWidth: 2,

                          valueColor:
                              AlwaysStoppedAnimation(
                                accent,
                              ),
                        ),
                  )
                : Icon(
                    icon,
                    color: accent,
                    size: 28.sp,
                  ),

            SizedBox(width: 14.w),

            Text(
              loading
                  ? 'Connecting...'
                  : title,

              style: TextStyle(
                color: Colors.white,

                fontSize: 18.sp,

                fontWeight:
                    FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}