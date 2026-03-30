import 'package:flutter/material.dart';
import 'package:frontend/features/video/page/video_player_page.dart';

class VideoOverlayService {
  static final VideoOverlayService _instance =
      VideoOverlayService._internal();

  factory VideoOverlayService() => _instance;

  VideoOverlayService._internal();

  OverlayEntry? _overlayEntry;

  void show({
    required BuildContext context,
    required String videoAsset,
  }) {
    /// 🔥 prevent double overlay
    if (_overlayEntry != null) return;

    _overlayEntry = OverlayEntry(
      builder: (context) => Material(
        color: Colors.transparent,
        child: VideoPlayerPage(
          videoAsset: videoAsset,
          onFinish: hide,
        ),
      ),
    );

    Overlay.of(context, rootOverlay: true).insert(_overlayEntry!);
  }

  void hide() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  bool get isShowing => _overlayEntry != null;
}