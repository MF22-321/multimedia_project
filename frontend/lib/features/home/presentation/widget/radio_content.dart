import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:media_kit/media_kit.dart';

import '../../../../core/themes/car_theme.dart';

class RadioContent extends StatefulWidget {
  const RadioContent({super.key});

  @override
  State<RadioContent> createState() => _RadioContentState();
}

class _RadioContentState extends State<RadioContent> {
  /// =========================
  /// MEDIA KIT PLAYER
  /// =========================
  final Player player = Player(
    configuration: const PlayerConfiguration(bufferSize: 32 * 1024 * 1024),
  );

  bool isPlaying = false;

  int currentIndex = 0;

  /// =========================
  /// RADIO STATIONS
  /// =========================
  final List<Map<String, dynamic>> stations = [
    {
      'name': 'Groove Salad',

      'subtitle': 'Ambient Radio',

      'image': 'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f',

      'url': 'https://ice1.somafm.com/groovesalad-128-mp3',
    },

    {
      'name': 'Lofi Girl',

      'subtitle': 'Chill Beats Radio',

      'image': 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4',

      'url': 'https://play.streamafrica.net/lofiradio',
    },

    {
      'name': 'Jazz24',

      'subtitle': 'Smooth Jazz Live',

      'image': 'https://images.unsplash.com/photo-1511192336575-5a79af67a629',

      'url': 'https://live.wostreaming.net/direct/ppm-jazz24mp3-ibc1',
    },

    {
      'name': 'Drone Zone',

      'subtitle': 'Space Ambient',

      'image': 'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee',

      'url': 'https://ice1.somafm.com/dronezone-128-mp3',
    },

    {
      'name': 'Deep House',

      'subtitle': 'Electronic Radio',

      'image': 'https://images.unsplash.com/photo-1501386761578-eac5c94b800a',

      'url': 'https://uk2.internet-radio.com/proxy/danceradiouk?mp=/stream',
    },
    {
      'name': 'Prambors FM',
      'subtitle': 'Indonesia Hits Music',
      'image': 'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f',
      'url': 'https://23683.live.streamtheworld.com/PRAMBORS_FM.mp3',
    },

    {
      'name': 'Hard Rock FM',
      'subtitle': 'Lifestyle & Hits',
      'image': 'https://images.unsplash.com/photo-1501386761578-eac5c94b800a',
      'url': 'https://n0e.radiojar.com/7csmg90fuqruv',
    },

    {
      'name': 'Gen FM',
      'subtitle': 'Suara Musik Terkini',
      'image': 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4',
      'url': 'https://stream.radiojar.com/4ywdgup3bnzuv',
    },

    {
      'name': 'Motion Radio',
      'subtitle': 'Feel The Beat',
      'image': 'https://images.unsplash.com/photo-1511192336575-5a79af67a629',
      'url': 'https://stream.radiojar.com/kw89u0d3bnzuv',
    },

    {
      'name': 'Elshinta',
      'subtitle': 'News & Talk Radio',
      'image': 'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee',
      'url': 'https://stream-ssl.arenastreaming.com:8000/jakarta',
    },

    {
      'name': 'Ardan Radio',
      'subtitle': 'Bandung Hits Station',
      'image': 'https://images.unsplash.com/photo-1521334884684-d80222895322',
      'url': 'https://stream.radiojar.com/ardanfm',
    },

    {
      'name': 'Oz Radio',
      'subtitle': 'Young & Fresh Hits',
      'image': 'https://images.unsplash.com/photo-1506157786151-b8491531f063',
      'url': 'https://stream.radiojar.com/ozradio',
    },
  ];

  /// =========================
  /// INIT
  /// =========================
  @override
  void initState() {
    super.initState();

    /// AUTO PLAY FIRST STATION
    playStation(0);
  }

  /// =========================
  /// PLAY STATION
  /// =========================
  Future<void> playStation(int index) async {
    try {
      currentIndex = index;

      final station = stations[index];

      print('PLAYING => ${station['name']}');

      print('URL => ${station['url']}');

      await player.open(Media(station['url']), play: false);

      await Future.delayed(const Duration(seconds: 2));

      player.play();

      await player.setVolume(100);

      setState(() {
        isPlaying = true;
      });
    } catch (e) {
      debugPrint('RADIO ERROR => $e');
    }
  }

