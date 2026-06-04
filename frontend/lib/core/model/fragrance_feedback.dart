import 'package:flutter/material.dart';

class FragranceFeedback {
  const FragranceFeedback({
    required this.title,
    required this.message,
    required this.accent,
    required this.icon,
  });

  final String title;
  final String message;
  final Color accent;
  final IconData icon;
}
