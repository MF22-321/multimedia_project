import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/fragrance_control/page/fragrance_control_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FragranceControlApp());
}

class FragranceControlApp extends StatelessWidget {
  const FragranceControlApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Toyota Smart Fragrance',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      builder: (context, child) {
        final media = MediaQuery.of(context);
        final scale = media.textScaler.scale(1).clamp(1.0, 1.1).toDouble();

        return MediaQuery(
          data: media.copyWith(textScaler: TextScaler.linear(scale)),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const FragranceControlPage(),
    );
  }
}
