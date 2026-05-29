import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:frontend/core/navigation/app_navigation.dart';
import 'package:frontend/core/provider/music_provider.dart';
import 'package:frontend/core/themes/car_theme.dart';
import 'package:provider/provider.dart';

class MediaCard extends StatelessWidget {
  const MediaCard({super.key});

  @override
  Widget build(BuildContext context) {
    final musicProvider = Provider.of<MusicProvider>(context);

    return ValueListenableBuilder(
      valueListenable: CarThemes.currentTheme,
      builder: (context, themeType, _) {
        return ValueListenableBuilder(
          valueListenable: CarThemes.customTheme,
          builder: (context, __, ___) {
            final theme = CarThemes.getTheme(themeType);

            final Color playButtonColor = themeType == CarThemeType.comfort
                ? Colors.grey.shade600
                : theme.buttonColor;

            return GestureDetector(
          /// OPEN MUSIC PAGE
          onTap: () {
            /// PINDAH SIDEBAR + PAGE
            AppNavigation.currentIndex.value = 0;
          },

          child: AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            height: 130.h,
            padding: EdgeInsets.symmetric(horizontal: 20.w),

            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(25.r),

              gradient: LinearGradient(
                colors: [
                  theme.backgroundGradient.last.withValues(alpha: 0.9),

                  Colors.black.withValues(alpha: 0.6),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),

              border: Border.all(
                color: theme.accentColor.withValues(alpha: 0.4),
                width: 2,
              ),

              boxShadow: [
                BoxShadow(
                  color: theme.accentColor.withValues(alpha: 0.25),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),

            child: Row(
              children: [
                /// ALBUM COVER
                Hero(
                  tag: 'album_art',

                  child: Container(
                    width: 90.w,
                    height: 90.w,

                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15.r),

                      image: DecorationImage(
                        image: musicProvider.albumArt.isNotEmpty
                            ? NetworkImage(musicProvider.albumArt)
                            : const AssetImage("assets/images/weekend.png")
                                  as ImageProvider,

                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),

                SizedBox(width: 20.w),

                /// SONG INFO
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,

                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [
                      /// SONG TITLE
                      Text(
                        musicProvider.title,

                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,

                        style: TextStyle(
                          color: theme.textColor,
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      SizedBox(height: 4.h),

                      /// ARTIST
                      Text(
                        musicProvider.artist,

                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,

                        style: TextStyle(
                          color: theme.textColor.withValues(alpha: 0.7),

                          fontSize: 14.sp,
                        ),
                      ),

                      SizedBox(height: 12.h),

                      /// PROGRESS BAR
                      /// ===============================
                      /// PROGRESS BAR
                      /// ===============================
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          /// TIME
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,

                            children: [
                              Text(
                                formatDuration(musicProvider.currentPosition),

                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),

                              Text(
                                formatDuration(musicProvider.totalDuration),

                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),

                          SizedBox(height: 8.h),

                          SliderTheme(
                            data: SliderThemeData(
                              trackHeight: 4.h,

                              thumbShape: RoundSliderThumbShape(
                                enabledThumbRadius: 5.r,
                              ),

                              overlayShape: SliderComponentShape.noOverlay,

                              inactiveTrackColor: Colors.white.withValues(
                                alpha: 0.15,
                              ),

                              activeTrackColor:
                                  themeType == CarThemeType.comfort
                                  ? const Color(0xFF6CB4FF)
                                  : theme.accentColor,

                              thumbColor: themeType == CarThemeType.comfort
                                  ? const Color(0xFF6CB4FF)
                                  : theme.accentColor,
                            ),

                            child: Slider(
                              value:
                                  musicProvider.totalDuration.inMilliseconds ==
                                      0
                                  ? 0
                                  : (musicProvider
                                                .currentPosition
                                                .inMilliseconds /
                                            musicProvider
                                                .totalDuration
                                                .inMilliseconds)
                                        .clamp(0.0, 1.0),

                              onChanged: (value) {},

                              onChangeEnd: (value) async {
                                await musicProvider.seekTo(value);
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                /// CONTROLS
                Row(
                  children: [
                    /// PREVIOUS
                    GestureDetector(
                      onTap: () async {
                        await musicProvider.previous();
                      },

                      child: Icon(
                        Icons.skip_previous,
                        color: theme.textColor,
                        size: 30.sp,
                      ),
                    ),

                    SizedBox(width: 10.w),

                    /// PLAY / PAUSE
                    GestureDetector(
                      onTap: () async {
                        await musicProvider.togglePlay();
                      },

                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),

                        width: 50.w,
                        height: 50.w,

                        decoration: BoxDecoration(
                          color: playButtonColor,
                          shape: BoxShape.circle,

                          boxShadow: [
                            BoxShadow(
                              color: playButtonColor.withValues(alpha: 0.4),

                              blurRadius: 12,
                            ),
                          ],
                        ),

                        child: Icon(
                          musicProvider.isPlaying
                              ? Icons.pause
                              : Icons.play_arrow,

                          color: Colors.white,
                          size: 28.sp,
                        ),
                      ),
                    ),

                    SizedBox(width: 10.w),

                    /// NEXT
                    GestureDetector(
                      onTap: () async {
                        await musicProvider.next();
                      },

                      child: Icon(
                        Icons.skip_next,
                        color: theme.textColor,
                        size: 30.sp,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
            );
          },
        );
      },
    );
  }
}

String formatDuration(Duration d) {
  String twoDigits(int n) => n.toString().padLeft(2, '0');

  final minutes = twoDigits(d.inMinutes.remainder(60));

  final seconds = twoDigits(d.inSeconds.remainder(60));

  return '$minutes:$seconds';
}
