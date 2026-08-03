import 'dart:convert';

import 'package:frontend/core/constant/video_assets.dart';

class ActionParser {
  static String? parseToVideo(String message) {
    final normalizedRawAction = _normalizeAction(message);
    final rawVehicleAction = VideoAssets.fromString(normalizedRawAction);
    if (rawVehicleAction != null) {
      return VideoAssets.actionVideoMap[rawVehicleAction];
    }

    try {
      final jsonData = jsonDecode(message);
      if (jsonData is! Map<String, dynamic>) return null;

      return parseMapToVideo(jsonData);
    } catch (e) {
      return null;
    }
  }

  static String? parseMapToVideo(Map<String, dynamic> command) {
    final actionString = _extractAction(command);
    if (actionString == null) return null;

    final vehicleAction = VideoAssets.fromString(actionString);
    if (vehicleAction == null) return null;

    return VideoAssets.actionVideoMap[vehicleAction];
  }

  static String? _extractAction(Map<String, dynamic> jsonData) {
    final action = jsonData['action']?.toString().trim() ?? '';
    final normalizedAction = action.toLowerCase().replaceAll(
      RegExp(r'[ -]+'),
      '_',
    );
    if (normalizedAction == 'stop') return null;

    final rawAction =
        (normalizedAction == 'play' || normalizedAction == 'start'
            ? jsonData['video']
            : jsonData['action']) ??
        jsonData['video'] ??
        jsonData['command'] ??
        jsonData['sop'] ??
        jsonData['intent'];

    if (rawAction == null) return null;

    final language =
        (jsonData['language'] ?? jsonData['lang'] ?? jsonData['locale'] ?? '')
            .toString();

    return _normalizeAction(rawAction.toString(), language: language);
  }

  static String _normalizeAction(String value, {String language = ''}) {
    final text = value
        .trim()
        .toLowerCase()
        .replaceAll('-', '_')
        .replaceAll(' ', '_');
    final lang = language.trim().toLowerCase();

    final isEnglish = lang == 'en' || lang == 'eng' || text.endsWith('_eng');
    final isJapanese = lang == 'jp' || lang == 'jpn' || text.endsWith('_jpn');
    final suffix = isJapanese
        ? 'JPN'
        : isEnglish
        ? 'ENG'
        : 'IND';

    if (text == 'open_hood' ||
        text == 'buka_kap' ||
        text == 'buka_kap_mobil' ||
        text == 'kap_mobil' ||
        text == 'hood' ||
        text == 'open_car_hood' ||
        text == 'open_hood_ind' ||
        text == 'open_hood_eng' ||
        text == 'open_hood_jpn') {
      if (text.endsWith('_eng')) return 'OPEN_HOOD_ENG';
      if (text.endsWith('_jpn')) return 'OPEN_HOOD_JPN';
      if (text.endsWith('_ind')) return 'OPEN_HOOD_IND';
      return 'OPEN_HOOD_$suffix';
    }

    if (text == 'open_trunk' ||
        text == 'buka_bagasi' ||
        text == 'bagasi' ||
        text == 'buka_tangki' ||
        text == 'buka_tutup_tangki' ||
        text == 'trunk' ||
        text == 'fuel_lid' ||
        text == 'open_trunk_ind' ||
        text == 'open_trunk_eng' ||
        text == 'open_trunk_jpn') {
      if (text.endsWith('_eng')) return 'OPEN_TRUNK_ENG';
      if (text.endsWith('_jpn')) return 'OPEN_TRUNK_JPN';
      if (text.endsWith('_ind')) return 'OPEN_TRUNK_IND';
      return 'OPEN_TRUNK_$suffix';
    }

    if (text == 'check_oil' ||
        text == 'check_oil_level' ||
        text == 'cek_oil_level' ||
        text == 'cek_oli' ||
        text == 'cek_level_oli' ||
        text == 'cara_cek_oil_level' ||
        text == 'cara_cek_oli' ||
        text == 'oil_level') {
      return 'CHECK_OIL_LEVEL';
    }

    if (text == 'change_tire' ||
        text == 'replace_tire' ||
        text == 'ganti_ban' ||
        text == 'mengganti_ban' ||
        text == 'cara_mengganti_ban' ||
        text == 'cara_ganti_ban') {
      return 'CHANGE_TIRE';
    }

    if (text == 'use_fire_extinguisher' ||
        text == 'fire_extinguisher' ||
        text == 'apar' ||
        text == 'gunakan_apar' ||
        text == 'menggunakan_apar' ||
        text == 'cara_menggunakan_apar') {
      return 'USE_FIRE_EXTINGUISHER';
    }

    if (text == 'accident' ||
        text == 'help_accident' ||
        text == 'accident_help' ||
        text == 'menolong_kecelakaan' ||
        text == 'tolong_kecelakaan' ||
        text == 'bantu_kecelakaan' ||
        text == 'cara_menolong_kecelakaan') {
      return 'HELP_ACCIDENT';
    }

    return value.trim().toUpperCase();
  }
}
