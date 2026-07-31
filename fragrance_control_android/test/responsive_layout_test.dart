import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fragrance_control_android/features/fragrance_control/page/fragrance_control_page.dart';

void main() {
  for (final size in [
    const Size(320, 568),
    const Size(360, 800),
    const Size(412, 915),
  ]) {
    testWidgets('fits phone viewport ${size.width}x${size.height}', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: FragranceControlPage(connectOnStart: false),
        ),
      );
      await tester.pump();

      expect(find.text('TOYOTA'), findsOneWidget);
      expect(find.text('In-Car Smart Fragrance'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('fits Samsung-style large text scaling', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) {
          final media = MediaQuery.of(context);
          return MediaQuery(
            data: media.copyWith(
              textScaler: const TextScaler.linear(1.5),
            ),
            child: child!,
          );
        },
        home: const FragranceControlPage(connectOnStart: false),
      ),
    );
    await tester.pump();

    expect(find.text('TOYOTA'), findsOneWidget);
    expect(find.text('Cartridge 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
