import 'dart:async';
import 'package:flutter/material.dart';
import 'package:frontend/core/services/overlay_service.dart';
import 'package:frontend/core/services/video_mqtt_service.dart';
import '../../../core/utils/action_parser.dart';

class VideoProvider extends ChangeNotifier {
  final VideoMqttService _videoMqttService = VideoMqttService();

  StreamSubscription? _subscription;

  void init(BuildContext context) {
    final overlayState = Overlay.of(context, rootOverlay: true);

    _videoMqttService.connect();

    _subscription = _videoMqttService.stream.listen((message) {
      final videoPath = ActionParser.parseToVideo(message);
      if (videoPath == null) return;

      final overlay = VideoOverlayService();

      /// 🔥 LOCK SYSTEM (INI KUNCI)
      if (overlay.isShowing) {
        debugPrint("⛔ Sedang play, command diabaikan");
        return;
      }

      overlay.showOnOverlay(overlayState: overlayState, videoAsset: videoPath);
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _videoMqttService.dispose();
    super.dispose();
  }
}
