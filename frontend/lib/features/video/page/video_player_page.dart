import 'package:flutter/material.dart';
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

  bool _isClosing = false;

  @override
  void initState() {
    super.initState();

    /// 🎬 Media init
    player = Player();
    controller = VideoController(player);

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
    player.open(Media('asset:///${widget.videoAsset}'));

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

    _fadeController.reverse().then((_) {
      widget.onFinish();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        color: Colors.black.withValues(alpha: 0.95),
        child: Stack(
          children: [
            /// 🎬 VIDEO
            Positioned.fill(
              child: Center(
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Video(controller: controller),
                ),
              ),
            ),

            /// ❌ CLOSE BUTTON
            Positioned(
              top: 30,
              right: 30,
              child: GestureDetector(
                onTap: _closeVideo,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 28),
                ),
              ),
            ),

            /// 🔤 LABEL (optional, bisa kamu customize)
            Positioned(
              bottom: 30,
              left: 30,
              child: Text(
                "Instruction Video",
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
