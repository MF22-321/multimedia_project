import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:frontend/core/utils/app_logger.dart';

typedef MultimediaCommandHandler =
    Future<MultimediaCommandResult> Function(Map<String, dynamic> command);

class MultimediaCommandResult {
  const MultimediaCommandResult._({
    required this.isSuccess,
    required this.message,
  });

  const MultimediaCommandResult.success(String message)
    : this._(isSuccess: true, message: message);

  const MultimediaCommandResult.error(String message)
    : this._(isSuccess: false, message: message);

  final bool isSuccess;
  final String message;
}

/// Newline-delimited JSON TCP server used by the Raspberry Pi voice assistant.
///
/// The listening socket remains alive when a client disconnects. Commands from
/// each individual socket are awaited serially to preserve word/command order.
class MultimediaTcpServer {
  MultimediaTcpServer();

  static final MultimediaTcpServer instance = MultimediaTcpServer();

  final Map<String, MultimediaCommandHandler> _handlers = {};
  final Set<Socket> _clients = {};
  final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast(sync: true);

  ServerSocket? _server;
  StreamSubscription<Socket>? _serverSubscription;
  Future<bool>? _startTask;

  bool get isListening => _server != null;
  bool get hasClients => _clients.isNotEmpty;
  int? get boundPort => _server?.port;
  InternetAddress? get boundAddress => _server?.address;
  Stream<bool> get connectionState => _connectionController.stream;

  void registerHandler(String messageType, MultimediaCommandHandler handler) {
    _handlers[_normalizeMessageType(messageType)] = handler;
  }

  void unregisterHandler(String messageType) {
    _handlers.remove(_normalizeMessageType(messageType));
  }

  Future<bool> start({String bindAddress = '0.0.0.0', int port = 5050}) {
    if (isListening) return Future<bool>.value(true);
    if (_startTask != null) return _startTask!;

    _startTask = _start(bindAddress: bindAddress, port: port).whenComplete(() {
      _startTask = null;
    });
    return _startTask!;
  }

  Future<bool> _start({required String bindAddress, required int port}) async {
    try {
      final server = await ServerSocket.bind(bindAddress, port, shared: true);
      _server = server;
      _serverSubscription = server.listen(
        (socket) => unawaited(_serveClient(socket)),
        onError: (Object error, StackTrace stackTrace) {
          AppLogger.error('tcp_listener_error error=$error');
        },
        cancelOnError: false,
      );
      AppLogger.info(
        'tcp_listener_started address=${server.address.address} port=${server.port}',
      );
      return true;
    } catch (error) {
      AppLogger.error(
        'tcp_listener_start_failed address=$bindAddress port=$port error=$error',
      );
      return false;
    }
  }

  Future<void> _serveClient(Socket socket) async {
    final peer = '${socket.remoteAddress.address}:${socket.remotePort}';
    _clients.add(socket);
    _connectionController.add(true);
    AppLogger.info(
      'tcp_client_connected peer=$peer clients=${_clients.length}',
    );

    try {
      final lines = socket
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter());
      await for (final line in lines) {
        await _processLine(socket, line, peer);
      }
    } catch (error) {
      AppLogger.error('tcp_client_error peer=$peer error=$error');
    } finally {
      _clients.remove(socket);
      socket.destroy();
      _connectionController.add(_clients.isNotEmpty);
      AppLogger.info(
        'tcp_client_disconnected peer=$peer clients=${_clients.length}',
      );
    }
  }

  Future<void> _processLine(Socket socket, String line, String peer) async {
    Map<String, dynamic> command;
    try {
      final decoded = jsonDecode(line);
      if (decoded is! Map) {
        await _sendAck(
          socket,
          requestId: null,
          result: const MultimediaCommandResult.error(
            'Payload must be a JSON object',
          ),
          peer: peer,
        );
        return;
      }
      command = Map<String, dynamic>.from(decoded);
    } catch (error) {
      AppLogger.error('tcp_invalid_json peer=$peer error=$error');
      await _sendAck(
        socket,
        requestId: null,
        result: const MultimediaCommandResult.error('Invalid JSON payload'),
        peer: peer,
      );
      return;
    }

    final requestId = command['request_id']?.toString();
    final rawType = command['message_type'] ?? command['type'];
    final messageType = _normalizeMessageType(rawType?.toString() ?? '');
    final skipAck = messageType == 'avatar_word';

    AppLogger.info(
      'tcp_command_received peer=$peer type=$messageType request_id=${requestId ?? '-'}',
    );

    MultimediaCommandResult result;
    final handler = _handlers[messageType];
    if (messageType.isEmpty) {
      result = const MultimediaCommandResult.error('Missing message_type');
    } else if (handler == null) {
      result = MultimediaCommandResult.error(
        'Unsupported or unavailable message type: $messageType',
      );
    } else {
      try {
        result = await handler(command);
      } catch (error, stackTrace) {
        AppLogger.error(
          'tcp_handler_exception type=$messageType request_id=${requestId ?? '-'} '
          'error=$error stack=$stackTrace',
        );
        result = MultimediaCommandResult.error(
          'Command handler failed: $error',
        );
      }
    }

    AppLogger.info(
      'tcp_handler_result type=$messageType request_id=${requestId ?? '-'} '
      'status=${result.isSuccess ? 'success' : 'error'} message=${result.message}',
    );

    if (!skipAck) {
      await _sendAck(socket, requestId: requestId, result: result, peer: peer);
    }
  }

  Future<void> _sendAck(
    Socket socket, {
    required String? requestId,
    required MultimediaCommandResult result,
    required String peer,
  }) async {
    final payload = jsonEncode({
      'message_type': 'ack',
      'request_id': requestId,
      'status': result.isSuccess ? 'success' : 'error',
      'message': result.message,
    });

    try {
      socket.write('$payload\n');
      await socket.flush();
      AppLogger.info(
        'tcp_ack_sent peer=$peer request_id=${requestId ?? '-'} '
        'status=${result.isSuccess ? 'success' : 'error'}',
      );
    } catch (error) {
      AppLogger.error(
        'tcp_ack_failed peer=$peer request_id=${requestId ?? '-'} error=$error',
      );
    }
  }

  String _normalizeMessageType(String value) {
    final normalized = value.trim().toLowerCase();
    switch (normalized) {
      case 'music':
        return 'music_command';
      case 'sop':
        return 'sop_command';
      default:
        return normalized;
    }
  }

  Future<void> stop() async {
    await _serverSubscription?.cancel();
    _serverSubscription = null;

    for (final client in _clients.toList()) {
      client.destroy();
    }
    _clients.clear();
    _connectionController.add(false);

    await _server?.close();
    _server = null;
    AppLogger.info('tcp_listener_stopped');
  }
}
