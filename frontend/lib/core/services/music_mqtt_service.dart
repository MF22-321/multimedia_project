import 'dart:async';

import 'package:frontend/core/navigation/app_navigation.dart';
import 'package:frontend/core/navigation/smart_music_navigation.dart';
import 'package:frontend/core/provider/music_provider.dart';
import 'package:frontend/core/services/multimedia_tcp_server.dart';
import 'package:frontend/core/services/spotify_search_service.dart';
import 'package:frontend/core/utils/app_logger.dart';
import 'package:url_launcher/url_launcher.dart';

/// Music command handler for the RJ45 TCP transport.
///
/// The historical class name is retained for source compatibility. Commands
/// now come exclusively from [MultimediaTcpServer], not an MQTT broker.
class MusicMqttService {
  MusicMqttService._internal();

  static final MusicMqttService _instance = MusicMqttService._internal();

  factory MusicMqttService() => _instance;

  final MultimediaTcpServer _server = MultimediaTcpServer.instance;
  final SpotifySearchService _spotifySearchService = SpotifySearchService();

  MusicProvider? _musicProvider;
  bool _registered = false;
  bool _busy = false;

  bool get isConnected => _server.hasClients;

  Future<bool> connect({required MusicProvider musicProvider}) async {
    _musicProvider = musicProvider;
    if (!_registered) {
      _server.registerHandler('music_command', _handleCommand);
      _registered = true;
      AppLogger.info('music_tcp_handler_registered');
    }
    return _server.isListening;
  }

  Future<MultimediaCommandResult> _handleCommand(
    Map<String, dynamic> command,
  ) async {
    if (_busy) {
      return const MultimediaCommandResult.error(
        'Another music command is still running',
      );
    }

    final provider = _musicProvider;
    if (provider == null) {
      return const MultimediaCommandResult.error(
        'Music playback backend is not ready',
      );
    }

    final action = (command['action'] ?? command['command'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    const supported = {'play', 'pause', 'resume', 'next', 'previous', 'stop'};
    if (!supported.contains(action)) {
      return MultimediaCommandResult.error(
        'Unsupported music action: ${action.isEmpty ? '(empty)' : action}',
      );
    }

    try {
      _busy = true;
      final hasTarget = [
        command['query'],
        command['keyword'],
        command['q'],
        command['uri'],
        command['url'],
      ].any((value) => value?.toString().trim().isNotEmpty == true);

      if (action == 'play' && hasTarget) {
        await _playSearchResult(command, provider);
      } else {
        await provider.executeTransportAction(action);
      }

      return MultimediaCommandResult.success('Music action accepted: $action');
    } catch (error) {
      AppLogger.error('music_tcp_command_failed action=$action error=$error');
      return MultimediaCommandResult.error(
        'Music backend rejected $action: $error',
      );
    } finally {
      _busy = false;
    }
  }

  Future<void> _playSearchResult(
    Map<String, dynamic> command,
    MusicProvider provider,
  ) async {
    final query = (command['query'] ?? command['keyword'] ?? command['q'] ?? '')
        .toString()
        .trim();
    final type = (command['search_type'] ?? command['type'] ?? 'track')
        .toString()
        .trim()
        .toLowerCase();
    final uri = (command['uri'] ?? '').toString().trim();
    final url = (command['url'] ?? '').toString().trim();

    if (uri.isNotEmpty || url.isNotEmpty) {
      _showMusicPageForQuery(query);
      await _launchSpotify(uri.isNotEmpty ? uri : url, provider);
      return;
    }

    if (query.isEmpty) {
      await provider.executeTransportAction('play');
      return;
    }

    _showMusicPageForQuery(query, autoPlay: true);
    final safeType = _safeSpotifySearchType(type);
    final result = await _spotifySearchService.search(query, safeType);
    final target = _firstSpotifyItem(result, safeType);
    if (target == null) {
      throw StateError('No Spotify result for: $query');
    }

    final targetUri = target['uri']?.toString() ?? '';
    final externalUrls = target['external_urls'];
    final externalUrl = externalUrls is Map
        ? externalUrls['spotify']?.toString() ?? ''
        : '';
    await _launchSpotify(
      targetUri.isNotEmpty ? targetUri : externalUrl,
      provider,
    );
  }

  void _showMusicPageForQuery(String? query, {bool autoPlay = false}) {
    final keyword = query?.trim();
    scheduleMicrotask(() {
      AppNavigation.currentIndex.value = 0;
      if (keyword == null || keyword.isEmpty) return;

      if (autoPlay) {
        if (SmartMusicSuggestion.autoPlayKeyword.value == keyword) {
          SmartMusicSuggestion.autoPlayKeyword.value = null;
        }
        SmartMusicSuggestion.autoPlayKeyword.value = keyword;
      }
      if (SmartMusicSuggestion.suggestedKeyword.value == keyword) {
        SmartMusicSuggestion.suggestedKeyword.value = null;
      }
      SmartMusicSuggestion.suggestedKeyword.value = keyword;
    });
  }

  String _safeSpotifySearchType(String type) {
    return const {'artist', 'album', 'playlist', 'track'}.contains(type)
        ? type
        : 'track';
  }

  Map<String, dynamic>? _firstSpotifyItem(
    Map<String, dynamic> result,
    String type,
  ) {
    final container = result['${type}s'];
    if (container is! Map<String, dynamic>) return null;
    final items = container['items'];
    if (items is! List || items.isEmpty) return null;
    final first = items.first;
    return first is Map<String, dynamic> ? first : null;
  }

  Future<void> _launchSpotify(String target, MusicProvider provider) async {
    final trimmedTarget = target.trim();
    if (trimmedTarget.isEmpty) {
      throw ArgumentError('Spotify target is empty');
    }

    final spotifyTarget = trimmedTarget.startsWith('spotify:')
        ? trimmedTarget
        : _spotifyUriFromWebUrl(trimmedTarget);
    if (spotifyTarget != null) {
      await provider.playUri(spotifyTarget);
      provider.startProgressListener();
      return;
    }

    final uri = Uri.parse(trimmedTarget);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      throw StateError('Could not launch music URL');
    }
  }

  String? _spotifyUriFromWebUrl(String target) {
    final uri = Uri.tryParse(target);
    if (uri == null || uri.host != 'open.spotify.com') return null;
    final segments = uri.pathSegments
        .where((segment) => segment.trim().isNotEmpty)
        .toList();
    if (segments.length < 2) return null;

    final typeIndex = segments[0].startsWith('intl-') ? 1 : 0;
    if (segments.length <= typeIndex + 1) return null;
    final type = segments[typeIndex];
    final id = segments[typeIndex + 1];
    return const {'album', 'artist', 'playlist', 'track'}.contains(type)
        ? 'spotify:$type:$id'
        : null;
  }

  void dispose() {
    _server.unregisterHandler('music_command');
    _musicProvider = null;
    _registered = false;
  }
}
