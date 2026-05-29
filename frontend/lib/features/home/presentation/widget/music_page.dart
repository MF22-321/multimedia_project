import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:frontend/core/localization/app_strings.dart';
import 'package:frontend/core/navigation/smart_music_navigation.dart';
import 'package:frontend/core/provider/music_provider.dart';
import 'package:frontend/core/services/spotify_search_service.dart';
import 'package:frontend/core/themes/car_theme.dart';
import 'package:frontend/core/widgets/in_app_keyboard.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

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
  String suggestedMoodKeyword = "";

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
  void initState() {
    super.initState();

    SmartMusicSuggestion.suggestedKeyword.addListener(_handleMoodSuggestion);
  }

  @override
  void dispose() {
    SmartMusicSuggestion.suggestedKeyword.removeListener(_handleMoodSuggestion);

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
  /// HANDLE MOOD SUGGESTION
  /// ===============================
  void _handleMoodSuggestion() {
    final keyword = SmartMusicSuggestion.suggestedKeyword.value;

    if (keyword == null) return;

    setState(() {
      suggestedMoodKeyword = keyword;
    });

    /// AUTO SEARCH
    _searchController.text = keyword;

    searchMusic(keyword);

    /// RESET
    Future.delayed(const Duration(seconds: 2), () {
      SmartMusicSuggestion.suggestedKeyword.value = null;
    });
  }

  /// ===============================
  /// SEARCH MUSIC
  /// ===============================
  void _onSearchTextChanged(String value) {
    if (_searchDebounce?.isActive ?? false) {
      _searchDebounce?.cancel();
    }

    _searchDebounce = Timer(
      const Duration(milliseconds: 500),
      () {
        searchMusic(value);
      },
    );
  }

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
      final launched = await launchUrl(
        Uri.parse(uri),
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        final trackId = uri.startsWith('spotify:track:')
            ? uri.replaceFirst('spotify:track:', '')
            : '';

        if (trackId.isEmpty) return;

        await launchUrl(
          Uri.parse('https://open.spotify.com/track/$trackId'),
          mode: LaunchMode.externalApplication,
        );
      }

      await Future.delayed(const Duration(milliseconds: 1200));

      await musicProvider.play();
      musicProvider.startProgressListener();
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final musicProvider = Provider.of<MusicProvider>(context);
    final moodKeyword = SmartMusicSuggestion.suggestedKeyword.value;

    if (moodKeyword != null &&
        moodKeyword.isNotEmpty &&
        moodKeyword != suggestedMoodKeyword) {
      suggestedMoodKeyword = moodKeyword;

      _searchController.text = moodKeyword;

      Future.microtask(() {
        searchMusic(moodKeyword);
      });
    }

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
                      color: musicAccent.withValues(alpha: 0.18),
                    ),
                  ),
                ),

                /// ===============================
                /// BLUR
                /// ===============================
                BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),

                  child: Container(color: Colors.black.withValues(alpha: 0.15)),
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
                        color: Colors.white.withValues(alpha: 0.03),

                        border: Border(
                          right: BorderSide(
                            color: Colors.white.withValues(alpha: 0.06),
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
                                AppStrings.music,
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
                              color: Colors.white.withValues(alpha: 0.06),

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
                                    readOnly: true,
                                    showCursor: true,
                                    onTap: () {
                                      showInAppKeyboard(
                                        context: context,
                                        controller: _searchController,
                                        title: 'Search music',
                                        accentColor: musicAccent,
                                        onChanged: _onSearchTextChanged,
                                        onSubmitted: searchMusic,
                                      );
                                    },
                                    onChanged: _onSearchTextChanged,

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

                          /// ===============================
                          /// AI MOOD RECOMMENDATION
                          /// ===============================
                          if (suggestedMoodKeyword.isNotEmpty)
                            Container(
                              margin: EdgeInsets.only(bottom: 24.h),

                              padding: EdgeInsets.all(22.w),

                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(28.r),

                                color: musicAccent.withValues(alpha: 0.12),

                                border: Border.all(
                                  color: musicAccent.withValues(alpha: 0.22),
                                ),

                                boxShadow: [
                                  BoxShadow(
                                    color: musicAccent.withValues(alpha: 0.24),

                                    blurRadius: 24,
                                  ),
                                ],
                              ),

                              child: Row(
                                children: [
                                  Container(
                                    width: 60.w,
                                    height: 60.w,

                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,

                                      color: musicAccent.withValues(
                                        alpha: 0.18,
                                      ),
                                    ),

                                    child: Icon(
                                      Icons.psychology,

                                      color: musicAccent,

                                      size: 30.sp,
                                    ),
                                  ),

                                  SizedBox(width: 18.w),

                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,

                                      children: [
                                        Text(
                                          "AI Mood Recommendation",

                                          style: TextStyle(
                                            color: Colors.white,

                                            fontSize: 18.sp,

                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),

                                        SizedBox(height: 6.h),

                                        Text(
                                          suggestedMoodKeyword,

                                          style: TextStyle(
                                            color: Colors.white70,

                                            fontSize: 14.sp,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

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

                              itemCount: _spotifyItems.length,

                              itemBuilder: (context, index) {
                                final song = _spotifyItems[index];

                                final imageUrl = _imageUrlForSong(song);

                                final title = _titleForSong(song);

                                final subtitle = _subtitleForSong(song);

                                return Container(
                                  margin: EdgeInsets.only(bottom: 16.h),

                                  padding: EdgeInsets.symmetric(
                                    horizontal: 16.w,
                                    vertical: 12.h,
                                  ),

                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.05),

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
                                            final uri =
                                                song['uri']?.toString() ?? '';

                                            if (uri.isEmpty) {
                                              return;
                                            }

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
                                                color: musicAccent.withValues(
                                                  alpha: 0.4,
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
                                                            key:
                                                                _lyricKeys[index],
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
                                                                          color: musicAccent.withValues(
                                                                            alpha:
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
                                                        .withValues(
                                                          alpha: 0.35,
                                                        ),
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
                                          color: musicAccent.withValues(
                                            alpha: 0.45,
                                          ),

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
                                          : theme.accentColor.withValues(
                                              alpha: 0.4,
                                            ),

                                      shape: BoxShape.circle,

                                      boxShadow: showLyrics
                                          ? [
                                              BoxShadow(
                                                color: theme.accentColor
                                                    .withValues(alpha: 0.4),
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

  List<Map<String, dynamic>> get _spotifyItems {
    if (spotifyData.isEmpty) {
      return recentSongs;
    }

    final section = selectedCategory == 'track'
        ? spotifyData['tracks']
        : selectedCategory == 'artist'
        ? spotifyData['artists']
        : selectedCategory == 'album'
        ? spotifyData['albums']
        : spotifyData['playlists'];

    if (section is! Map) {
      return [];
    }

    final items = section['items'];

    if (items is! List) {
      return [];
    }

    return items
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  String _imageUrlForSong(Map<String, dynamic> song) {
    if (spotifyData.isEmpty) {
      return song['image']?.toString() ?? '';
    }

    if (selectedCategory == 'track') {
      final album = song['album'];

      if (album is Map) {
        return _firstImageUrl(album['images']);
      }

      return '';
    }

    return _firstImageUrl(song['images']);
  }

  String _firstImageUrl(dynamic images) {
    if (images is! List || images.isEmpty) {
      return '';
    }

    final firstImage = images.first;

    if (firstImage is! Map) {
      return '';
    }

    return firstImage['url']?.toString() ?? '';
  }

  String _titleForSong(Map<String, dynamic> song) {
    if (spotifyData.isEmpty) {
      return song['title']?.toString() ?? 'Unknown Title';
    }

    return song['name']?.toString() ?? 'Unknown Title';
  }

  String _subtitleForSong(Map<String, dynamic> song) {
    if (spotifyData.isEmpty) {
      return song['artist']?.toString() ?? 'Unknown Artist';
    }

    if (selectedCategory == 'artist') {
      return 'Artist';
    }

    if (selectedCategory == 'playlist') {
      return 'Playlist';
    }

    final artists = song['artists'];

    if (artists is List && artists.isNotEmpty && artists.first is Map) {
      final firstArtist = artists.first as Map;

      return firstArtist['name']?.toString() ?? 'Unknown Artist';
    }

    return 'Unknown Artist';
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
          color: active ? musicAccent : Colors.white.withValues(alpha: 0.06),

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
          color: Colors.white.withValues(alpha: 0.07),

          shape: BoxShape.circle,

          border: Border.all(color: musicAccent.withValues(alpha: 0.35)),
        ),

        child: Icon(icon, color: Colors.white, size: 42.sp),
      ),
    );
  }
}
