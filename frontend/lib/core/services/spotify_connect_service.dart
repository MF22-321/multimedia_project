import 'dart:convert';
import 'dart:io';

import 'package:frontend/core/services/spotify_search_service.dart';
import 'package:frontend/core/utils/app_logger.dart';
import 'package:http/http.dart' as http;

class SpotifyConnectService {
  String? _accessToken;
  DateTime? _accessTokenExpiresAt;

  Future<void> playUri(String uri) async {
    final target = uri.trim();
    if (target.isEmpty) {
      return;
    }

    final token = await _getUserAccessToken();
    final deviceId = await _resolveDeviceId(token);

    await _playOnDevice(token: token, deviceId: deviceId, uri: target);
  }

  Future<void> next() async {
    await _playerCommand('next');
  }

  Future<void> previous() async {
    await _playerCommand('previous');
  }

  Future<String> _getUserAccessToken() async {
    final envAccessToken = Platform.environment['SPOTIFY_ACCESS_TOKEN'];
    if (envAccessToken != null && envAccessToken.trim().isNotEmpty) {
      return envAccessToken.trim();
    }

    final cached = _accessToken;
    final expiresAt = _accessTokenExpiresAt;
    if (cached != null &&
        expiresAt != null &&
        DateTime.now().isBefore(expiresAt)) {
      return cached;
    }

    final refreshToken = _readRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      throw Exception(
        'SPOTIFY_REFRESH_TOKEN is not set. Spotifyd MPRIS cannot OpenUri, so direct song play needs Spotify Web API user auth.',
      );
    }

    final credentials = base64Encode(
      utf8.encode(
        '${SpotifySearchService.clientId}:${SpotifySearchService.clientSecret}',
      ),
    );

    final response = await http.post(
      Uri.parse('https://accounts.spotify.com/api/token'),
      headers: {
        'Authorization': 'Basic $credentials',
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {
        'grant_type': 'refresh_token',
        'refresh_token': refreshToken,
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Spotify refresh token failed: ${response.statusCode} ${response.body}',
      );
    }

    final data = jsonDecode(response.body);
    final token = data['access_token']?.toString();
    if (token == null || token.isEmpty) {
      throw Exception('Spotify refresh response has no access_token');
    }

    final expiresIn = data['expires_in'] is int
        ? data['expires_in'] as int
        : 3600;
    _accessToken = token;
    _accessTokenExpiresAt = DateTime.now().add(
      Duration(seconds: expiresIn - 60),
    );

    return token;
  }

  String? _readRefreshToken() {
    final env = Platform.environment;
    final direct = env['SPOTIFY_REFRESH_TOKEN'] ??
        env['SPOTIFY_USER_REFRESH_TOKEN'] ??
        env['SPOTIFY_WEB_API_REFRESH_TOKEN'];
    if (direct != null && direct.trim().isNotEmpty) {
      return direct.trim();
    }

    final tokenPath = env['SPOTIFY_REFRESH_TOKEN_FILE'] ??
        '${env['HOME'] ?? ''}/.config/multimedia_project/spotify_token.json';

    try {
      final file = File(tokenPath.trim());
      if (!file.existsSync()) {
        return null;
      }

      final content = file.readAsStringSync().trim();
      if (content.isEmpty) {
        return null;
      }

      final data = jsonDecode(content);
      if (data is Map) {
        return data['refresh_token']?.toString().trim();
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  Future<String> _resolveDeviceId(String token) async {
    final envDeviceId = Platform.environment['SPOTIFY_DEVICE_ID'];
    if (envDeviceId != null && envDeviceId.trim().isNotEmpty) {
      return envDeviceId.trim();
    }

    final response = await http.get(
      Uri.parse('https://api.spotify.com/v1/me/player/devices'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Spotify devices failed: ${response.statusCode} ${response.body}',
      );
    }

    final data = jsonDecode(response.body);
    final devices = data['devices'];
    if (devices is! List || devices.isEmpty) {
      throw Exception('No Spotify Connect devices found. Start spotifyd first.');
    }

    final preferredName =
        Platform.environment['SPOTIFYD_DEVICE_NAME'] ?? 'Jetson Multimedia';

    Map<String, dynamic>? fallback;
    for (final device in devices) {
      if (device is! Map) {
        continue;
      }

      final map = Map<String, dynamic>.from(device);
      final name = map['name']?.toString() ?? '';
      final isActive = map['is_active'] == true;
      final id = map['id']?.toString() ?? '';
      if (id.isEmpty) {
        continue;
      }

      if (name.toLowerCase() == preferredName.toLowerCase()) {
        return id;
      }

      if (fallback == null || isActive) {
        fallback = map;
      }
    }

    final fallbackId = fallback?['id']?.toString();
    if (fallbackId == null || fallbackId.isEmpty) {
      throw Exception('Spotify devices response has no usable device id');
    }

    AppLogger.info(
      'Spotify Connect preferred device "$preferredName" not found, using ${fallback?['name']}',
    );
    return fallbackId;
  }

  Future<void> _playOnDevice({
    required String token,
    required String deviceId,
    required String uri,
  }) async {
    final isTrack = uri.startsWith('spotify:track:');
    final body = isTrack
        ? {
            'uris': [uri],
          }
        : {
            'context_uri': uri,
          };

    final response = await http.put(
      Uri.parse('https://api.spotify.com/v1/me/player/play?device_id=$deviceId'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode != 204) {
      throw Exception(
        'Spotify play failed: ${response.statusCode} ${response.body}',
      );
    }
  }

  Future<void> _playerCommand(String command) async {
    final token = await _getUserAccessToken();
    final response = await http.post(
      Uri.parse('https://api.spotify.com/v1/me/player/$command'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 204) {
      throw Exception(
        'Spotify $command failed: ${response.statusCode} ${response.body}',
      );
    }
  }
}
