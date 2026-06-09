import 'package:flutter/material.dart';
import 'package:frontend/features/video/page/video_player_page.dart';

class VideoOverlayService {
  static final VideoOverlayService _instance = VideoOverlayService._internal();

  factory VideoOverlayService() => _instance;

  VideoOverlayService._internal();

  OverlayEntry? _overlayEntry;

  void show({required BuildContext context, required String videoAsset}) {
    showOnOverlay(
      overlayState: Overlay.of(context, rootOverlay: true),
      videoAsset: videoAsset,
    );
  }

  void showOnOverlay({
    required OverlayState overlayState,
    required String videoAsset,
  }) {
    /// Prevent double overlay.
    if (_overlayEntry != null) return;

    _overlayEntry = OverlayEntry(
      opaque: true,
      maintainState: false,
      builder: (context) =>
          _VideoOverlayShell(videoAsset: videoAsset, onFinish: hide),
    );

    overlayState.insert(_overlayEntry!);
  }

  void hide() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  bool get isShowing => _overlayEntry != null;
}

class _VideoOverlayShell extends StatelessWidget {
  const _VideoOverlayShell({
    required this.videoAsset,
    required this.onFinish,
  });

  final String videoAsset;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Material(
        color: Colors.black,
        child: Stack(
          children: [
            const Positioned.fill(
              child: ColoredBox(color: Colors.black),
            ),
            Positioned.fill(
              child: VideoPlayerPage(
                videoAsset: videoAsset,
                onFinish: onFinish,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
