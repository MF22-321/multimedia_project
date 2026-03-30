import 'package:flutter/material.dart';

class ScanFaceButton extends StatefulWidget {
  final VoidCallback onPressed;

  const ScanFaceButton({super.key, required this.onPressed});

  @override
  State<ScanFaceButton> createState() => _ScanFaceButtonState();
}

class _ScanFaceButtonState extends State<ScanFaceButton> {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: widget.onPressed,
        icon: const Icon(Icons.face),
        label: const Text('Scan Face'),
      ),
    );
  }
}