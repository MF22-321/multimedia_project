import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import 'package:frontend/core/model/lyric_line.dart';
import 'package:frontend/core/services/lyric_service.dart';
import 'package:frontend/core/services/spotify_linux_service.dart';

class MusicProvider extends ChangeNotifier {
  final SpotifyDBusService _service =
      SpotifyDBusService();

  final LyricsService _lyricsService =
      LyricsService();

  /// =========================
  /// SONG INFO
  /// =========================
  String title = 'No Song Playing';

  String artist = 'Unknown Artist';

  String albumArt = '';

  bool isPlaying = false;

  /// =========================
  /// PLAYBACK
  /// =========================
  Duration currentPosition =
      Duration.zero;

  Duration totalDuration =
      Duration.zero;

  /// =========================
  /// KARAOKE
  /// =========================
  List<LyricLine> syncedLyrics = [];

  int currentLyricIndex = 0;

  /// =========================
  /// TIMERS
  /// =========================
  Timer? _timer;

  Timer? progressTimer;

  /// =========================
  /// START LISTENING
  /// =========================
  void startListening() {
    _fetchMusic();

    startProgressListener();

    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        _fetchMusic();
      },
    );
  }

  /// =========================
  /// REALTIME PROGRESS
  /// =========================
  void startProgressListener() {
    progressTimer?.cancel();

    progressTimer = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) async {
        await getSpotifyPlayback();
      },
    );
  }

  /// =========================
  /// FETCH SONG INFO
  /// =========================
  Future<void> _fetchMusic() async {
    try {
      final data =
          await _service.getMetadata();

      final newTitle =
          data['title'] ??
          'No Song Playing';

      final newArtist =
          data['artist'] ??
          'Unknown Artist';

      /// SONG CHANGED
      final changed =
          title != newTitle ||
          artist != newArtist;

      title = newTitle;

      artist = newArtist;

      albumArt =
          data['albumArt'] ?? '';

      isPlaying =
          data['isPlaying'] ?? false;

      /// LOAD NEW LYRICS
      if (changed) {
        syncedLyrics =
            await _lyricsService.getLyrics(
              title: title,
              artist: artist,
            );

        currentLyricIndex = 0;

        print(
          'SYNCED LYRICS => ${syncedLyrics.length}',
        );
      }

      notifyListeners();
    } catch (e) {
      debugPrint(
        'MUSIC PROVIDER ERROR => $e',
      );
    }
  }

  /// =========================
  /// SPOTIFY PLAYBACK
  /// =========================
  Future<void> getSpotifyPlayback() async {
    try {
      /// CURRENT POSITION
      final positionResult =
          await Process.run(
            'playerctl',
            ['position'],
          );

      final seconds =
          double.tryParse(
            positionResult.stdout
                .toString()
                .trim(),
          );

      if (seconds != null) {
        currentPosition = Duration(
          milliseconds:
              (seconds * 1000).toInt(),
        );
      }

      /// TOTAL DURATION
      final metadataResult =
          await Process.run(
            'playerctl',
            [
              'metadata',
              'mpris:length',
            ],
          );

      final microseconds =
          int.tryParse(
            metadataResult.stdout
                .toString()
                .trim(),
          );

      if (microseconds != null) {
        totalDuration = Duration(
          microseconds: microseconds,
        );
      }

      /// UPDATE KARAOKE
      updateCurrentLyric();

      notifyListeners();
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  /// =========================
  /// UPDATE ACTIVE LYRIC
  /// =========================
  void updateCurrentLyric() {
    for (
      int i = 0;
      i < syncedLyrics.length;
      i++
    ) {
      if (
          currentPosition >=
          syncedLyrics[i].time) {
        currentLyricIndex = i;
      }
    }
  }

  /// =========================
  /// SEEK
  /// =========================
  Future<void> seekTo(
    double value,
  ) async {
    try {
      final targetMilliseconds =
          (totalDuration.inMilliseconds *
                  value)
              .toInt();

      final seconds =
          (targetMilliseconds / 1000);

      await Process.run(
        'playerctl',
        [
          'position',
          seconds.toString(),
        ],
      );

      currentPosition = Duration(
        milliseconds:
            targetMilliseconds,
      );

      updateCurrentLyric();

      notifyListeners();
    } catch (e) {
      debugPrint(
        'SEEK ERROR => $e',
      );
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
      debugPrint(
        'TOGGLE ERROR => $e',
      );
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
      debugPrint(
        'PLAY ERROR => $e',
      );
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
      debugPrint(
        'NEXT ERROR => $e',
      );
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
      debugPrint(
        'PREVIOUS ERROR => $e',
      );
    }
  }

  /// =========================
  /// DISPOSE
  /// =========================
  @override
  void dispose() {
    _timer?.cancel();

    progressTimer?.cancel();

    super.dispose();
  }
}