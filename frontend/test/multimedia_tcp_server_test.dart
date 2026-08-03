import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/services/multimedia_tcp_server.dart';

void main() {
  late MultimediaTcpServer server;

  setUp(() async {
    server = MultimediaTcpServer();
    expect(await server.start(bindAddress: '127.0.0.1', port: 0), isTrue);
  });

  tearDown(() => server.stop());

  test('dispatches aliases and returns newline-delimited ACK', () async {
    server.registerHandler('sop_command', (command) async {
      expect(command['action'], 'open hood');
      return const MultimediaCommandResult.success('SOP video started');
    });

    final ack = await _sendAndReadAck(server, {
      'type': 'sop',
      'action': 'open hood',
      'request_id': 'sop-1',
    });

    expect(ack['message_type'], 'ack');
    expect(ack['request_id'], 'sop-1');
    expect(ack['status'], 'success');

    server.registerHandler('music_command', (command) async {
      expect(command['action'], 'pause');
      return const MultimediaCommandResult.success('Music paused');
    });
    final musicAck = await _sendAndReadAck(server, {
      'type': 'music',
      'action': 'pause',
      'request_id': 'music-1',
    });
    expect(musicAck['request_id'], 'music-1');
    expect(musicAck['status'], 'success');
  });

  test(
    'malformed JSON returns an error and listener accepts reconnect',
    () async {
      final first = await _sendRawAndReadAck(server, '{not-json}\n');
      expect(first['status'], 'error');
      expect(first['message'], 'Invalid JSON payload');

      server.registerHandler('avatar_reset', (_) async {
        return const MultimediaCommandResult.success('Avatar subtitle reset');
      });
      final second = await _sendAndReadAck(server, {
        'message_type': 'avatar_reset',
        'request_id': 'reset-1',
      });
      expect(second['status'], 'success');
      expect(server.isListening, isTrue);
    },
  );

  test('avatar words have no ACK and preserve per-client order', () async {
    final received = <String>[];
    server.registerHandler('avatar_word', (command) async {
      received.add(command['word'] as String);
      return const MultimediaCommandResult.success('word accepted');
    });
    server.registerHandler('avatar_reset', (_) async {
      received.add('reset');
      return const MultimediaCommandResult.success('reset accepted');
    });

    final socket = await Socket.connect('127.0.0.1', server.boundPort!);
    final lines = StreamIterator<String>(
      socket
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter()),
    );
    socket.write(
      '${jsonEncode({'message_type': 'avatar_word', 'word': 'Hello', 'request_id': 'word-1'})}\n',
    );
    socket.write(
      '${jsonEncode({'message_type': 'avatar_word', 'word': 'world', 'request_id': 'word-2'})}\n',
    );
    socket.write(
      '${jsonEncode({'message_type': 'avatar_reset', 'request_id': 'reset-2'})}\n',
    );
    await socket.flush();

    expect(await lines.moveNext(), isTrue);
    final ack = jsonDecode(lines.current) as Map<String, dynamic>;
    expect(ack['request_id'], 'reset-2');
    expect(received, ['Hello', 'world', 'reset']);

    await lines.cancel();
    socket.destroy();
  });
}

Future<Map<String, dynamic>> _sendAndReadAck(
  MultimediaTcpServer server,
  Map<String, dynamic> command,
) {
  return _sendRawAndReadAck(server, '${jsonEncode(command)}\n');
}

Future<Map<String, dynamic>> _sendRawAndReadAck(
  MultimediaTcpServer server,
  String payload,
) async {
  final socket = await Socket.connect('127.0.0.1', server.boundPort!);
  socket.write(payload);
  await socket.flush();
  final line = await socket
      .cast<List<int>>()
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .first;
  socket.destroy();
  return jsonDecode(line) as Map<String, dynamic>;
}
