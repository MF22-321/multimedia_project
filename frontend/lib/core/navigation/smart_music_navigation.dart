import 'package:flutter/material.dart';

class SmartMusicSuggestion {
  static final ValueNotifier<String?> suggestedKeyword = ValueNotifier(null);
  static final ValueNotifier<String?> autoPlayKeyword = ValueNotifier(null);
}
