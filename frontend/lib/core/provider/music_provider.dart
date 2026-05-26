import 'dart:async';

import 'package:flutter/material.dart';
import 'package:frontend/core/model/lyric_line.dart';
import 'package:frontend/core/services/lyric_service.dart';
import 'package:frontend/core/services/spotify_linux_service.dart';
import 'package:frontend/core/utils/app_logger.dart';

class MusicProvider extends ChangeNotifier {
  final SpotifyDBusService _service = SpotifyDBusService();

  final LyricsService _lyricsService = LyricsService();

  /// =========================
  /// MUSIC DATA
  /// =========================
  String title = 'No Song Playing';

  String artist = 'Unknown Artist';

  String albumArt = '';

  bool isPlaying = false;

  Duration currentPosition = Duration.zero;

  Duration totalDuration = Duration.zero;

  String _trackId = '';

  /// =========================
  /// LYRICS
  /// =========================
  List<LyricLine> lyrics = [];

  List<LyricLine> get syncedLyrics => lyrics;

  int get currentLyricIndex {
    if (lyrics.isEmpty) {
      return -1;
    }

    if (lyrics.every((lyric) => lyric.time == Duration.zero)) {
      return 0;
    }

    var activeIndex = 0;

    for (var i = 0; i < lyrics.length; i++) {
      if (lyrics[i].time <= currentPosition) {
        activeIndex = i;
      } else {
        break;
      }
    }

    return activeIndex;
  }

  /// =========================
  /// INTERNAL
  /// =========================
  Timer? _timer;

  String _lastSongKey = '';

  DateTime? _lastLyricsFetchAt;

  bool _lyricsUnavailable = false;

  bool _isFetchingLyrics = false;

  /// =========================
  /// START LISTENING
  /// =========================
  void startListening() {
    if (_timer?.isActive ?? false) {
      return;
    }

    /// FIRST FETCH
    _fetchMusic();

    /// REALTIME UPDATE
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _fetchMusic();
    });
  }

  /// =========================
  /// FETCH MUSIC
  /// =========================
  Future<void> _fetchMusic() async {
    try {
      final data = await _service.getMetadata();

      final rawTitle = data['title']?.toString() ?? '';

      final rawArtist = data['artist']?.toString() ?? '';

      final newTitle = rawTitle.trim().isEmpty ? 'No Song Playing' : rawTitle;

      final newArtist = rawArtist.trim().isEmpty ? 'Unknown Artist' : rawArtist;

      final newAlbumArt = data['albumArt'] ?? '';

      final newPlaying = data['isPlaying'] ?? false;

      final newPosition = data['position'] ?? Duration.zero;

      final newDuration = data['duration'] ?? Duration.zero;

      final newTrackId = data['trackId'] ?? '';

      /// =========================
      /// UPDATE MUSIC
      /// =========================
      title = newTitle;

      artist = newArtist;

      albumArt = newAlbumArt;

      isPlaying = newPlaying;

      currentPosition = newPosition;

      totalDuration = newDuration;

      _trackId = newTrackId;

      /// =========================
      /// SONG KEY
      /// =========================
      final currentSongKey = '$title-$artist';

      /// =========================
      /// FETCH LYRICS ONLY
      /// WHEN SONG CHANGED
      /// =========================
      final shouldRetryLyrics =
          _lyricsUnavailable &&
          (_lastLyricsFetchAt == null ||
              DateTime.now().difference(_lastLyricsFetchAt!).inSeconds >= 20);

      if ((_lastSongKey != currentSongKey || shouldRetryLyrics) &&
          !_isFetchingLyrics) {
        _lastSongKey = currentSongKey;

        _lastLyricsFetchAt = DateTime.now();

        _isFetchingLyrics = true;

        AppLogger.info('FETCHING LYRICS => $title');

        try {
          lyrics = await _lyricsService.getLyrics(title: title, artist: artist);

          /// FALLBACK
          if (lyrics.isEmpty) {
            lyrics = [
              LyricLine(time: Duration.zero, text: '♪ Lyrics unavailable ♪'),
            ];
          }

          _lyricsUnavailable =
              lyrics.length == 1 &&
              lyrics.first.text.contains('Lyrics unavailable');
        } finally {
          _isFetchingLyrics = false;
        }

        AppLogger.info('SYNCED LYRICS => ${lyrics.length}');
      }

      /// =========================
      /// DEBUG
      /// =========================
      AppLogger.info('\n========== MUSIC ==========');
      AppLogger.info('TITLE      : $title');
      AppLogger.info('ARTIST     : $artist');
      AppLogger.info('ALBUM ART  : $albumArt');
      AppLogger.info('PLAYING    : $isPlaying');
      AppLogger.info('===========================\n');

      notifyListeners();
    } catch (e) {
      debugPrint('MUSIC PROVIDER ERROR => $e');
    }
  }

  /// =========================
  /// PLAY / PAUSE
  /// =========================
  Future<void> togglePlay() async {
    try {
      await _service.playPause();

      await _fetchMusic();
    } catch (e) {
      debugPrint('TOGGLE ERROR => $e');
    }
  }

  /// =========================
  /// PLAY
  /// =========================
  Future<void> play() async {
    try {
      await _service.play();

      await _fetchMusic();
    } catch (e) {
      debugPrint('PLAY ERROR => $e');
    }
  }

  void startProgressListener() {
    if (_timer == null || !_timer!.isActive) {
      startListening();
    } else {
      _fetchMusic();
    }
  }

  Future<void> seekTo(double value) async {
    try {
      if (totalDuration.inMilliseconds <= 0) {
        return;
      }

      final target = Duration(
        milliseconds: (totalDuration.inMilliseconds * value.clamp(0.0, 1.0))
            .round(),
      );

      await _service.seekTo(trackId: _trackId, position: target);

      currentPosition = target;
      notifyListeners();

      await _fetchMusic();
    } catch (e) {
      debugPrint('SEEK ERROR => $e');
    }
  }

  /// =========================
  /// NEXT
  /// =========================
  Future<void> next() async {
    try {
      await _service.next();

      await _fetchMusic();
    } catch (e) {
      debugPrint('NEXT ERROR => $e');
    }
  }

  /// =========================
  /// PREVIOUS
  /// =========================
  Future<void> previous() async {
    try {
      await _service.previous();

      await _fetchMusic();
    } catch (e) {
      debugPrint('PREVIOUS ERROR => $e');
    }
  }

  /// =========================
  /// DISPOSE
  /// =========================
  @override
  void dispose() {
    _timer?.cancel();
    unawaited(_service.dispose());

    super.dispose();
  }
}
