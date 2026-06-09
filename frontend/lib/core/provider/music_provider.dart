import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:frontend/core/model/lyric_line.dart';
import 'package:frontend/core/services/lyric_service.dart';
import 'package:frontend/core/services/spotify_connect_service.dart';
import 'package:frontend/core/services/spotify_linux_service.dart';
import 'package:frontend/core/utils/app_logger.dart';

class MusicProvider extends ChangeNotifier {
  final SpotifyDBusService _service = SpotifyDBusService();
  final SpotifyConnectService _connectService = SpotifyConnectService();

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

  DateTime? _lastFetchAt;

  DateTime? _lastCommandAt;

  bool? _commandedPlaying;

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
      final now = DateTime.now();

      final data = await _service.getMetadata();
      final logState = await _readSpotifydLogState();

      final rawTitle = data['title']?.toString() ?? '';

      final rawArtist = data['artist']?.toString() ?? '';

      final newTitle = rawTitle.trim().isEmpty ? 'No Song Playing' : rawTitle;

      final newArtist = rawArtist.trim().isEmpty ? 'Unknown Artist' : rawArtist;

      final newAlbumArt = data['albumArt'] ?? '';

      final dbusPlaying = data['isPlaying'] ?? false;

      final newPosition = data['position'] ?? Duration.zero;

      final newDuration = data['duration'] ?? Duration.zero;

      final newTrackId = data['trackId'] ?? '';

      final sameTrack =
          title == newTitle && artist == newArtist && _trackId == newTrackId;

      var effectivePlaying = dbusPlaying;
      var effectivePosition = newPosition;

      if (logState != null) {
        if (logState.isPlaying != null) {
          effectivePlaying = logState.isPlaying!;
        }

        if (logState.position != null && logState.position! > newPosition) {
          effectivePosition = logState.position!;
        }
      }

      if (_commandedPlaying != null &&
          _lastCommandAt != null &&
          now.difference(_lastCommandAt!).inSeconds < 12) {
        effectivePlaying = _commandedPlaying!;
      }

      if (effectivePlaying &&
          effectivePosition <= currentPosition &&
          sameTrack) {
        final elapsed = _lastFetchAt == null
            ? const Duration(seconds: 1)
            : now.difference(_lastFetchAt!);
        effectivePosition = currentPosition + elapsed;
      }

      if (newDuration > Duration.zero && effectivePosition > newDuration) {
        effectivePosition = newDuration;
      }

      /// =========================
      /// UPDATE MUSIC
      /// =========================
      title = newTitle;

      artist = newArtist;

      albumArt = newAlbumArt;

      isPlaying = effectivePlaying;

      currentPosition = effectivePosition;

      totalDuration = newDuration;

      _trackId = newTrackId;

      _lastFetchAt = now;

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
      if (isPlaying) {
        await pause();
      } else {
        await play();
      }

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
      _markCommandedPlayback(true);

      await _fetchMusic();
    } catch (e) {
      debugPrint('PLAY ERROR => $e');
    }
  }

  Future<void> pause() async {
    try {
      await _service.pause();
      _markCommandedPlayback(false);

      await _fetchMusic();
    } catch (e) {
      debugPrint('PAUSE ERROR => $e');
    }
  }

  Future<void> playUri(String uri) async {
    try {
      final target = uri.trim();
      if (target.isEmpty) {
        return;
      }

      try {
        await _service.openUri(target);
      } catch (e) {
        AppLogger.error('DBus OpenUri unavailable, using Spotify Connect: $e');
        await _connectService.playUri(target);
      }

      _markCommandedPlayback(true);
      currentPosition = Duration.zero;
      notifyListeners();

      await Future.delayed(const Duration(milliseconds: 700));
      await _fetchMusic();
    } catch (e) {
      debugPrint('PLAY URI ERROR => $e');
      rethrow;
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
      try {
        await _service.next();
      } catch (e) {
        AppLogger.error('DBus Next unavailable, using Spotify Connect: $e');
        await _connectService.next();
      }

      _markCommandedPlayback(true);

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
      try {
        await _service.previous();
      } catch (e) {
        AppLogger.error('DBus Previous unavailable, using Spotify Connect: $e');
        await _connectService.previous();
      }

      _markCommandedPlayback(true);

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

  void _markCommandedPlayback(bool playing) {
    _commandedPlaying = playing;
    _lastCommandAt = DateTime.now();
    isPlaying = playing;
    notifyListeners();
  }

  Future<_SpotifydLogState?> _readSpotifydLogState() async {
    try {
      final env = Platform.environment;
      final candidates = [
        env['SPOTIFYD_LOG_PATH'],
        if ((env['MULTIMEDIA_ROOT'] ?? '').isNotEmpty)
          '${env['MULTIMEDIA_ROOT']}/spotifyd.log',
        '../spotifyd.log',
      ].whereType<String>().where((path) => path.trim().isNotEmpty);

      File? file;
      for (final path in candidates) {
        final candidate = File(path);
        if (await candidate.exists()) {
          file = candidate;
          break;
        }
      }

      if (file == null) {
        return null;
      }

      final modified = await file.lastModified();
      if (DateTime.now().difference(modified).inSeconds > 15) {
        return null;
      }

      final size = await file.length();
      final start = size > 131072 ? size - 131072 : 0;
      final input = file.openRead(start);
      final content = await utf8.decoder.bind(input).join();
      final clean = content.replaceAll(RegExp(r'\x1B\[[0-9;]*m'), '');

      bool? playing;
      Duration? position;

      for (final line in clean.split('\n')) {
        final status = RegExp(
          r'updated connect play status playing: (true|false), paused: (true|false)',
        ).firstMatch(line);
        if (status != null) {
          playing = status.group(1) == 'true' && status.group(2) == 'false';
        }

        final paused = RegExp(
          r'handling event Paused .* position_ms: ([0-9]+)',
        ).firstMatch(line);
        if (paused != null) {
          playing = false;
          position = Duration(milliseconds: int.parse(paused.group(1)!));
        }

        final pos = RegExp(
          r'update position to ([0-9]+):([0-9]+)(?::([0-9]+))?',
        ).firstMatch(line);
        if (pos != null) {
          final first = int.parse(pos.group(1)!);
          final second = int.parse(pos.group(2)!);
          final third = pos.group(3);
          position = third == null
              ? Duration(minutes: first, seconds: second)
              : Duration(
                  hours: first,
                  minutes: second,
                  seconds: int.parse(third),
                );
        }
      }

      if (playing == null && position == null) {
        return null;
      }

      return _SpotifydLogState(isPlaying: playing, position: position);
    } catch (_) {
      return null;
    }
  }
}

class _SpotifydLogState {
  const _SpotifydLogState({this.isPlaying, this.position});

  final bool? isPlaying;
  final Duration? position;
}
