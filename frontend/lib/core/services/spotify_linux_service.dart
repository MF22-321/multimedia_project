import 'package:dbus/dbus.dart';
import 'package:frontend/core/model/lyric_line.dart';

class SpotifyDBusService {

  static const String service =
      'org.mpris.MediaPlayer2.spotify';

  static const String path =
      '/org/mpris/MediaPlayer2';

  Future<Map<String, dynamic>> getMetadata() async {

    try {

      final client = DBusClient.session();

      final object = DBusRemoteObject(
        client,

        name: service,

        path: DBusObjectPath(path),
      );

      final properties =
          await object.getAllProperties(
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

      return {

        'title': title,
        'artist': artist,
        'albumArt': albumArt,
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
        'isPlaying': false,
      };
    }
  }

  Future<void> playPause() async {

    final client = DBusClient.session();

    final object = DBusRemoteObject(
      client,

      name: service,

      path: DBusObjectPath(path),
    );

    await object.callMethod(
      'org.mpris.MediaPlayer2.Player',
      'PlayPause',
      [],
    );
  }

  Future<void> play() async {

  final client = DBusClient.session();

  final object = DBusRemoteObject(
    client,

    name: service,

    path: DBusObjectPath(path),
  );

  await object.callMethod(
    'org.mpris.MediaPlayer2.Player',
    'Play',
    [],
  );
}

  Future<void> next() async {

    final client = DBusClient.session();

    final object = DBusRemoteObject(
      client,

      name: service,

      path: DBusObjectPath(path),
    );

    await object.callMethod(
      'org.mpris.MediaPlayer2.Player',
      'Next',
      [],
    );
  }

  Future<void> previous() async {

    final client = DBusClient.session();

    final object = DBusRemoteObject(
      client,

      name: service,

      path: DBusObjectPath(path),
    );

    await object.callMethod(
      'org.mpris.MediaPlayer2.Player',
      'Previous',
      [],
    );
  }

}