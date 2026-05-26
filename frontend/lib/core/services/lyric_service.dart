import 'dart:async';
import 'dart:convert';

import 'package:frontend/core/model/lyric_line.dart';
import 'package:frontend/core/utils/app_logger.dart';
import 'package:http/http.dart' as http;

class LyricsService {
  /// CACHE
  final Map<String, List<LyricLine>> _cache = {};

  /// =========================
  /// GET LYRICS
  /// =========================
  Future<List<LyricLine>> getLyrics({
    required String title,
    required String artist,
  }) async {
    try {
      final songKey = '$title-$artist';

      /// =========================
      /// CACHE HIT
      /// =========================
      if (_cache.containsKey(songKey)) {
        AppLogger.info('LYRICS CACHE HIT');

        return _cache[songKey]!;
      }

      for (final queryTitle in _titleQueries(title)) {
        final data = await _searchLyrics(title: queryTitle, artist: artist);

        final syncedResult = _findResultWithLyrics(data, 'syncedLyrics');

        if (syncedResult != null) {
          final parsed = parseLRC(syncedResult);

          if (parsed.isNotEmpty) {
            _cache[songKey] = parsed;

            return parsed;
          }
        }

        final plainResult = _findResultWithLyrics(data, 'plainLyrics');

        if (plainResult != null) {
          final parsed = _parsePlainLyrics(plainResult);

          if (parsed.isNotEmpty) {
            _cache[songKey] = parsed;

            return parsed;
          }
        }
      }

      return _fallbackLyrics();
    } catch (e) {
      AppLogger.error('LYRICS ERROR => $e');

      return _fallbackLyrics();
    }
  }

  Future<List<dynamic>> _searchLyrics({
    required String title,
    required String artist,
  }) async {
    final url = Uri.parse(
      'https://lrclib.net/api/search?track_name=${Uri.encodeComponent(title)}&artist_name=${Uri.encodeComponent(artist)}',
    );

    const timeouts = [Duration(seconds: 6), Duration(seconds: 12)];

    for (final timeout in timeouts) {
      try {
        final response = await http.get(url).timeout(timeout);

        AppLogger.info(
          'LYRICS SEARCH => "$title" / "$artist" (${response.statusCode})',
        );

        if (response.statusCode != 200) {
          return [];
        }

        final data = jsonDecode(response.body);

        if (data is List) {
          return data;
        }

        return [];
      } on TimeoutException {
        AppLogger.error(
          'LYRICS TIMEOUT => "$title" / "$artist" after ${timeout.inSeconds}s',
        );
      }
    }

    return [];
  }

  String? _findResultWithLyrics(List<dynamic> data, String key) {
    for (final item in data) {
      if (item is! Map) {
        continue;
      }

      final lyrics = item[key]?.toString().trim() ?? '';

      if (lyrics.isNotEmpty) {
        AppLogger.info(
          'LYRICS MATCH => ${item['trackName']} - ${item['artistName']}',
        );

        return lyrics;
      }
    }

    return null;
  }

  List<String> _titleQueries(String title) {
    final cleanedTitle = title
        .replaceAll(RegExp(r'\s*[\(\[].*?[\)\]]\s*'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    final queries = <String>[title.trim(), cleanedTitle];

    if (cleanedTitle.startsWith("'")) {
      queries.add(cleanedTitle.substring(1));
    }

    if (cleanedTitle.startsWith("’")) {
      queries.add(cleanedTitle.substring(1));
    }

    return queries.where((query) => query.isNotEmpty).toSet().toList();
  }

  List<LyricLine> _parsePlainLyrics(String plainLyrics) {
    return plainLyrics
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .map((line) => LyricLine(time: Duration.zero, text: line))
        .toList();
  }

  /// =========================
  /// PARSE LRC
  /// =========================
  List<LyricLine> parseLRC(String lrc) {
    final List<LyricLine> lyrics = [];

    final lines = lrc.split('\n');

    for (final line in lines) {
      final regex = RegExp(r'\[(\d{1,2}):(\d{1,2})(?:\.(\d{1,3}))?\](.*)');

      final match = regex.firstMatch(line);

      if (match != null) {
        final minutes = int.parse(match.group(1)!);

        final seconds = int.parse(match.group(2)!);

        final fraction = match.group(3) ?? '0';

        final milliseconds = int.parse(
          fraction.padRight(3, '0').substring(0, 3),
        );

        final text = match.group(4)!.trim();

        final duration = Duration(
          milliseconds: ((minutes * 60) + seconds) * 1000 + milliseconds,
        );

        lyrics.add(LyricLine(time: duration, text: text));
      }
    }

    AppLogger.info('SYNCED LYRICS => ${lyrics.length}');

    lyrics.sort((a, b) => a.time.compareTo(b.time));

    return lyrics;
  }

  /// =========================
  /// FALLBACK
  /// =========================
  List<LyricLine> _fallbackLyrics() {
    return [LyricLine(time: Duration.zero, text: '♪ Lyrics unavailable ♪')];
  }
}
