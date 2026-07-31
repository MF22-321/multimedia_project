import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fragrance_control_android/features/fragrance_control/page/fragrance_control_page.dart';

void main() {
  testWidgets('shows the clean Toyota fragrance controls', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: FragranceControlPage(connectOnStart: false),
      ),
    );

    expect(find.text('TOYOTA'), findsOneWidget);
    expect(find.text('In-Car Smart Fragrance'), findsOneWidget);
    expect(find.text('PROTOTYPE'), findsOneWidget);
    expect(find.text('POWER OFF'), findsOneWidget);
    expect(find.text('Cartridge 1'), findsOneWidget);
    expect(find.text('Cartridge 2'), findsOneWidget);
  });
}
