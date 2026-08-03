import 'package:frontend/core/services/multimedia_tcp_server.dart';
import 'package:frontend/core/utils/app_logger.dart';

typedef SopCommandHandler =
    Future<MultimediaCommandResult> Function(Map<String, dynamic> command);

/// SOP handler registration for the RJ45 TCP transport.
///
/// The class name remains for source compatibility; no MQTT client is created.
class VideoMqttService {
  static final VideoMqttService _instance = VideoMqttService._internal();
  factory VideoMqttService() => _instance;

  VideoMqttService._internal();

  final MultimediaTcpServer _server = MultimediaTcpServer.instance;
  SopCommandHandler? _commandHandler;
  bool _registered = false;

  bool get isConnected => _server.hasClients;

  Future<bool> connect({required SopCommandHandler commandHandler}) async {
    _commandHandler = commandHandler;
    if (!_registered) {
      _server.registerHandler('sop_command', _handleCommand);
      _registered = true;
      AppLogger.info('sop_tcp_handler_registered');
    }
    return _server.isListening;
  }

  Future<MultimediaCommandResult> _handleCommand(
    Map<String, dynamic> command,
  ) async {
    final handler = _commandHandler;
    if (handler == null) {
      return const MultimediaCommandResult.error('SOP video UI is not ready');
    }
    return handler(command);
  }

  void dispose() {
    _server.unregisterHandler('sop_command');
    _commandHandler = null;
    _registered = false;
  }
}