  /// =========================
  /// PLAY / PAUSE
  /// =========================
  Future<void> togglePlay() async {
    if (isPlaying) {
      player.pause();
    } else {
      player.play();
    }

    setState(() {
      isPlaying = !isPlaying;
    });
  }

  /// =========================
  /// NEXT STATION
  /// =========================
  Future<void> nextStation() async {
    int next = currentIndex + 1;

    if (next >= stations.length) {
      next = 0;
    }

    await playStation(next);
  }

  /// =========================
  /// PREVIOUS STATION
  /// =========================
  Future<void> previousStation() async {
    int prev = currentIndex - 1;

    if (prev < 0) {
      prev = stations.length - 1;
    }

    await playStation(prev);
  }

  /// =========================
  /// DISPOSE
  /// =========================
  @override
  void dispose() {
    player.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentTheme = CarThemes.currentTheme.value;

    final theme = CarThemes.getTheme(currentTheme);

    final accentColor = currentTheme == CarThemeType.comfort
        ? const Color(0xFF6CB4FF)
        : theme.accentColor;

    final currentStation = stations[currentIndex];

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
                /// LEFT PANEL
                /// =========================
                Expanded(
                  flex: 3,

                  child: Container(
                    padding: EdgeInsets.all(24.w),

                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(40.r),

                      color: Colors.white.withOpacity(0.05),

                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                    ),

                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [
                        /// =========================
                        /// HEADER
                        /// =========================
                        /// =========================
                        /// HEADER
                        /// =========================
                        Row(
                          children: [
                            /// BACK BUTTON
                            GestureDetector(
                              onTap: () {
                                Navigator.pop(context);
                              },

                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 250),

                                width: 58.w,
                                height: 58.w,

                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,

                                  color: Colors.white.withOpacity(0.06),

                                  border: Border.all(
                                    color: accentColor.withOpacity(0.25),
                                  ),

                                  boxShadow: [
                                    BoxShadow(
                                      color: accentColor.withOpacity(0.12),

                                      blurRadius: 18,
                                    ),
                                  ],
                                ),

                                child: Icon(
                                  Icons.arrow_back_ios_new,

                                  color: accentColor,

                                  size: 24.sp,
                                ),
                              ),
                            ),

                            SizedBox(width: 18.w),

                            /// RADIO ICON
                            Container(
                              width: 60.w,
                              height: 60.w,

                              decoration: BoxDecoration(
                                shape: BoxShape.circle,

                                color: accentColor,

                                boxShadow: [
                                  BoxShadow(
                                    color: accentColor.withOpacity(0.45),

                                    blurRadius: 20,
                                  ),
                                ],
                              ),

                              child: Icon(
                                Icons.radio,

                                color: Colors.white,

                                size: 30.sp,
                              ),
                            ),

                            SizedBox(width: 18.w),

                            /// TITLE
                            Text(
                              'Radio',

                              style: TextStyle(
                                color: Colors.white,

                                fontSize: 38.sp,

                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: 34.h),

                        Text(
                          'Live Stations',

                          style: TextStyle(
                            color: Colors.white,

                            fontSize: 24.sp,

                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        SizedBox(height: 24.h),

                        /// =========================
                        /// STATION LIST
                        /// =========================
                        Expanded(
                          child: ListView.builder(
                            physics: const BouncingScrollPhysics(),

                            itemCount: stations.length,

                            itemBuilder: (context, index) {
                              final station = stations[index];

                              final active = index == currentIndex;

                              return GestureDetector(
                                onTap: () {
                                  playStation(index);
                                },

                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 250),

                                  margin: EdgeInsets.only(bottom: 18.h),

                                  padding: EdgeInsets.all(18.w),

                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(28.r),

                                    color: active
                                        ? accentColor.withOpacity(0.12)
                                        : Colors.white.withOpacity(0.04),

                                    border: Border.all(
                                      color: active
                                          ? accentColor.withOpacity(0.35)
                                          : Colors.white.withOpacity(0.06),
                                    ),

                                    boxShadow: [
                                      if (active)
                                        BoxShadow(
                                          color: accentColor.withOpacity(0.18),

                                          blurRadius: 24,
                                        ),
                                    ],
                                  ),

                                  child: Row(
                                    children: [
                                      /// IMAGE
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(
                                          18.r,
                                        ),

                                        child: Image.network(
                                          station['image'],

                                          width: 78.w,

                                          height: 78.w,

                                          fit: BoxFit.cover,
                                        ),
                                      ),

                                      SizedBox(width: 16.w),

                                      /// TEXT
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,

                                          children: [
                                            Text(
                                              station['name'],

                                              style: TextStyle(
                                                color: Colors.white,

                                                fontSize: 22.sp,

                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),

                                            SizedBox(height: 6.h),

                                            Text(
                                              station['subtitle'],

                                              style: TextStyle(
                                                color: Colors.white.withOpacity(
                                                  0.6,
                                                ),

                                                fontSize: 15.sp,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      /// LIVE
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 12.w,

                                          vertical: 6.h,
                                        ),

                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            12.r,
                                          ),

                                          color: accentColor,
                                        ),

                                        child: Text(
                                          'LIVE',

                                          style: TextStyle(
                                            color: Colors.white,

                                            fontSize: 12.sp,

                                            fontWeight: FontWeight.bold,
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

                SizedBox(width: 24.w),

                /// =========================
                /// RIGHT PANEL
                /// =========================
                Expanded(
                  flex: 4,

                  child: Container(
                    padding: EdgeInsets.all(28.w),

                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(40.r),

                      color: Colors.white.withOpacity(0.05),

                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                    ),

                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,

                      children: [
                        /// =========================
                        /// RADIO IMAGE
                        /// =========================
                        Container(
                          width: 300.w,
                          height: 300.w,

                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(40.r),

                            boxShadow: [
                              BoxShadow(
                                color: accentColor.withOpacity(0.35),

                                blurRadius: 35,
                              ),
                            ],
                          ),

                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(40.r),

                            child: Image.network(
                              currentStation['image'],

                              fit: BoxFit.cover,
                            ),
                          ),
                        ),

                        SizedBox(height: 34.h),

                        /// =========================
                        /// TITLE
                        /// =========================
                        Text(
                          currentStation['name'],

                          style: TextStyle(
                            color: Colors.white,

                            fontSize: 38.sp,

                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        SizedBox(height: 10.h),

                        Text(
                          currentStation['subtitle'],

                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),

                            fontSize: 20.sp,
                          ),
                        ),

                        SizedBox(height: 34.h),

                        /// =========================
                        /// LIVE STATUS
                        /// =========================
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,

                          children: [
                            Container(
                              width: 14.w,
                              height: 14.w,

                              decoration: BoxDecoration(
                                shape: BoxShape.circle,

                                color: Colors.redAccent,

                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.redAccent.withOpacity(0.45),

                                    blurRadius: 12,
                                  ),
                                ],
                              ),
                            ),

                            SizedBox(width: 12.w),

                            Text(
                              'LIVE STREAMING',

                              style: TextStyle(
                                color: Colors.white,

                                fontSize: 16.sp,

                                letterSpacing: 2,

                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: 48.h),

                        /// =========================
                        /// CONTROLS
                        /// =========================
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,

                          children: [
                            /// PREVIOUS
                            buildControlButton(
                              icon: Icons.skip_previous,

                              accentColor: accentColor,

                              onTap: previousStation,
                            ),

                            SizedBox(width: 28.w),

                            /// PLAY
                            GestureDetector(
                              onTap: togglePlay,

                              child: Container(
                                width: 110.w,
                                height: 110.w,

                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,

                                  color: accentColor,

                                  boxShadow: [
                                    BoxShadow(
                                      color: accentColor.withOpacity(0.45),

                                      blurRadius: 28,
                                    ),
                                  ],
                                ),

                                child: Icon(
                                  isPlaying ? Icons.pause : Icons.play_arrow,

                                  color: Colors.white,

                                  size: 52.sp,
                                ),
                              ),
                            ),

                            SizedBox(width: 28.w),

                            /// NEXT
                            buildControlButton(
                              icon: Icons.skip_next,

                              accentColor: accentColor,

                              onTap: nextStation,
                            ),
                          ],
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
  /// CONTROL BUTTON
  /// =========================
  Widget buildControlButton({
    required IconData icon,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,

      child: Container(
        width: 82.w,
        height: 82.w,

        decoration: BoxDecoration(
          shape: BoxShape.circle,

          color: Colors.white.withOpacity(0.06),

          border: Border.all(color: accentColor.withOpacity(0.25)),
        ),

        child: Icon(icon, color: accentColor, size: 38.sp),
      ),
    );
  }
}
