import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:frontend/core/services/jetson_performance.dart';
import 'package:frontend/core/themes/car_theme.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

class VideoPlayerPage extends StatefulWidget {
  final String videoAsset;
  final VoidCallback onFinish;

  const VideoPlayerPage({
    super.key,
    required this.videoAsset,
    required this.onFinish,
  });

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage>
    with SingleTickerProviderStateMixin {
  late final Player player;
  late final VideoController controller;

  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;
  StreamSubscription<bool>? _playingSub;
  Timer? _controlsHideTimer;

  bool _isClosing = false;
  bool _controlsVisible = true;

  @override
  void initState() {
    super.initState();

    /// 🎬 Media init
    player = Player(
      configuration: const PlayerConfiguration(bufferSize: 16 * 1024 * 1024),
    );
    controller = VideoController(
      player,
      configuration: VideoControllerConfiguration(
        width: JetsonPerformance.tutorialVideoWidth,
        height: JetsonPerformance.tutorialVideoHeight,
        enableHardwareAcceleration: JetsonPerformance.videoHardwareAcceleration,
      ),
    );

    /// 🎨 Fade animation
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );

    _fadeController.forward();

    /// ▶️ Play video
    player.setVolume(100);
    player.open(Media('asset:///${widget.videoAsset}'), play: true);

    _scheduleControlsHide();

    _playingSub = player.stream.playing.listen((playing) {
      if (playing) {
        _scheduleControlsHide();
      } else {
        _showControls(keepVisible: true);
      }
    });

    /// 🔥 Auto close saat selesai
    player.stream.completed.listen((completed) {
      if (completed) {
        _closeVideo();
      }
    });
  }

  void _closeVideo() {
    if (_isClosing) return;
    _isClosing = true;
    _controlsHideTimer?.cancel();

    _fadeController.reverse().then((_) {
      widget.onFinish();
    });
  }

  void _showControls({bool keepVisible = false}) {
    _controlsHideTimer?.cancel();

    if (mounted && !_controlsVisible) {
      setState(() => _controlsVisible = true);
    }

    if (!keepVisible && player.state.playing) {
      _scheduleControlsHide();
    }
  }

