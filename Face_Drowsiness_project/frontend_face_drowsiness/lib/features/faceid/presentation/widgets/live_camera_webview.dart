import 'package:flutter/material.dart';
import 'package:webview_windows/webview_windows.dart';

class LiveCameraWebView extends StatefulWidget {
  final String url;
  final double width;
  final double height;

  const LiveCameraWebView({
    super.key,
    required this.url,
    this.width = 260,
    this.height = 260,
  });

  @override
  State<LiveCameraWebView> createState() => _LiveCameraWebViewState();
}

class _LiveCameraWebViewState extends State<LiveCameraWebView> {
  final WebviewController _controller = WebviewController();
  bool _ready = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  Future<void> _initWebView() async {
    try {
      await _controller.initialize();
      await _controller.setBackgroundColor(Colors.transparent);
      await _controller.loadUrl(widget.url);

      if (!mounted) return;
      setState(() {
        _ready = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: widget.width,
        height: widget.height,
        color: Colors.grey.shade300,
        child: _error != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    "WebView error:\n$_error",
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : !_ready
                ? const Center(child: CircularProgressIndicator())
                : Webview(_controller),
      ),
    );
  }
}