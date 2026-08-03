import 'package:dbus/dbus.dart';
import 'package:frontend/core/utils/app_logger.dart';

class SpotifyDBusService {
  static const String service = 'org.mpris.MediaPlayer2.spotify';

  static const String path = '/org/mpris/MediaPlayer2';

  DBusClient? _client;

  DBusClient get _sessionClient {
    _client ??= DBusClient.session();
    return _client!;
  }

  Future<DBusRemoteObject> _playerObject() async {
    final name = await _resolvePlayerService();
    return DBusRemoteObject(
      _sessionClient,
      name: name,
      path: DBusObjectPath(path),
    );
  }

  Future<String> _resolvePlayerService() async {
    final names = await _sessionClient.listNames();
    final players = names
        .where((name) => name.startsWith('org.mpris.MediaPlayer2.'))
        .toList();

    if (players.contains(service)) {
      return service;
    }

    for (final keyword in ['spotifyd', 'spotify']) {
      final match = players.where(
        (name) => name.toLowerCase().contains(keyword),
      );
      if (match.isNotEmpty) {
        return match.first;
      }
    }

    throw Exception(
      'No Spotify MPRIS player found. Start spotifyd with --use-mpris=true.',
    );
  }

  Future<Map<String, dynamic>> getMetadata() async {
    try {
      final playerObject = await _playerObject();
      final properties = await playerObject.getAllProperties(
        'org.mpris.MediaPlayer2.Player',
      );

      final metadata = properties['Metadata'];

      final playback = properties['PlaybackStatus'];

      final map = metadata?.asStringVariantDict() ?? {};

      final title = map['xesam:title']?.asString() ?? '';

      final artistList = map['xesam:artist']?.asStringArray() ?? [];

      final artist = artistList.isNotEmpty ? artistList.first : '';

      final albumArt = map['mpris:artUrl']?.asString() ?? '';

      final length = _readDbusInteger(map['mpris:length']);

      final position = _readDbusInteger(properties['Position']);

      final trackId = _readTrackId(map['mpris:trackid']);

      return {
        'title': title,
        'artist': artist,
        'albumArt': albumArt,
        'position': Duration(microseconds: position),
        'duration': Duration(microseconds: length),
        'trackId': trackId,
        'isPlaying': playback?.asString() == 'Playing',
      };
    } catch (e) {
      AppLogger.error("DBUS ERROR => $e");

      return {
        'title': '',
        'artist': '',
        'albumArt': '',
        'position': Duration.zero,
        'duration': Duration.zero,
        'trackId': '',
        'isPlaying': false,
      };
    }
  }

  Future<void> playPause() async {
    final playerObject = await _playerObject();
    await playerObject.callMethod(
      'org.mpris.MediaPlayer2.Player',
      'PlayPause',
      [],
    );
  }

  Future<void> play() async {
    final playerObject = await _playerObject();
    await playerObject.callMethod('org.mpris.MediaPlayer2.Player', 'Play', []);
  }

  Future<void> pause() async {
    final playerObject = await _playerObject();
    await playerObject.callMethod('org.mpris.MediaPlayer2.Player', 'Pause', []);
  }

  Future<void> stop() async {
    final playerObject = await _playerObject();
    await playerObject.callMethod('org.mpris.MediaPlayer2.Player', 'Stop', []);
  }

  Future<void> openUri(String uri) async {
    final playerObject = await _playerObject();
    await playerObject.callMethod('org.mpris.MediaPlayer2', 'OpenUri', [
      DBusString(uri),
    ]);
  }

  Future<void> next() async {
    final playerObject = await _playerObject();
    await playerObject.callMethod('org.mpris.MediaPlayer2.Player', 'Next', []);
  }

  Future<void> previous() async {
    final playerObject = await _playerObject();
    await playerObject.callMethod(
      'org.mpris.MediaPlayer2.Player',
      'Previous',
      [],
    );
  }

  Future<void> seekTo({
    required String trackId,
    required Duration position,
  }) async {
    if (trackId.isEmpty || !trackId.startsWith('/')) {
      return;
    }

    final playerObject = await _playerObject();
    await playerObject.callMethod(
      'org.mpris.MediaPlayer2.Player',
      'SetPosition',
      [DBusObjectPath(trackId), DBusInt64(position.inMicroseconds)],
    );
  }

  Future<void> dispose() async {
    await _client?.close();
    _client = null;
  }

  int _readDbusInteger(DBusValue? value) {
    if (value == null) {
      return 0;
    }

    switch (value.signature.value) {
      case 'x':
        return value.asInt64();
      case 't':
        return value.asUint64();
      case 'i':
        return value.asInt32();
      case 'u':
        return value.asUint32();
      case 'n':
        return value.asInt16();
      case 'q':
        return value.asUint16();
      case 'y':
        return value.asByte();
      default:
        return 0;
    }
  }

  String _readTrackId(DBusValue? value) {
    if (value == null) {
      return '';
    }

    switch (value.signature.value) {
      case 'o':
        return value.asObjectPath().value;
      case 's':
        return value.asString();
      default:
        return '';
    }
  }
}
