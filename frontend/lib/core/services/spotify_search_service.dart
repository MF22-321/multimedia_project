import 'dart:convert';

import 'package:frontend/core/utils/app_logger.dart';
import 'package:http/http.dart' as http;

class SpotifySearchService {
  /// CLIENT ID
  static const String clientId = '790dba056ed74025adbf60b5a0bcf45d';

  /// CLIENT SECRET
  static const String clientSecret = '943045b5faea4c60a1a7e1100a232780';

  String? _accessToken;

  /// =========================
  /// GET ACCESS TOKEN
  /// =========================
  Future<String> getAccessToken() async {
    try {
      if (_accessToken != null) {
        return _accessToken!;
      }

      final credentials = base64Encode(utf8.encode('$clientId:$clientSecret'));

      final response = await http.post(
        Uri.parse('https://accounts.spotify.com/api/token'),

        headers: {
          'Authorization': 'Basic $credentials',

          'Content-Type': 'application/x-www-form-urlencoded',
        },

        body: {'grant_type': 'client_credentials'},
      );

      AppLogger.info('TOKEN STATUS : ${response.statusCode}');

      AppLogger.info('TOKEN BODY : ${response.body}');

      final data = jsonDecode(response.body);

      if (data['access_token'] == null) {
        throw Exception('Failed get access token');
      }

      _accessToken = data['access_token'];

      return _accessToken!;
    } catch (e) {
      AppLogger.error('TOKEN ERROR : $e');

      rethrow;
    }
  }

  /// =========================
  /// SEARCH
  /// =========================
  Future<Map<String, dynamic>> search(String query, String type) async {
    try {
      if (query.isEmpty) {
        return {};
      }

      final token = await getAccessToken();

      final response = await http.get(
        Uri.parse(
          'https://api.spotify.com/v1/search?q=${Uri.encodeComponent(query)}&type=$type&limit=10',
        ),

        headers: {'Authorization': 'Bearer $token'},
      );

      AppLogger.info('SEARCH STATUS : ${response.statusCode}');

      AppLogger.info('SEARCH BODY : ${response.body}');

      final data = jsonDecode(response.body);

      return data;
    } catch (e) {
      AppLogger.error('SEARCH ERROR : $e');

      return {};
    }
  }
}
