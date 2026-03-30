import 'dart:async';
import 'package:flutter/material.dart';
import 'package:frontend/core/services/overlay_service.dart';
import '../../../core/services/lan_service.dart';
import '../../../core/utils/action_parser.dart';


class VideoProvider extends ChangeNotifier {
  final LanService _lanService = LanService();

  StreamSubscription? _subscription;

  void init(BuildContext context) {
    _lanService.connect();

    _subscription = _lanService.stream.listen((message) {
      final videoPath = ActionParser.parseToVideo(message);
      if (videoPath == null) return;

      final overlay = VideoOverlayService();

      /// 🔥 LOCK SYSTEM (INI KUNCI)
      if (overlay.isShowing) {
        debugPrint("⛔ Sedang play, command diabaikan");
        return;
      }

      overlay.show(
        context: context,
        videoAsset: videoPath,
      );
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _lanService.dispose();
    super.dispose();
  }
}