import 'dart:async';
import 'dart:convert';

import 'package:frontend/core/provider/music_provider.dart';
import 'package:frontend/core/services/spotify_search_service.dart';
import 'package:frontend/core/utils/app_logger.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:url_launcher/url_launcher.dart';

class MusicMqttService {
  MusicMqttService._internal();

  static final MusicMqttService _instance = MusicMqttService._internal();

  factory MusicMqttService() => _instance;

  static const String broker = 'broker.hivemq.com';
  static const int port = 1883;
  static const String commandTopic = 'toyota/music/command';

  final SpotifySearchService _spotifySearchService = SpotifySearchService();
  final String _clientId =
      'flutter_music_client_${DateTime.now().millisecondsSinceEpoch}';

  MqttServerClient? _client;
  StreamSubscription? _updatesSubscription;
  Timer? _reconnectTimer;
  Future<bool>? _connectTask;
  MusicProvider? _musicProvider;
  bool _manualDisconnect = false;
  bool _busy = false;

  bool get isConnected {
    return _client?.connectionStatus?.state == MqttConnectionState.connected;
  }

  Future<bool> connect({required MusicProvider musicProvider}) {
    _musicProvider = musicProvider;

    if (isConnected) return Future.value(true);
    if (_connectTask != null) return _connectTask!;

    _connectTask = _connectInternal().whenComplete(() {
      _connectTask = null;
    });

    return _connectTask!;
  }

  Future<bool> _connectInternal() async {
    _manualDisconnect = false;

    final client = MqttServerClient(broker, _clientId);
    _client = client;

    client.port = port;
    client.keepAlivePeriod = 20;
    client.connectTimeoutPeriod = 3000;
    client.logging(on: false);

    client.onConnected = () {
      AppLogger.info('Music MQTT connected');
      client.subscribe(commandTopic, MqttQos.atLeastOnce);
    };

    client.onDisconnected = () {
      AppLogger.info('Music MQTT disconnected');
      if (!_manualDisconnect) _scheduleReconnect();
    };

    try {
      await client.connect();
    } catch (e) {
      AppLogger.error('Music MQTT connect failed: $e');
      client.disconnect();
      _scheduleReconnect();
      return false;
    }

    await _updatesSubscription?.cancel();
    _updatesSubscription = client.updates?.listen(_handleMessages);

    if (!isConnected) _scheduleReconnect();
    return isConnected;
  }

  void _handleMessages(List<MqttReceivedMessage<MqttMessage>> events) {
    if (events.isEmpty) return;

    for (final event in events) {
      final message = event.payload as MqttPublishMessage;
      if (message.header?.retain == true) {
        AppLogger.info('Music MQTT retained command ignored');
        continue;
      }

      final payload = MqttPublishPayload.bytesToStringAsString(
        message.payload.message,
      ).trim();

      if (payload.isEmpty) continue;

      AppLogger.info('Music MQTT payload: $payload');
      unawaited(_handlePayload(payload));
    }
  }

  Future<void> _handlePayload(String payload) async {
    if (_busy) {
      AppLogger.info('Music MQTT command skipped: another command is running');
      return;
    }

    final provider = _musicProvider;
    if (provider == null) {
      AppLogger.error('Music MQTT skipped: MusicProvider is not ready');
      return;
    }

    try {
      _busy = true;
      final command = _parseCommand(payload);
      if (command == null) return;

      final action = (command['action'] ?? command['command'] ?? '')
          .toString()
          .trim()
          .toLowerCase();

      switch (action) {
        case 'play':
        case 'search':
        case 'play_spotify':
        case 'setel':
        case 'putar':
          await _playSearchResult(command, provider);
          break;
        case 'resume':
          await provider.play();
          provider.startProgressListener();
          break;
        case 'pause':
          if (provider.isPlaying) {
            await provider.togglePlay();
          }
          break;
        case 'toggle':
        case 'play_pause':
          await provider.togglePlay();
          break;
        case 'next':
        case 'skip':
          await provider.next();
          break;
        case 'previous':
        case 'prev':
          await provider.previous();
          break;
        default:
          AppLogger.info('Music MQTT unknown action: $action');
      }
    } catch (e) {
      AppLogger.error('Music MQTT command failed: $e');
    } finally {
      _busy = false;
    }
  }

  Map<String, dynamic>? _parseCommand(String payload) {
    try {
      final data = jsonDecode(payload);
      if (data is Map<String, dynamic>) return data;
    } catch (_) {
      final text = payload.trim();
      if (text.isNotEmpty) {
        return {'action': 'play', 'query': text, 'type': 'track'};
      }
    }

    return null;
  }

  Future<void> _playSearchResult(
    Map<String, dynamic> command,
    MusicProvider provider,
  ) async {
    final query = (command['query'] ?? command['keyword'] ?? command['q'] ?? '')
        .toString()
        .trim();
    final type = (command['type'] ?? 'track').toString().trim().toLowerCase();
    final uri = (command['uri'] ?? '').toString().trim();
    final url = (command['url'] ?? '').toString().trim();

    if (uri.isNotEmpty || url.isNotEmpty) {
      await _launchSpotify(uri.isNotEmpty ? uri : url, provider);
      return;
    }

    if (query.isEmpty) {
      await provider.play();
      provider.startProgressListener();
      return;
    }

    final safeType = _safeSpotifySearchType(type);
    final result = await _spotifySearchService.search(query, safeType);
    final target = _firstSpotifyItem(result, safeType);

    if (target == null) {
      AppLogger.info('Music MQTT no Spotify result for: $query');
      return;
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

  String _safeSpotifySearchType(String type) {
    switch (type) {
      case 'artist':
      case 'album':
      case 'playlist':
      case 'track':
        return type;
      default:
        return 'track';
    }
  }

  Map<String, dynamic>? _firstSpotifyItem(
    Map<String, dynamic> result,
    String type,
  ) {
    final key = '${type}s';
    final container = result[key];
    if (container is! Map<String, dynamic>) return null;

    final items = container['items'];
    if (items is! List || items.isEmpty) return null;

    final first = items.first;
    if (first is Map<String, dynamic>) return first;
    return null;
  }

  Future<void> _launchSpotify(String target, MusicProvider provider) async {
    if (target.trim().isEmpty) return;

    final uri = Uri.parse(target);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      AppLogger.error('Music MQTT failed to launch Spotify target: $target');
      return;
    }

    await Future.delayed(const Duration(milliseconds: 1200));
    await provider.play();
    provider.startProgressListener();
  }

  void _scheduleReconnect() {
    if (_manualDisconnect || isConnected || _reconnectTimer?.isActive == true) {
      return;
    }

    _reconnectTimer = Timer(const Duration(seconds: 2), () {
      final provider = _musicProvider;
      if (_manualDisconnect || isConnected || provider == null) return;
      connect(musicProvider: provider);
    });
  }

  void dispose() {
    _manualDisconnect = true;
    _reconnectTimer?.cancel();
    _updatesSubscription?.cancel();
    _client?.disconnect();
  }
}
