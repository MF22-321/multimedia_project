import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:frontend/core/services/multimedia_tcp_server.dart';
import 'package:frontend/core/utils/app_logger.dart';
import 'package:frontend/models/avatar_state.dart';

/// Avatar handler for the RJ45 TCP transport.
///
/// The historical class name is kept to avoid a broad UI rename. This service
/// no longer creates an MQTT connection.
class MqttAvatarService extends ChangeNotifier {
  MqttAvatarService({MultimediaTcpServer? server})
    : _server = server ?? MultimediaTcpServer.instance;

  final MultimediaTcpServer _server;
  StreamSubscription<bool>? _connectionSubscription;

  AvatarState _state = AvatarState.idle;
  String _subtitle = '';
  bool _connected = false;
  bool _registered = false;

  AvatarState get state => _state;
  String get subtitle => _subtitle;
  bool get isConnected => _connected;

  Future<void> connect() async {
    if (_registered) return;
    _registered = true;

    _server.registerHandler('avatar_state', _handleStateCommand);
    _server.registerHandler('avatar_word', _handleWordCommand);
    _server.registerHandler('avatar_reset', _handleResetCommand);

    _connected = _server.hasClients;
    _connectionSubscription = _server.connectionState.listen((connected) {
      if (_connected == connected) return;
      _connected = connected;
      notifyListeners();
    });
    notifyListeners();
    AppLogger.info('avatar_tcp_handlers_registered');
  }

  Future<MultimediaCommandResult> _handleStateCommand(
    Map<String, dynamic> command,
  ) async {
    final value = command['state']?.toString().trim().toLowerCase() ?? '';
    const supported = {'idle', 'listening', 'thinking', 'answering'};
    if (!supported.contains(value)) {
      return MultimediaCommandResult.error(
        'Unsupported avatar state: ${value.isEmpty ? '(empty)' : value}',
      );
    }

    final nextState = AvatarStateX.fromString(value);
    final resetText =
        command['resetText'] == true || command['reset_text'] == true;
    setState(nextState, resetText: resetText);
    return MultimediaCommandResult.success('Avatar state changed to $value');
  }

  Future<MultimediaCommandResult> _handleWordCommand(
    Map<String, dynamic> command,
  ) async {
    final word = (command['word'] ?? command['text'] ?? '').toString().trim();
    if (word.isEmpty) {
      return const MultimediaCommandResult.error('Avatar word is empty');
    }

    appendWord(word);
    return const MultimediaCommandResult.success('Avatar word appended');
  }

  Future<MultimediaCommandResult> _handleResetCommand(
    Map<String, dynamic> command,
  ) async {
    _subtitle = '';
    notifyListeners();
    return const MultimediaCommandResult.success('Avatar subtitle reset');
  }

  void setState(AvatarState nextState, {bool resetText = false}) {
    if (_state == nextState && !resetText) return;

    _state = nextState;
    AppLogger.info('avatar_state_applied state=${nextState.name}');

    if (resetText ||
        nextState == AvatarState.idle ||
        nextState == AvatarState.listening ||
        nextState == AvatarState.thinking) {
      _subtitle = '';
    }

    notifyListeners();
  }

  void appendWord(String word) {
    final cleanWord = word.trim();
    if (cleanWord.isEmpty || _state != AvatarState.answering) return;

    _subtitle = _subtitle.isEmpty ? cleanWord : '$_subtitle $cleanWord';
    notifyListeners();
  }

  @override
  void dispose() {
    _server.unregisterHandler('avatar_state');
    _server.unregisterHandler('avatar_word');
    _server.unregisterHandler('avatar_reset');
    _connectionSubscription?.cancel();
    super.dispose();
  }
}
