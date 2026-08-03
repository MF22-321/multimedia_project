import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:frontend/core/services/jetson_performance.dart';
import 'package:frontend/models/avatar_state.dart';
import 'package:frontend/services/mqtt_avatar_service.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

class AiAssistantOverlay extends StatefulWidget {
  const AiAssistantOverlay({
    super.key,
    required this.service,
    this.thinkingVideo = 'assets/video_sdr/think.mp4',
    this.answeringVideo = 'assets/video_sdr/what_else.mp4',
  });

  final MqttAvatarService service;
  final String thinkingVideo;
  final String answeringVideo;

  @override
  State<AiAssistantOverlay> createState() => _AiAssistantOverlayState();
}

class _AiAssistantOverlayState extends State<AiAssistantOverlay>
    with TickerProviderStateMixin {
  late final Player _player;
  late final VideoController _videoController;
  late final AnimationController _pulseController;
  late final AnimationController _typingController;

  AvatarState _lastState = AvatarState.idle;
  String? _currentVideoAsset;
  int _videoSyncGeneration = 0;
  Timer? _subtitleScrollTimer;
  final ScrollController _subtitleScrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    _player = Player(
      configuration: const PlayerConfiguration(bufferSize: 8 * 1024 * 1024),
    );
    _videoController = VideoController(
      _player,
      configuration: VideoControllerConfiguration(
        width: JetsonPerformance.assistantVideoWidth,
        height: JetsonPerformance.assistantVideoHeight,
        enableHardwareAcceleration: JetsonPerformance.videoHardwareAcceleration,
      ),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    _typingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();

    widget.service.addListener(_handleServiceChanged);
    _handleServiceChanged();
  }

  @override
  void didUpdateWidget(covariant AiAssistantOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.service != widget.service) {
      oldWidget.service.removeListener(_handleServiceChanged);
      widget.service.addListener(_handleServiceChanged);
      _lastState = AvatarState.idle;
      _currentVideoAsset = null;
      _handleServiceChanged();
    }
  }

  void _handleServiceChanged() {
    final state = widget.service.state;

    if (state != _lastState) {
      _lastState = state;
      _syncVideoWithState(state);
    }

    if (state == AvatarState.answering) {
      _scheduleSubtitleScroll();
    }

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _syncVideoWithState(AvatarState state) async {
    final generation = ++_videoSyncGeneration;

    if (state == AvatarState.idle) {
      _currentVideoAsset = null;
      await Future<void>.delayed(Duration.zero);
      if (generation != _videoSyncGeneration) return;
      await _player.stop();
      return;
    }

    final asset = state == AvatarState.thinking
        ? widget.thinkingVideo
        : widget.answeringVideo;

    if (_currentVideoAsset == asset && _player.state.playing) return;

    _currentVideoAsset = asset;
    await _player.setPlaylistMode(PlaylistMode.single);
    await _player.setVolume(100);
    if (generation != _videoSyncGeneration) return;
    await _player.open(Media('asset:///$asset'), play: true);
  }

  void _scheduleSubtitleScroll() {
    _subtitleScrollTimer?.cancel();
    _subtitleScrollTimer = Timer(const Duration(milliseconds: 80), () {
      if (!_subtitleScrollController.hasClients) return;
      final maxScroll = _subtitleScrollController.position.maxScrollExtent;
      _subtitleScrollController.animateTo(
        maxScroll,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    widget.service.removeListener(_handleServiceChanged);
    _subtitleScrollTimer?.cancel();
    _subtitleScrollController.dispose();
    _pulseController.dispose();
    _typingController.dispose();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.service.state;
    final visible = state.isVisible;

    return Positioned.fill(
      child: IgnorePointer(
        ignoring: !visible,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          child: AnimatedScale(
            scale: visible ? 1 : 0.98,
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            child: RepaintBoundary(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xFF02070B),
                        gradient: RadialGradient(
                          center: Alignment.center,
                          radius: 0.86,
                          colors: [
                            const Color(0xFF062631),
                            const Color(0xFF02070B),
                            Colors.black,
                          ],
                          stops: const [0, 0.62, 1],
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: RepaintBoundary(
                      child: _AssistantCard(
                        state: state,
                        subtitle: widget.service.subtitle,
                        isConnected: widget.service.isConnected,
                        pulse: _pulseController,
                        typing: _typingController,
                        videoController: _videoController,
                        subtitleScrollController: _subtitleScrollController,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AssistantCard extends StatelessWidget {
  const _AssistantCard({
    required this.state,
    required this.subtitle,
    required this.isConnected,
    required this.pulse,
    required this.typing,
    required this.videoController,
    required this.subtitleScrollController,
  });

  final AvatarState state;
  final String subtitle;
  final bool isConnected;
  final Animation<double> pulse;
  final Animation<double> typing;
  final VideoController videoController;
  final ScrollController subtitleScrollController;

  @override
  Widget build(BuildContext context) {
    final cardWidth = 0.88.sw.clamp(980.0, 1540.0).toDouble();
    final cardHeight = 0.88.sh.clamp(660.0, 900.0).toDouble();
    final avatarCoreSize = math.min(cardHeight * 0.56, cardWidth * 0.42);

    return Container(
      width: cardWidth,
      height: cardHeight,
      constraints: BoxConstraints(maxWidth: 0.92.sw, maxHeight: 0.92.sh),
      padding: EdgeInsets.fromLTRB(40.w, 30.h, 40.w, 32.h),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(38.r),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [const Color(0xFF07131A), const Color(0xFF02070B)],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.14),
          width: 1.3,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2EEBFF).withValues(alpha: 0.24),
            blurRadius: 70,
            spreadRadius: -12,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.68),
            blurRadius: 46,
            offset: const Offset(0, 28),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _GlowingDot(active: state.isVisible),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Toyota AI Assistant',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 31.sp,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      isConnected
                          ? 'Voice command connected'
                          : 'Waiting for Raspberry over RJ45',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.56),
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusPill(state: state),
            ],
          ),
          SizedBox(height: 8.h),
          Expanded(
            child: Center(
              child: SizedBox(
                width: avatarCoreSize,
                height: avatarCoreSize,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AnimatedBuilder(
                      animation: pulse,
                      builder: (context, _) {
                        return CustomPaint(
                          size: Size.square(avatarCoreSize),
                          painter: _AnsweringRingPainter(
                            progress: pulse.value,
                            active: state == AvatarState.answering,
                          ),
                        );
                      },
                    ),
                    Container(
                      width: avatarCoreSize * 0.82,
                      height: avatarCoreSize * 0.82,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withValues(alpha: 0.74),
                        border: Border.all(
                          color: const Color(
                            0xFF58F3FF,
                          ).withValues(alpha: 0.34),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF00DFFF,
                            ).withValues(alpha: 0.36),
                            blurRadius: 64,
                            spreadRadius: -6,
                          ),
                          BoxShadow(
                            color: const Color(
                              0xFF4DFFB8,
                            ).withValues(alpha: 0.10),
                            blurRadius: 100,
                            spreadRadius: 6,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: ColoredBox(
                          color: Colors.black,
                          child: Transform.scale(
                            scale: 1.16,
                            alignment: Alignment.topCenter,
                            child: Video(
                              controller: videoController,
                              controls: NoVideoControls,
                              fit: BoxFit.cover,
                              alignment: Alignment.topCenter,
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
          Text(
            state == AvatarState.thinking
                ? 'Thinking...'
                : state == AvatarState.listening
                ? 'Listening...'
                : 'Answering',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.92),
              fontSize: 25.sp,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
          SizedBox(height: 10.h),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child:
                state == AvatarState.thinking || state == AvatarState.listening
                ? _TypingIndicator(
                    key: const ValueKey('typing'),
                    typing: typing,
                  )
                : _SubtitlePanel(
                    key: const ValueKey('subtitle'),
                    subtitle: subtitle,
                    scrollController: subtitleScrollController,
                  ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.state});

  final AvatarState state;

  @override
  Widget build(BuildContext context) {
    final color = state == AvatarState.answering
        ? const Color(0xFF4DFFB8)
        : const Color(0xFF54DFFF);

    return Container(
      height: 34.h,
      padding: EdgeInsets.symmetric(horizontal: 14.w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.38)),
      ),
      child: Center(
        child: Text(
          state.label,
          style: TextStyle(
            color: color,
            fontSize: 12.sp,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}

class _SubtitlePanel extends StatelessWidget {
  const _SubtitlePanel({
    super.key,
    required this.subtitle,
    required this.scrollController,
  });

  final String subtitle;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 92.h,
      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 14.h),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20.r),
        color: Colors.white.withValues(alpha: 0.06),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Stack(
        children: [
          SingleChildScrollView(
            controller: scrollController,
            physics: const NeverScrollableScrollPhysics(),
            child: Text(
              subtitle.isEmpty ? ' ' : subtitle,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.90),
                fontSize: 20.sp,
                fontWeight: FontWeight.w600,
                height: 1.34,
                letterSpacing: 0,
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 22.h,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFF07111B).withValues(alpha: 0),
                      const Color(0xFF07111B).withValues(alpha: 0.72),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator({super.key, required this.typing});

  final Animation<double> typing;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 92.h,
      child: Center(
        child: AnimatedBuilder(
          animation: typing,
          builder: (context, _) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (index) {
                final phase = (typing.value + index * 0.22) % 1.0;
                final scale = 0.65 + (math.sin(phase * math.pi) * 0.35);

                return Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 10.w,
                    height: 10.w,
                    margin: EdgeInsets.symmetric(horizontal: 5.w),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(
                        0xFF54DFFF,
                      ).withValues(alpha: 0.34 + (scale * 0.48)),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFF54DFFF,
                          ).withValues(alpha: 0.34),
                          blurRadius: 14 * scale,
                        ),
                      ],
                    ),
                  ),
                );
              }),
            );
          },
        ),
      ),
    );
  }
}

class _GlowingDot extends StatelessWidget {
  const _GlowingDot({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 13.w,
      height: 13.w,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? const Color(0xFF42F5FF) : Colors.white38,
        boxShadow: active
            ? [
                BoxShadow(
                  color: const Color(0xFF42F5FF).withValues(alpha: 0.78),
                  blurRadius: 18,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
    );
  }
}

class _AnsweringRingPainter extends CustomPainter {
  const _AnsweringRingPainter({required this.progress, required this.active});

  final double progress;
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2;

    final basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(0xFF58F3FF).withValues(alpha: 0.18);

    canvas.drawCircle(center, radius * 0.44, basePaint);
    canvas.drawCircle(center, radius * 0.50, basePaint);
    canvas.drawCircle(center, radius * 0.58, basePaint);

    for (var i = 0; i < 48; i++) {
      final angle = (math.pi * 2 / 48) * i;
      final start = Offset(
        center.dx + math.cos(angle) * radius * 0.61,
        center.dy + math.sin(angle) * radius * 0.61,
      );
      final end = Offset(
        center.dx + math.cos(angle) * radius * 0.64,
        center.dy + math.sin(angle) * radius * 0.64,
      );
      final tickPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = i % 4 == 0 ? 1.7 : 1.0
        ..color = const Color(0xFF58F3FF).withValues(alpha: 0.16);

      canvas.drawLine(start, end, tickPaint);
    }

    final sweepPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = active ? 3.4 : 2.4
      ..color = (active ? const Color(0xFF4DFFB8) : const Color(0xFF58F3FF))
          .withValues(alpha: active ? 0.74 : 0.38);

    final rect = Rect.fromCircle(center: center, radius: radius * 0.56);
    final startAngle = progress * math.pi * 2;
    canvas.drawArc(
      rect,
      startAngle,
      active ? math.pi * 0.74 : math.pi * 0.36,
      false,
      sweepPaint,
    );

    if (active) {
      for (var i = 0; i < 3; i++) {
        final local = (progress + i / 3) % 1.0;
        final waveRadius = radius * (0.46 + local * 0.18);
        final alpha = (1 - local).clamp(0.0, 1.0);
        final wavePaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.7
          ..color = const Color(0xFF58F3FF).withValues(alpha: 0.24 * alpha);

        canvas.drawCircle(center, waveRadius, wavePaint);
      }
    }

    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF58F3FF).withValues(alpha: 0.10),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 0.68));

    canvas.drawCircle(center, radius * 0.68, glowPaint);
  }

  @override
  bool shouldRepaint(covariant _AnsweringRingPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.active != active;
  }
}
