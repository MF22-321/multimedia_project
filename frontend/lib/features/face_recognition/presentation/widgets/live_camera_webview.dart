import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class LiveCameraWS extends StatefulWidget {
  final String url;
  final double width;
  final double height;

  const LiveCameraWS({
    super.key,
    required this.url,
    this.width = 360,
    this.height = 360,
  });

  @override
  State<LiveCameraWS> createState() => _LiveCameraWSState();
}

class _LiveCameraWSState extends State<LiveCameraWS> {
  WebSocketChannel? _channel;
  Uint8List? _image;
  bool _connected = false;

  @override
  void initState() {
    super.initState();
    _connect();
  }

  void _connect() {
    try {
      _channel = WebSocketChannel.connect(Uri.parse(widget.url));

      _channel!.stream.listen(
        (data) {
          if (data is Uint8List) {
            if (!mounted) return;

            setState(() {
              _image = data;
              _connected = true;
            });
          }
        },
        onError: (e) {
          debugPrint("WS Error: $e");
          _reconnect();
        },
        onDone: () {
          debugPrint("WS Closed");
          _reconnect();
        },
      );
    } catch (e) {
      debugPrint("WS Connect Error: $e");
      _reconnect();
    }
  }

  void _reconnect() {
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      _connect();
    });
  }

  @override
  void dispose() {
    _channel?.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: widget.width,
        height: widget.height,
        color: Colors.black,
        child: _image == null
            ? const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
            : Stack(
                children: [
                  /// 🎥 CAMERA
                  Positioned.fill(
                    child: Image.memory(
                      _image!,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                    ),
                  ),

                  /// 🔲 SCAN BOX
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.greenAccent,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),

                  /// 🔴 STATUS
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Text(
                      _connected ? "LIVE" : "CONNECTING...",
                      style: TextStyle(
                        color: _connected ? Colors.green : Colors.red,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}