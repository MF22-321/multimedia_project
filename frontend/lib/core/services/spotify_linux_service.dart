import 'package:dbus/dbus.dart';


class SpotifyDBusService {

  static const String service =
      'org.mpris.MediaPlayer2.spotify';

  static const String path =
      '/org/mpris/MediaPlayer2';

  DBusClient? _client;

  DBusRemoteObject get _playerObject {
    _client ??= DBusClient.session();

    return DBusRemoteObject(
      _client!,

      name: service,

      path: DBusObjectPath(path),
    );
  }

  Future<Map<String, dynamic>> getMetadata() async {

    try {

      final properties =
          await _playerObject.getAllProperties(
        'org.mpris.MediaPlayer2.Player',
      );

      final metadata =
          properties['Metadata'];

      final playback =
          properties['PlaybackStatus'];

      final map =
          metadata?.asStringVariantDict() ?? {};

      final title =
          map['xesam:title']
              ?.asString() ??
          '';

      final artistList =
          map['xesam:artist']
              ?.asStringArray() ??
          [];

      final artist =
          artistList.isNotEmpty
              ? artistList.first
              : '';

      final albumArt =
          map['mpris:artUrl']
              ?.asString() ??
          '';

      final length =
          _readDbusInteger(
        map['mpris:length'],
      );

      final position =
          _readDbusInteger(
        properties['Position'],
      );

      final trackId =
          _readTrackId(
        map['mpris:trackid'],
      );

      return {

        'title': title,
        'artist': artist,
        'albumArt': albumArt,
        'position': Duration(
          microseconds: position,
        ),
        'duration': Duration(
          microseconds: length,
        ),
        'trackId': trackId,
        'isPlaying':
            playback?.asString() ==
                'Playing',
      };

    } catch (e) {

      print("DBUS ERROR => $e");

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

    await _playerObject.callMethod(
      'org.mpris.MediaPlayer2.Player',
      'PlayPause',
      [],
    );
  }

  Future<void> play() async {

    await _playerObject.callMethod(
      'org.mpris.MediaPlayer2.Player',
      'Play',
      [],
    );
  }

  Future<void> next() async {

    await _playerObject.callMethod(
      'org.mpris.MediaPlayer2.Player',
      'Next',
      [],
    );
  }

  Future<void> previous() async {

    await _playerObject.callMethod(
      'org.mpris.MediaPlayer2.Player',
      'Previous',
      [],
    );
  }

  Future<void> seekTo({
    required String trackId,
    required Duration position,
  }) async {

    if (trackId.isEmpty ||
        !trackId.startsWith('/')) {
      return;
    }

    await _playerObject.callMethod(
      'org.mpris.MediaPlayer2.Player',
      'SetPosition',
      [
        DBusObjectPath(trackId),
        DBusInt64(position.inMicroseconds),
      ],
    );
  }

  Future<void> dispose() async {
    await _client?.close();
    _client = null;
  }

  int _readDbusInteger(
    DBusValue? value,
  ) {
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

  String _readTrackId(
    DBusValue? value,
  ) {
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
