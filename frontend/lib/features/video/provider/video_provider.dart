import 'package:flutter/material.dart';
import 'package:frontend/core/services/multimedia_tcp_server.dart';
import 'package:frontend/core/services/overlay_service.dart';
import 'package:frontend/core/services/video_mqtt_service.dart';
import '../../../core/utils/action_parser.dart';

class VideoProvider extends ChangeNotifier {
  final VideoMqttService _videoMqttService = VideoMqttService();

  OverlayState? _overlayState;

  void init(BuildContext context) {
    _overlayState = Overlay.of(context, rootOverlay: true);
    _videoMqttService.connect(commandHandler: _handleCommand);
  }

  Future<MultimediaCommandResult> _handleCommand(
    Map<String, dynamic> command,
  ) async {
    final rawAction = (command['action'] ?? '').toString().trim().toLowerCase();
    final normalizedAction = rawAction.replaceAll(RegExp(r'[ -]+'), '_');
    final overlay = VideoOverlayService();

    if (normalizedAction == 'stop') {
      overlay.hide();
      return const MultimediaCommandResult.success('SOP video stopped');
    }

    final videoPath = ActionParser.parseMapToVideo(command);
    if (videoPath == null) {
      final requested = command['video'] ?? command['action'] ?? '(empty)';
      return MultimediaCommandResult.error('Unsupported SOP video: $requested');
    }

    final overlayState = _overlayState;
    if (overlayState == null) {
      return const MultimediaCommandResult.error('SOP overlay is not ready');
    }
    if (overlay.isShowing) {
      return const MultimediaCommandResult.error(
        'Another SOP video is already playing',
      );
    }

    overlay.showOnOverlay(overlayState: overlayState, videoAsset: videoPath);
    if (!overlay.isShowing) {
      return const MultimediaCommandResult.error(
        'SOP overlay rejected the video',
      );
    }

    return const MultimediaCommandResult.success('SOP video started');
  }

  @override
  void dispose() {
    _videoMqttService.dispose();
    super.dispose();
  }
}
