import 'dart:convert';

import 'package:frontend/core/constant/video_assets.dart';

class ActionParser {
  static String? parseToVideo(String message) {
    try {
      final jsonData = jsonDecode(message);
      final String actionString = jsonData['action'];

      final vehicleAction = VideoAssets.fromString(actionString);
      if (vehicleAction == null) return null;

      return VideoAssets.actionVideoMap[vehicleAction];
    } catch (e) {
      return null;
    }
  }
}