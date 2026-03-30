import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../data/services/faceid_api.dart';

class FaceThumbnail extends StatefulWidget {
  const FaceThumbnail({super.key});

  @override
  State<FaceThumbnail> createState() => _FaceThumbnailState();
}

class _FaceThumbnailState extends State<FaceThumbnail> {
  Uint8List? _liveFrame;
  Timer? _timer;
  bool _isFetching = false;

  @override
  void initState() {
    super.initState();
    _startPreview();
  }

  void _startPreview() {
    _timer = Timer.periodic(const Duration(milliseconds: 300), (_) async {
      if (_isFetching) return;

      _isFetching = true;
      try {
        final bytes = await FaceIdApi.captureFace();
        if (!mounted) return;

        setState(() {
          _liveFrame = bytes;
        });
      } catch (_) {
        // diamkan dulu supaya UI tidak spam error
      } finally {
        _isFetching = false;
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 220,
        height: 220,
        color: Colors.grey.shade300,
        child: _liveFrame == null
            ? const Center(child: CircularProgressIndicator())
            : Image.memory(
                _liveFrame!,
                fit: BoxFit.cover,
                gaplessPlayback: true,
              ),
      ),
    );
  }
}