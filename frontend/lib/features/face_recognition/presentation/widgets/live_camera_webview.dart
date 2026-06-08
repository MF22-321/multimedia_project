import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class LiveCameraWS extends StatefulWidget {
  final String url;
  final double width;
  final double height;
  final BoxFit fit;
  final int maxFps;

  const LiveCameraWS({
    super.key,
    required this.url,
    this.width = 360,
    this.height = 270,
    this.fit = BoxFit.cover,
    this.maxFps = 16,
  });

  @override
  State<LiveCameraWS> createState() => _LiveCameraWSState();
}

class _LiveCameraWSState extends State<LiveCameraWS> {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Uint8List? _image;
  bool _connected = false;
  bool _framePending = false;
  int _connectGeneration = 0;
  DateTime? _lastFrameAt;

  @override
  void initState() {
    super.initState();
    _connect();
  }

  @override
  void didUpdateWidget(covariant LiveCameraWS oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.url != widget.url) {
      _image = null;
      _connected = false;
      _lastFrameAt = null;
      _connect();
    }
  }

  void _connect() {
    final generation = ++_connectGeneration;

    try {
      _subscription?.cancel();
      _channel?.sink.close();
      _channel = WebSocketChannel.connect(Uri.parse(widget.url));

      _subscription = _channel!.stream.listen(
        (data) {
          if (generation != _connectGeneration) return;

          final bytes = _decodeFrameBytes(data);

          if (bytes != null) {
            final now = DateTime.now();
            final minFrameGapMs = (1000 / widget.maxFps.clamp(1, 30)).round();
            final lastFrameAt = _lastFrameAt;

            if (lastFrameAt != null &&
                now.difference(lastFrameAt).inMilliseconds < minFrameGapMs) {
              return;
            }

            if (!mounted || _framePending) return;
            _framePending = true;
            _lastFrameAt = now;

            WidgetsBinding.instance.addPostFrameCallback((_) {
              _framePending = false;
              if (!mounted) return;

              setState(() {
                _image = bytes;
                _connected = true;
              });
            });
          }
        },
        onError: (e) {
          if (generation != _connectGeneration) return;
          debugPrint("WS Error: $e");
          _reconnect();
        },
        onDone: () {
          if (generation != _connectGeneration) return;
          debugPrint("WS Closed");
          _reconnect();
        },
      );
    } catch (e) {
      debugPrint("WS Connect Error: $e");
      _reconnect();
    }
  }

  Uint8List? _decodeFrameBytes(dynamic data) {
    if (data is Uint8List) return data;
    if (data is List<int>) return Uint8List.fromList(data);
    return null;
  }

  void _reconnect() {
    if (mounted && _connected) {
      setState(() {
        _connected = false;
      });
    }

    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      _connect();
    });
  }

  @override
  void dispose() {
    _connectGeneration++;
    _subscription?.cancel();
    _channel?.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cacheWidth = (widget.width * MediaQuery.devicePixelRatioOf(context))
        .round()
        .clamp(240, 960);
    final cacheHeight = (widget.height * MediaQuery.devicePixelRatioOf(context))
        .round()
        .clamp(240, 960);

    return RepaintBoundary(
      child: ClipRRect(
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
                        fit: widget.fit,
                        gaplessPlayback: true,
                        cacheWidth: cacheWidth,
                        cacheHeight: cacheHeight,
                        filterQuality: FilterQuality.medium,
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
      ),
    );
  }
}
