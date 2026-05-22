import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:frontend/core/navigation/drowsiness_control.dart';
import 'package:frontend/core/themes/car_theme.dart';


class SettingsContent extends StatefulWidget {
  const SettingsContent({super.key});

  @override
  State<SettingsContent> createState() =>
      _SettingsPageState();
}

class _SettingsPageState
    extends State<SettingsContent> {
  bool potholeEnabled =
      true;

  String selectedLanguage =
      'English';

  @override
  Widget build(
    BuildContext context,
  ) {

    final currentTheme =
        CarThemes.currentTheme
            .value;

    final theme =
        CarThemes.getTheme(
      currentTheme,
    );

    final accentColor =

        currentTheme ==
                CarThemeType
                    .comfort

            ? const Color(
                0xFF6CB4FF,
              )

            : theme.accentColor;

    return Scaffold(

      backgroundColor:
          Colors.black,

      body: Container(

        width: double.infinity,
        height: double.infinity,

        decoration: BoxDecoration(

          gradient:
              LinearGradient(

            begin:
                Alignment.topLeft,

            end:
                Alignment.bottomRight,

            colors:
                theme
                    .backgroundGradient,
          ),
        ),

        child: SafeArea(

          child: Padding(

            padding:
                EdgeInsets.all(
              24.w,
            ),

            child: Row(

              children: [

                /// =========================
                /// CONTENT
                /// =========================
                Expanded(

                  child: Container(

                    padding:
                        EdgeInsets.all(
                      30.w,
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

                      border: Border.all(

                        color: Colors
                            .white
                            .withOpacity(
                          0.08,
                        ),
                      ),

                      boxShadow: [

                        BoxShadow(

                          color:
                              accentColor
                                  .withOpacity(
                            0.08,
                          ),

                          blurRadius:
                              30,

                          spreadRadius:
                              2,
                        ),
                      ],
                    ),

                    child: Column(

                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,

                      children: [

                        /// =========================
                        /// HEADER
                        /// =========================
                        Row(

                          children: [

                            Container(

                              width: 64.w,
                              height: 64.w,

                              decoration:
                                  BoxDecoration(

                                shape:
                                    BoxShape.circle,

                                color:
                                    accentColor,

                                boxShadow: [

                                  BoxShadow(

                                    color:
                                        accentColor
                                            .withOpacity(
                                      0.4,
                                    ),

                                    blurRadius:
                                        25,
                                  ),
                                ],
                              ),

                              child:
                                  Icon(

                                Icons.settings,

                                color:
                                    Colors.white,

                                size:
                                    30.sp,
                              ),
                            ),

                            SizedBox(
                              width: 18.w,
                            ),

                            Column(

                              crossAxisAlignment:
                                  CrossAxisAlignment.start,

                              children: [

                                Text(

                                  'Settings',

                                  style:
                                      TextStyle(

                                    color:
                                        Colors.white,

                                    fontSize:
                                        38.sp,

                                    fontWeight:
                                        FontWeight.bold,
                                  ),
                                ),

                                SizedBox(
                                  height:
                                      4.h,
                                ),

                                Text(

                                  'Smart Vehicle Features',

                                  style:
                                      TextStyle(

                                    color: Colors
                                        .white
                                        .withOpacity(
                                      0.6,
                                    ),

                                    fontSize:
                                        18.sp,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),

                        SizedBox(
                          height: 40.h,
                        ),

                        /// =========================
                        /// DROWSINESS
                        /// =========================
                        ValueListenableBuilder(
                          valueListenable:
                              DrowsinessControl
                                  .enabled,
                          builder: (
                            context,
                            drowsinessEnabled,
                            _,
                          ) {
                            return buildFeatureCard(

                              icon:
                                  Icons
                                      .bedtime_rounded,

                              title:
                                  'Drowsiness Alert',

                              description:
                                  'Aktifkan fitur untuk mendeteksi kantuk dan memberi peringatan otomatis.',

                              value:
                                  drowsinessEnabled,

                              accentColor:
                                  accentColor,

                              onChanged:
                                  (value) {
                                DrowsinessControl
                                        .enabled
                                        .value =
                                    value;
                              },
                            );
                          },
                        ),

                        SizedBox(
                          height: 24.h,
                        ),

                        /// =========================
                        /// POTHOLE
                        /// =========================
                        buildFeatureCard(

                          icon:
                              Icons
                                  .traffic_rounded,

                          title:
                              'Pothole Detection',

                          description:
                              'Deteksi lubang jalan secara realtime dan tampilkan notifikasi bahaya.',

                          value:
                              potholeEnabled,

                          accentColor:
                              accentColor,

                          onChanged:
                              (value) {

                            setState(() {

                              potholeEnabled =
                                  value;
                            });
                          },
                        ),

                        SizedBox(
                          height: 24.h,
                        ),

                        /// =========================
                        /// LANGUAGE
                        /// =========================
                        Container(

                          padding:
                              EdgeInsets.all(
                            24.w,
                          ),

                          decoration:
                              BoxDecoration(

                            borderRadius:
                                BorderRadius.circular(
                              30.r,
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
                                0.06,
                              ),
                            ),
                          ),

                          child: Row(

                            children: [

                              /// ICON
                              Container(

                                width: 72.w,
                                height: 72.w,

                                decoration:
                                    BoxDecoration(

                                  shape:
                                      BoxShape.circle,

                                  color:
                                      accentColor
                                          .withOpacity(
                                    0.15,
                                  ),
                                ),

                                child:
                                    Icon(

                                  Icons.language,

                                  color:
                                      accentColor,

                                  size:
                                      34.sp,
                                ),
                              ),

                              SizedBox(
                                width: 20.w,
                              ),

                              /// TEXT
                              Expanded(

                                child:
                                    Column(

                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,

                                  children: [

                                    Text(

                                      'Language',

                                      style:
                                          TextStyle(

                                        color:
                                            Colors.white,

                                        fontSize:
                                            26.sp,

                                        fontWeight:
                                            FontWeight.bold,
                                      ),
                                    ),

                                    SizedBox(
                                      height:
                                          6.h,
                                    ),

                                    Text(

                                      'Pilih bahasa sistem infotainment.',

                                      style:
                                          TextStyle(

                                        color: Colors
                                            .white
                                            .withOpacity(
                                          0.55,
                                        ),

                                        fontSize:
                                            16.sp,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              /// BUTTONS
                              Container(

                                padding:
                                    EdgeInsets.all(
                                  6.w,
                                ),

                                decoration:
                                    BoxDecoration(

                                  borderRadius:
                                      BorderRadius.circular(
                                    20.r,
                                  ),

                                  color: Colors
                                      .white
                                      .withOpacity(
                                    0.06,
                                  ),
                                ),

                                child: Row(

                                  children: [

                                    buildLanguageButton(

                                      title:
                                          'English',

                                      isSelected:
                                          selectedLanguage ==
                                              'English',

                                      accentColor:
                                          accentColor,

                                      onTap:
                                          () {

                                        setState(() {

                                          selectedLanguage =
                                              'English';
                                        });
                                      },
                                    ),

                                    SizedBox(
                                      width:
                                          10.w,
                                    ),

                                    buildLanguageButton(

                                      title:
                                          'Bahasa',

                                      isSelected:
                                          selectedLanguage ==
                                              'Bahasa',

                                      accentColor:
                                          accentColor,

                                      onTap:
                                          () {

                                        setState(() {

                                          selectedLanguage =
                                              'Bahasa';
                                        });
                                      },
                                    ),
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
          ),
        ),
      ),
    );
  }

  /// =========================
  /// FEATURE CARD
  /// =========================
  Widget buildFeatureCard({

    required IconData icon,
    required String title,
    required String description,
    required bool value,
    required Color accentColor,
    required Function(bool)
        onChanged,
  }) {

    return AnimatedContainer(

      duration:
          const Duration(
        milliseconds: 250,
      ),

      padding:
          EdgeInsets.all(
        24.w,
      ),

      decoration:
          BoxDecoration(

        borderRadius:
            BorderRadius.circular(
          30.r,
        ),

        color: Colors.white
            .withOpacity(
          0.05,
        ),

        border: Border.all(

          color: value

              ? accentColor
                  .withOpacity(
                0.25,
              )

              : Colors.white
                  .withOpacity(
                0.06,
              ),
        ),

        boxShadow: [

          if (value)

            BoxShadow(

              color:
                  accentColor
                      .withOpacity(
                0.18,
              ),

              blurRadius: 25,
              spreadRadius: 2,
            ),
        ],
      ),

      child: Row(

        children: [

          /// ICON
          Container(

            width: 72.w,
            height: 72.w,

            decoration:
                BoxDecoration(

              shape:
                  BoxShape.circle,

              color:
                  accentColor
                      .withOpacity(
                0.15,
              ),
            ),

            child: Icon(

              icon,

              color:
                  accentColor,

              size: 34.sp,
            ),
          ),

          SizedBox(
            width: 20.w,
          ),

          /// TEXT
          Expanded(

            child: Column(

              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,

              children: [

                Text(

                  title,

                  style:
                      TextStyle(

                    color:
                        Colors.white,

                    fontSize:
                        26.sp,

                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                SizedBox(
                  height: 8.h,
                ),

                Text(

                  description,

                  style:
                      TextStyle(

                    color: Colors
                        .white
                        .withOpacity(
                      0.55,
                    ),

                    fontSize:
                        16.sp,

                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(
            width: 20.w,
          ),

          /// SWITCH
          Switch(

            value: value,

            activeColor:
                accentColor,

            onChanged:
                onChanged,
          ),
        ],
      ),
    );
  }

  /// =========================
  /// LANGUAGE BUTTON
  /// =========================
  Widget buildLanguageButton({

    required String title,
    required bool isSelected,
    required Color accentColor,
    required VoidCallback onTap,
  }) {

    return GestureDetector(

      onTap: onTap,

      child: AnimatedContainer(

        duration:
            const Duration(
          milliseconds: 250,
        ),

        padding:
            EdgeInsets.symmetric(

          horizontal: 22.w,
          vertical: 14.h,
        ),

        decoration:
            BoxDecoration(

          borderRadius:
              BorderRadius.circular(
            16.r,
          ),

          color: isSelected

              ? accentColor

              : Colors.transparent,

          boxShadow: [

            if (isSelected)

              BoxShadow(

                color:
                    accentColor
                        .withOpacity(
                  0.35,
                ),

                blurRadius: 18,
              ),
          ],
        ),

        child: Text(

          title,

          style: TextStyle(

            color:
                Colors.white,

            fontSize: 16.sp,

            fontWeight:
                FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
