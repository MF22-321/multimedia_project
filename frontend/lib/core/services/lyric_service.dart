import 'dart:convert';

import 'package:frontend/core/model/lyric_line.dart';
import 'package:http/http.dart' as http;

class LyricsService {
  /// =========================
  /// GET SYNCED LYRICS
  /// =========================
  Future<List<LyricLine>> getLyrics({
    required String title,
    required String artist,
  }) async {
    try {
      final url = Uri.parse(
        'https://lrclib.net/api/search?track_name=${Uri.encodeComponent(title)}&artist_name=${Uri.encodeComponent(artist)}',
      );

      final response = await http
          .get(url)
          .timeout(
            const Duration(seconds: 5),
          );

      print(
        'LYRICS STATUS => ${response.statusCode}',
      );

      /// API ERROR
      if (response.statusCode != 200) {
        return [];
      }

      final data = jsonDecode(response.body);

      /// EMPTY
      if (data == null || data.isEmpty) {
        return [];
      }

      /// GET SYNCED LRC
      final lyrics =
          data[0]['syncedLyrics'] ?? '';

      if (lyrics.isEmpty) {
        return [];
      }

      print('\n========== RAW LRC ==========');
      print(lyrics);
      print('=============================\n');

      /// PARSE LRC
      return parseLRC(lyrics);
    } catch (e) {
      print(
        'LYRICS ERROR => $e',
      );

      return [];
    }
  }

  /// =========================
  /// PARSE LRC
  /// =========================
  List<LyricLine> parseLRC(
    String lrc,
  ) {
    final List<LyricLine> lyrics = [];

    final lines = lrc.split('\n');

    for (final line in lines) {
      final regex = RegExp(
        r'\[(\d+):(\d+\.\d+)\](.*)',
      );

      final match =
          regex.firstMatch(line);

      if (match != null) {
        final minutes = int.parse(
          match.group(1)!,
        );

        final seconds = double.parse(
          match.group(2)!,
        );

        final text =
            match.group(3)!.trim();

        final duration = Duration(
          milliseconds:
              (((minutes * 60) + seconds) *
                      1000)
                  .toInt(),
        );

        lyrics.add(
          LyricLine(
            time: duration,
            text: text,
          ),
        );
      }
    }

    print(
      'PARSED LYRICS => ${lyrics.length}',
    );

    return lyrics;
  }
}