  void _scheduleControlsHide() {
    _controlsHideTimer?.cancel();

    if (!player.state.playing) return;

    _controlsHideTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted || _isClosing) return;
      setState(() => _controlsVisible = false);
    });
  }

  @override
  void dispose() {
    _controlsHideTimer?.cancel();
    _playingSub?.cancel();
    _fadeController.dispose();
    player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: CarThemes.currentTheme,
      builder: (context, themeType, _) {
        final theme = CarThemes.getTheme(themeType);
        final accent = getMusicAccentColor(themeType, theme);

        return FadeTransition(
          opacity: _fadeAnimation,
          child: Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topRight,
                radius: 1.2,
                colors: [
                  Color.lerp(Colors.black, accent, 0.16)!,
                  const Color(0xFF050505),
                  Colors.black,
                ],
                stops: const [0, 0.48, 1],
              ),
            ),
            child: SafeArea(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (_controlsVisible && player.state.playing) {
                    _controlsHideTimer?.cancel();
                    setState(() => _controlsVisible = false);
                    return;
                  }

                  _showControls();
                },
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(28, 72, 28, 68),
                        child: Center(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: accent.withValues(alpha: 0.46),
                                width: 1.4,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: accent.withValues(alpha: 0.20),
                                  blurRadius: 34,
                                  spreadRadius: -10,
                                ),
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.60),
                                  blurRadius: 26,
                                  offset: const Offset(0, 18),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(21),
                              child: AspectRatio(
                                aspectRatio: 16 / 9,
                                child: ColoredBox(
                                  color: Colors.black,
                                  child: Stack(
                                    children: [
                                      Positioned.fill(
                                        child: Video(
                                          controller: controller,
                                          controls: NoVideoControls,
                                        ),
                                      ),
                                      Positioned.fill(
                                        child: GestureDetector(
                                          behavior: HitTestBehavior.translucent,
                                          onTap: () {
                                            if (_controlsVisible &&
                                                player.state.playing) {
                                              _controlsHideTimer?.cancel();
                                              setState(() {
                                                _controlsVisible = false;
                                              });
                                              return;
                                            }

                                            _showControls();
                                          },
                                        ),
                                      ),
                                      Positioned(
                                        left: 18,
                                        right: 18,
                                        bottom: 16,
                                        child: Listener(
                                          behavior: HitTestBehavior.translucent,
                                          onPointerDown: (_) => _showControls(),
                                          child: AnimatedOpacity(
                                            opacity: _controlsVisible ? 1 : 0,
                                            duration: const Duration(
                                              milliseconds: 220,
                                            ),
                                            curve: Curves.easeOut,
                                            child: IgnorePointer(
                                              ignoring: !_controlsVisible,
                                              child: _PremiumVideoControls(
                                                player: player,
                                                accent: accent,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 22,
                      left: 28,
                      right: 104,
                      child: Listener(
                        behavior: HitTestBehavior.translucent,
                        onPointerDown: (_) => _showControls(),
                        child: AnimatedOpacity(
                          opacity: _controlsVisible ? 1 : 0,
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOut,
                          child: IgnorePointer(
                            ignoring: !_controlsVisible,
                            child: _VideoHeader(accent: accent),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 18,
                      right: 28,
                      child: Listener(
                        behavior: HitTestBehavior.translucent,
                        onPointerDown: (_) => _showControls(),
                        child: AnimatedOpacity(
                          opacity: _controlsVisible ? 1 : 0,
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOut,
                          child: IgnorePointer(
                            ignoring: !_controlsVisible,
                            child: _CloseVideoButton(
                              accent: accent,
                              onTap: _closeVideo,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PremiumVideoControls extends StatelessWidget {
  const _PremiumVideoControls({required this.player, required this.accent});

  final Player player;
  final Color accent;

  String _format(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    final hours = duration.inHours;

    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }

    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration>(
      stream: player.stream.duration,
      initialData: player.state.duration,
      builder: (context, durationSnapshot) {
        final duration = durationSnapshot.data ?? Duration.zero;

        return StreamBuilder<Duration>(
          stream: player.stream.position,
          initialData: player.state.position,
          builder: (context, positionSnapshot) {
            final position = positionSnapshot.data ?? Duration.zero;
            final maxMilliseconds = duration.inMilliseconds <= 0
                ? 1.0
                : duration.inMilliseconds.toDouble();
            final positionMilliseconds = position.inMilliseconds
                .clamp(0, maxMilliseconds.toInt())
                .toDouble();

            return ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.66),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.22),
                        blurRadius: 24,
                        spreadRadius: -10,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SliderTheme(
                        data: SliderThemeData(
                          trackHeight: 8,
                          overlayShape: SliderComponentShape.noOverlay,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 8,
                          ),
                          activeTrackColor: accent,
                          inactiveTrackColor: Colors.white.withValues(
                            alpha: 0.18,
                          ),
                          thumbColor: Colors.white,
                        ),
                        child: Slider(
                          value: positionMilliseconds,
                          min: 0,
                          max: maxMilliseconds,
                          onChanged: (value) {
                            player.seek(Duration(milliseconds: value.round()));
                          },
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          StreamBuilder<bool>(
                            stream: player.stream.playing,
                            initialData: player.state.playing,
                            builder: (context, snapshot) {
                              final playing = snapshot.data ?? false;

                              return _VideoControlButton(
                                icon: playing
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                accent: accent,
                                large: true,
                                onTap: () {
                                  player.playOrPause();
                                },
                              );
                            },
                          ),
                          const SizedBox(width: 14),
                          Text(
                            '${_format(position)} / ${_format(duration)}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.86),
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const Spacer(),
                          StreamBuilder<double>(
                            stream: player.stream.volume,
                            initialData: player.state.volume,
                            builder: (context, snapshot) {
                              final volume = (snapshot.data ?? 100).clamp(
                                0,
                                100,
                              );

                              return Row(
                                children: [
                                  _VideoControlButton(
                                    icon: volume == 0
                                        ? Icons.volume_off_rounded
                                        : Icons.volume_up_rounded,
                                    accent: accent,
                                    onTap: () {
                                      player.setVolume(
                                        volume == 0 ? 100.0 : 0.0,
                                      );
                                    },
                                  ),
                                  SizedBox(
                                    width: 150,
                                    child: SliderTheme(
                                      data: SliderThemeData(
                                        trackHeight: 5,
                                        overlayShape:
                                            SliderComponentShape.noOverlay,
                                        thumbShape: const RoundSliderThumbShape(
                                          enabledThumbRadius: 6,
                                        ),
                                        activeTrackColor: accent,
                                        inactiveTrackColor: Colors.white
                                            .withValues(alpha: 0.16),
                                        thumbColor: Colors.white,
                                      ),
                                      child: Slider(
                                        value: volume.toDouble(),
                                        min: 0,
                                        max: 100,
                                        onChanged: player.setVolume,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                          _PlaybackSpeedButton(player: player, accent: accent),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _VideoControlButton extends StatelessWidget {
  const _VideoControlButton({
    required this.icon,
    required this.accent,
    required this.onTap,
    this.large = false,
  });

  final IconData icon;
  final Color accent;
  final VoidCallback onTap;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final size = large ? 52.0 : 42.0;
    final foreground =
        ThemeData.estimateBrightnessForColor(accent) == Brightness.dark
        ? Colors.white
        : Colors.black;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: large ? accent : Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: large
                  ? accent.withValues(alpha: 0.44)
                  : Colors.white.withValues(alpha: 0.12),
            ),
            boxShadow: large
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.34),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Icon(
            icon,
            color: large ? foreground : Colors.white,
            size: large ? 34 : 24,
          ),
        ),
      ),
    );
  }
}

class _PlaybackSpeedButton extends StatelessWidget {
  const _PlaybackSpeedButton({required this.player, required this.accent});

  final Player player;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<double>(
      tooltip: 'Playback speed',
      color: const Color(0xFF101318),
      elevation: 16,
      offset: const Offset(0, -164),
      onSelected: (value) {
        player.setRate(value);
      },
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: 0.75,
          child: Text('0.75x', style: TextStyle(color: Colors.white)),
        ),
        PopupMenuItem(
          value: 1.0,
          child: Text('1.00x', style: TextStyle(color: Colors.white)),
        ),
        PopupMenuItem(
          value: 1.25,
          child: Text('1.25x', style: TextStyle(color: Colors.white)),
        ),
      ],
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Icon(Icons.tune_rounded, color: accent, size: 23),
      ),
    );
  }
}

class _VideoHeader extends StatelessWidget {
  const _VideoHeader({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.58),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.play_arrow_rounded, color: accent, size: 18),
            ),
            const SizedBox(width: 10),
            Text(
              'Instruction Video',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.88),
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CloseVideoButton extends StatelessWidget {
  const _CloseVideoButton({required this.accent, required this.onTap});

  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Close video',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.76),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.22),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.24),
                  blurRadius: 18,
                  spreadRadius: -2,
                ),
              ],
            ),
            child: const Icon(
              Icons.close_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
        ),
      ),
    );
  }
}
