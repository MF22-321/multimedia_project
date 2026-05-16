import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:frontend/core/provider/music_provider.dart';
import 'package:frontend/core/services/spotify_search_service.dart';
import 'package:frontend/core/themes/car_theme.dart';
import 'package:provider/provider.dart';

class MusicPage extends StatefulWidget {
  const MusicPage({super.key});

  @override
  State<MusicPage> createState() => _MusicPageState();
}

/// ===============================
/// MUSIC ACCENT COLOR
/// ===============================
Color getMusicAccentColor(CarThemeType type, CarThemeData theme) {
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

class _MusicPageState extends State<MusicPage> {
  final TextEditingController _searchController = TextEditingController();

  final ScrollController _lyricsController = ScrollController();
  final List<GlobalKey> _lyricKeys = [];

  bool showLyrics = false;

  int _lastLyricIndex = -1;

  Timer? _searchDebounce;

  final SpotifySearchService spotifySearchService = SpotifySearchService();

  Map<String, dynamic> spotifyData = {};

  String selectedCategory = 'track';

  final List<Map<String, String>> recentSongs = [
    {
      'title': 'Save Your Tears',
      'artist': 'The Weeknd',
      'image':
          'https://i.scdn.co/image/ab67616d0000b273b5097b81179824803664aaaf',
    },
    {
      'title': 'Tie Me Down',
      'artist': 'Gryffin',
      'image':
          'https://i.scdn.co/image/ab67616d0000b2730e5311993a01fb2e7169f6a7',
    },
    {
      'title': 'Malibu Nights',
      'artist': 'LANY',
      'image':
          'https://i.scdn.co/image/ab67616d0000b273c4dae9528b2a8408f463eb17',
    },
  ];

  @override
  void dispose() {
    _lyricsController.dispose();

    _searchController.dispose();

    _searchDebounce?.cancel();

    super.dispose();
  }

  void autoScrollLyrics(MusicProvider musicProvider) {
    final index = musicProvider.currentLyricIndex;

    if (index < 0 || index >= _lyricKeys.length) {
      return;
    }

    final context = _lyricKeys[index].currentContext;

    if (context == null) return;

    Scrollable.ensureVisible(
      context,

      duration: const Duration(milliseconds: 600),

      alignment: 0.5,

      curve: Curves.easeOutCubic,
    );
  }

  /// ===============================
  /// SEARCH MUSIC
  /// ===============================
  Future<void> searchMusic(String query) async {
    try {
      if (query.isEmpty) {
        setState(() {
          spotifyData = {};
        });
        return;
      }

      final result = await spotifySearchService.search(query, selectedCategory);

      setState(() {
        spotifyData = result;
      });
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  /// ===============================
  /// PLAY SONG
  /// ===============================
  Future<void> playSpotifySong(String uri, MusicProvider musicProvider) async {
    try {
      await Process.run('spotify', ['--uri=$uri']);

      await Future.delayed(const Duration(milliseconds: 500));

      await musicProvider.play();
      musicProvider.startProgressListener();
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final musicProvider = Provider.of<MusicProvider>(context);

    while (_lyricKeys.length < musicProvider.syncedLyrics.length) {
      _lyricKeys.add(GlobalKey());
    }

    if (_lyricKeys.length > musicProvider.syncedLyrics.length) {
      _lyricKeys.removeRange(
        musicProvider.syncedLyrics.length,
        _lyricKeys.length,
      );
    }

    if (_lastLyricIndex != musicProvider.currentLyricIndex) {
      _lastLyricIndex = musicProvider.currentLyricIndex;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        autoScrollLyrics(musicProvider);
      });
    }

    return ValueListenableBuilder(
      valueListenable: CarThemes.currentTheme,
      builder: (context, themeType, _) {
        final theme = CarThemes.getTheme(themeType);

        final musicAccent = getMusicAccentColor(themeType, theme);

        return Padding(
          padding: EdgeInsets.all(30.w),

          child: ClipRRect(
            borderRadius: BorderRadius.circular(38.r),

            child: Stack(
              fit: StackFit.expand,

              children: [
                /// ===============================
                /// BACKGROUND
                /// ===============================
                AnimatedContainer(
                  duration: const Duration(milliseconds: 400),

                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: theme.backgroundGradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),

                /// ===============================
                /// GLOW
                /// ===============================
                Positioned(
                  right: -100.w,
                  top: 100.h,

                  child: Container(
                    width: 420.w,
                    height: 420.w,

                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: musicAccent.withOpacity(0.18),
                    ),
                  ),
                ),

                /// ===============================
                /// BLUR
                /// ===============================
                BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),

                  child: Container(color: Colors.black.withOpacity(0.15)),
                ),

                /// ===============================
                /// CONTENT
                /// ===============================
                Row(
                  children: [
                    /// ===============================
                    /// LEFT PANEL
                    /// ===============================
                    Container(
                      width: 360.w,

                      padding: EdgeInsets.all(26.w),

                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.03),

                        border: Border(
                          right: BorderSide(
                            color: Colors.white.withOpacity(0.06),
                          ),
                        ),
                      ),

                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,

                        children: [
                          /// TITLE
                          Row(
                            children: [
                              Icon(
                                Icons.music_note,
                                color: Colors.white,
                                size: 34.sp,
                              ),

                              SizedBox(width: 14.w),

                              Text(
                                'Music',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 30.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),

                          SizedBox(height: 26.h),

                          /// SEARCH
                          Container(
                            height: 58.h,

                            padding: EdgeInsets.symmetric(horizontal: 18.w),

                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.06),

                              borderRadius: BorderRadius.circular(20.r),
                            ),

                            child: Row(
                              children: [
                                Icon(
                                  Icons.search,
                                  color: Colors.white60,
                                  size: 24.sp,
                                ),

                                SizedBox(width: 12.w),

                                Expanded(
                                  child: TextField(
                                    controller: _searchController,

                                    onChanged: (value) {
                                      if (_searchDebounce?.isActive ?? false) {
                                        _searchDebounce?.cancel();
                                      }

                                      _searchDebounce = Timer(
                                        const Duration(milliseconds: 500),
                                        () {
                                          searchMusic(value);
                                        },
                                      );
                                    },

                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16.sp,
                                    ),

                                    decoration: const InputDecoration(
                                      border: InputBorder.none,
                                      hintText: 'Search music...',
                                      hintStyle: TextStyle(
                                        color: Colors.white54,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          SizedBox(height: 28.h),

                          /// CATEGORY
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,

                            child: Row(
                              children: [
                                _category('Songs', 'track', musicAccent),

                                _category('Artists', 'artist', musicAccent),

                                _category('Albums', 'album', musicAccent),

                                _category('Playlist', 'playlist', musicAccent),
                              ],
                            ),
                          ),

                          SizedBox(height: 30.h),

                          /// TITLE
                          Text(
                            spotifyData.isEmpty
                                ? 'Recently Played'
                                : 'Search Results',

                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          SizedBox(height: 18.h),

                          /// SONG LIST
                          Expanded(
                            child: ListView.builder(
                              physics: const BouncingScrollPhysics(),

                              itemCount: spotifyData.isEmpty
                                  ? recentSongs.length
                                  : selectedCategory == 'track'
                                  ? (spotifyData['tracks']?['items']?.length ??
                                        0)
                                  : selectedCategory == 'artist'
                                  ? (spotifyData['artists']?['items']?.length ??
                                        0)
                                  : selectedCategory == 'album'
                                  ? (spotifyData['albums']?['items']?.length ??
                                        0)
                                  : (spotifyData['playlists']?['items']
                                            ?.length ??
                                        0),

                              itemBuilder: (context, index) {
                                final song = spotifyData.isEmpty
                                    ? recentSongs[index]
                                    : selectedCategory == 'track'
                                    ? spotifyData['tracks']['items'][index]
                                    : selectedCategory == 'artist'
                                    ? spotifyData['artists']['items'][index]
                                    : selectedCategory == 'album'
                                    ? spotifyData['albums']['items'][index]
                                    : spotifyData['playlists']['items'][index];

                                final imageUrl = spotifyData.isEmpty
                                    ? song['image']
                                    : selectedCategory == 'track'
                                    ? (song['album']['images'] != null &&
                                              song['album']['images']
                                                  .isNotEmpty)
                                          ? song['album']['images'][0]['url']
                                          : ''
                                    : song['images'] != null &&
                                          song['images'].isNotEmpty
                                    ? song['images'][0]['url']
                                    : '';

                                final title = spotifyData.isEmpty
                                    ? song['title']
                                    : song['name'];

                                final subtitle = spotifyData.isEmpty
                                    ? song['artist']
                                    : selectedCategory == 'track'
                                    ? song['artists'][0]['name']
                                    : selectedCategory == 'artist'
                                    ? 'Artist'
                                    : selectedCategory == 'album'
                                    ? song['artists'][0]['name']
                                    : 'Playlist';

                                return Container(
                                  margin: EdgeInsets.only(bottom: 16.h),

                                  padding: EdgeInsets.symmetric(
                                    horizontal: 16.w,
                                    vertical: 12.h,
                                  ),

                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.05),

                                    borderRadius: BorderRadius.circular(24.r),
                                  ),

                                  child: Row(
                                    children: [
                                      /// IMAGE
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(
                                          18.r,
                                        ),

                                        child: imageUrl.isNotEmpty
                                            ? Image.network(
                                                imageUrl,
                                                width: 68.w,
                                                height: 68.w,
                                                fit: BoxFit.cover,
                                              )
                                            : Container(
                                                width: 68.w,
                                                height: 68.w,
                                                color: Colors.white10,

                                                child: Icon(
                                                  Icons.music_note,
                                                  color: Colors.white,
                                                  size: 30.sp,
                                                ),
                                              ),
                                      ),

                                      SizedBox(width: 16.w),

                                      /// INFO
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,

                                          children: [
                                            Text(
                                              title,

                                              maxLines: 1,

                                              overflow: TextOverflow.ellipsis,

                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 17.sp,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),

                                            SizedBox(height: 6.h),

                                            Text(
                                              subtitle,

                                              style: TextStyle(
                                                color: Colors.white60,
                                                fontSize: 14.sp,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      /// PLAY
                                      GestureDetector(
                                        onTap: () async {
                                          if (spotifyData.isNotEmpty &&
                                              selectedCategory == 'track') {
                                            final uri = song['uri'];

                                            await playSpotifySong(
                                              uri,
                                              musicProvider,
                                            );
                                          }
                                        },

                                        child: Container(
                                          width: 46.w,
                                          height: 46.w,

                                          decoration: BoxDecoration(
                                            color: musicAccent,

                                            shape: BoxShape.circle,

                                            boxShadow: [
                                              BoxShadow(
                                                color: musicAccent.withOpacity(
                                                  0.4,
                                                ),
                                                blurRadius: 16,
                                              ),
                                            ],
                                          ),

                                          child: Icon(
                                            Icons.play_arrow,
                                            color: Colors.white,
                                            size: 28.sp,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),

                    /// RIGHT CONTENT
                    /// ===============================
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 40.w,
                          vertical: 28.h,
                        ),

                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            /// TITLE
                            Text(
                              'Now Playing',

                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 26.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            SizedBox(height: 24.h),

                            /// CENTER CONTENT
                            Flexible(
                              child: Center(
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 450),

                                  switchInCurve: Curves.easeOutCubic,
                                  switchOutCurve: Curves.easeInCubic,

                                  transitionBuilder: (child, animation) {
                                    return FadeTransition(
                                      opacity: animation,

                                      child: SlideTransition(
                                        position: Tween<Offset>(
                                          begin: const Offset(0, 0.08),
                                          end: Offset.zero,
                                        ).animate(animation),

                                        child: child,
                                      ),
                                    );
                                  },

                                  /// =========================
                                  /// LYRICS MODE
                                  /// =========================
                                  child: showLyrics
                                      ? SizedBox(
                                          key: const ValueKey('lyrics'),

                                          width: 620.w,

                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,

                                            children: [
                                              /// HEADER
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,

                                                children: [],
                                              ),

                                              SizedBox(height: 10.h),

                                              /// TITLE
                                              Text(
                                                musicProvider.title,

                                                maxLines: 1,

                                                overflow: TextOverflow.ellipsis,

                                                textAlign: TextAlign.center,

                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 24.sp,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),

                                              SizedBox(height: 8.h),

                                              /// ARTIST
                                              Text(
                                                musicProvider.artist,

                                                style: TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 18.sp,
                                                ),
                                              ),

                                              SizedBox(height: 24.h),

                                              /// LYRICS FIXED
                                              Expanded(
                                                child: SizedBox(
                                                  height: 340.h,

                                                  child: ClipRect(
                                                    child: ShaderMask(
                                                      shaderCallback: (rect) {
                                                        return LinearGradient(
                                                          begin: Alignment
                                                              .topCenter,

                                                          end: Alignment
                                                              .bottomCenter,

                                                          colors: [
                                                            Colors.transparent,
                                                            Colors.white,
                                                            Colors.white,
                                                            Colors.transparent,
                                                          ],

                                                          stops: const [
                                                            0.0,
                                                            0.08,
                                                            0.92,
                                                            1.0,
                                                          ],
                                                        ).createShader(rect);
                                                      },

                                                      blendMode:
                                                          BlendMode.dstIn,

                                                      child: ListView.builder(
                                                        controller:
                                                            _lyricsController,

                                                        padding:
                                                            EdgeInsets.symmetric(
                                                              vertical: 70.h,
                                                            ),

                                                        physics:
                                                            const BouncingScrollPhysics(),
                                                        itemCount: musicProvider
                                                            .syncedLyrics
                                                            .length,

                                                        itemBuilder: (context, index) {
                                                          final lyric =
                                                              musicProvider
                                                                  .syncedLyrics[index];

                                                          final active =
                                                              index ==
                                                              musicProvider
                                                                  .currentLyricIndex;

                                                          return AnimatedContainer(
                                                            key: _lyricKeys[index],
                                                            duration:
                                                                const Duration(
                                                                  milliseconds:
                                                                      300,
                                                                ),

                                                            padding:
                                                                EdgeInsets.symmetric(
                                                                  vertical:
                                                                      10.h,
                                                                ),

                                                            child: AnimatedDefaultTextStyle(
                                                              duration:
                                                                  const Duration(
                                                                    milliseconds:
                                                                        300,
                                                                  ),

                                                              style: TextStyle(
                                                                color: active
                                                                    ? Colors
                                                                          .white
                                                                    : Colors
                                                                          .white38,

                                                                fontSize: active
                                                                    ? 27.sp
                                                                    : 21.sp,

                                                                fontWeight:
                                                                    active
                                                                    ? FontWeight
                                                                          .bold
                                                                    : FontWeight
                                                                          .w600,

                                                                height: 1.8,

                                                                shadows: active
                                                                    ? [
                                                                        Shadow(
                                                                          color: musicAccent.withOpacity(
                                                                            0.8,
                                                                          ),

                                                                          blurRadius:
                                                                              18,
                                                                        ),
                                                                      ]
                                                                    : [],
                                                              ),

                                                              child: Text(
                                                                lyric.text,

                                                                textAlign:
                                                                    TextAlign
                                                                        .center,
                                                              ),
                                                            ),
                                                          );
                                                        },
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                      /// =========================
                                      /// ALBUM MODE
                                      /// =========================
                                      : Column(
                                          key: const ValueKey('album'),

                                          mainAxisAlignment:
                                              MainAxisAlignment.center,

                                          children: [
                                            /// ALBUM
                                            AnimatedContainer(
                                              duration: const Duration(
                                                milliseconds: 400,
                                              ),

                                              width: 300.w,
                                              height: 300.w,

                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(34.r),

                                                image: DecorationImage(
                                                  image:
                                                      musicProvider
                                                          .albumArt
                                                          .isNotEmpty
                                                      ? NetworkImage(
                                                          musicProvider
                                                              .albumArt,
                                                        )
                                                      : const AssetImage(
                                                              'assets/images/weekend.png',
                                                            )
                                                            as ImageProvider,

                                                  fit: BoxFit.cover,
                                                ),

                                                boxShadow: [
                                                  BoxShadow(
                                                    color: musicAccent
                                                        .withOpacity(0.35),
                                                    blurRadius: 35,
                                                  ),
                                                ],
                                              ),
                                            ),

                                            SizedBox(height: 28.h),

                                            /// TITLE
                                            SizedBox(
                                              width: 420.w,

                                              child: Text(
                                                musicProvider.title,

                                                textAlign: TextAlign.center,

                                                maxLines: 2,

                                                overflow: TextOverflow.ellipsis,

                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 28.sp,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),

                                            SizedBox(height: 12.h),

                                            /// ARTIST
                                            Text(
                                              musicProvider.artist,

                                              style: TextStyle(
                                                color: Colors.white70,
                                                fontSize: 20.sp,
                                              ),
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                            ),

                            /// ===============================
                            /// SLIDER
                            /// ===============================
                            ///
                            ///
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 90.w),

                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,

                                children: [
                                  Text(
                                    formatDuration(
                                      musicProvider.currentPosition,
                                    ),

                                    style: TextStyle(
                                      color: Colors.white60,
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),

                                  Text(
                                    formatDuration(musicProvider.totalDuration),

                                    style: TextStyle(
                                      color: Colors.white60,
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 90.w),

                              child: SliderTheme(
                                data: SliderThemeData(
                                  trackHeight: 5.h,

                                  thumbShape: RoundSliderThumbShape(
                                    enabledThumbRadius: 7.r,
                                  ),

                                  overlayShape: SliderComponentShape.noOverlay,
                                ),

                                child: Slider(
                                  value:
                                      musicProvider
                                              .totalDuration
                                              .inMilliseconds ==
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

                                  activeColor: musicAccent,

                                  inactiveColor: Colors.white24,
                                ),
                              ),
                            ),

                            SizedBox(height: 12.h),

                            /// ===============================
                            /// CONTROLS
                            /// ===============================
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,

                              children: [
                                _controlButton(
                                  icon: Icons.skip_previous,

                                  musicAccent: musicAccent,

                                  onTap: () async {
                                    await musicProvider.previous();
                                  },
                                ),

                                SizedBox(width: 24.w),

                                /// PLAY
                                GestureDetector(
                                  onTap: () async {
                                    await musicProvider.togglePlay();
                                  },

                                  child: Container(
                                    width: 88.w,
                                    height: 88.w,

                                    decoration: BoxDecoration(
                                      color: musicAccent,

                                      shape: BoxShape.circle,

                                      boxShadow: [
                                        BoxShadow(
                                          color: musicAccent.withOpacity(0.45),

                                          blurRadius: 24,
                                        ),
                                      ],
                                    ),

                                    child: Icon(
                                      musicProvider.isPlaying
                                          ? Icons.pause
                                          : Icons.play_arrow,

                                      color: Colors.white,

                                      size: 50.sp,
                                    ),
                                  ),
                                ),

                                SizedBox(width: 24.w),

                                _controlButton(
                                  icon: Icons.skip_next,

                                  musicAccent: musicAccent,

                                  onTap: () async {
                                    await musicProvider.next();
                                  },
                                ),

                                SizedBox(width: 20.w),

                                /// MIC
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      showLyrics = !showLyrics;
                                    });
                                  },

                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),

                                    width: 70.w,
                                    height: 70.w,

                                    decoration: BoxDecoration(
                                      color: showLyrics
                                          ? musicAccent
                                          : theme.accentColor
                                                    .withOpacity(0.4),

                                      shape: BoxShape.circle,

                                      boxShadow: showLyrics
                                          ? [
                                              BoxShadow(
                                                color: theme.accentColor
                                                    .withOpacity(0.4),
                                                blurRadius: 18,
                                              ),
                                            ]
                                          : [],
                                    ),

                                    child: Icon(
                                      Icons.mic,
                                      color: Colors.white,
                                      size: 34.sp,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            SizedBox(height: 22.h),
                          ],
                        ),
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
  }

  String formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');

    final minutes = twoDigits(d.inMinutes.remainder(60));

    final seconds = twoDigits(d.inSeconds.remainder(60));

    return '$minutes:$seconds';
  }

  /// ===============================
  /// CATEGORY BUTTON
  /// ===============================
  Widget _category(String title, String value, Color musicAccent) {
    final active = selectedCategory == value;

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedCategory = value;
        });

        searchMusic(_searchController.text);
      },

      child: Container(
        margin: EdgeInsets.only(right: 12.w),

        padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 11.h),

        decoration: BoxDecoration(
          color: active ? musicAccent : Colors.white.withOpacity(0.06),

          borderRadius: BorderRadius.circular(20.r),
        ),

        child: Text(
          title,

          style: TextStyle(
            color: active ? Colors.black : Colors.white,
            fontSize: 15.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  /// ===============================
  /// CONTROL BUTTON
  /// ===============================
  Widget _controlButton({
    required IconData icon,
    required Color musicAccent,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,

      child: Container(
        width: 74.w,
        height: 74.w,

        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.07),

          shape: BoxShape.circle,

          border: Border.all(color: musicAccent.withOpacity(0.35)),
        ),

        child: Icon(icon, color: Colors.white, size: 42.sp),
      ),
    );
  }
}
