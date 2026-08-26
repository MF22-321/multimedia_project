import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/navigation/hmi_page_route.dart';
import 'package:frontend/core/navigation/vehicle_3d_surface_control.dart';
import 'package:frontend/core/services/overlay_service.dart';
import 'package:frontend/core/themes/ambient_motion_control.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    AmbientMotionControl.paused.value = false;
    AmbientMotionControl.inspectionActive.value = false;
    Vehicle3DSurfaceControl.fullScreenContentActive.value = false;
    VideoOverlayService().hide();
  });

  testWidgets('ambient clock follows frames and freezes while paused', (
    tester,
  ) async {
    final clock = AmbientFrameClock(
      interval: const Duration(microseconds: 16666),
      cycle: const Duration(seconds: 1),
    );
    var emissions = 0;
    clock.addListener(() => emissions++);
    clock.enabled = true;

    await tester.pump();
    for (var frame = 0; frame < 5; frame++) {
      await tester.pump(const Duration(microseconds: 16667));
    }

    expect(emissions, greaterThanOrEqualTo(5));
    expect(clock.elapsedSeconds, closeTo(5 / 60, 0.005));

    AmbientMotionControl.paused.value = true;
    final elapsedBeforePause = clock.elapsedSeconds;
    final emissionsBeforePause = emissions;
    await tester.pump(const Duration(seconds: 1));

    expect(emissions, emissionsBeforePause);
    expect(clock.elapsedSeconds, elapsedBeforePause);

    AmbientMotionControl.paused.value = false;
    await tester.pump();
    await tester.pump(const Duration(microseconds: 16667));

    expect(emissions, greaterThan(emissionsBeforePause));
    expect(clock.elapsedSeconds, closeTo(elapsedBeforePause + 1 / 60, 0.005));

    clock.dispose();
  });

  test('foreground interaction owns the frame budget', () {
    AmbientMotionControl.beginInteraction();
    expect(AmbientMotionControl.paused.value, isTrue);

    AmbientMotionControl.endInteraction();
    expect(AmbientMotionControl.paused.value, isFalse);
  });

  testWidgets('HMI navigation reserves the ambient frame budget', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: <NavigatorObserver>[hmiNavigationObserver],
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.push<void>(
              context,
              HmiPageRoute<void>(
                builder: (_) => const Scaffold(body: Text('next')),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(AmbientMotionControl.paused.value, isFalse);

    await tester.tap(find.text('open'));
    await tester.pump();
    expect(AmbientMotionControl.paused.value, isTrue);
    await tester.pump(const Duration(milliseconds: 299));
    expect(AmbientMotionControl.paused.value, isTrue);
    await tester.pump(const Duration(milliseconds: 1));
    expect(AmbientMotionControl.paused.value, isFalse);
    expect(find.text('next'), findsOneWidget);
  });

  testWidgets('SOP overlay claims and releases the native 3D surface', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    final overlay = tester.state<OverlayState>(find.byType(Overlay));
    final service = VideoOverlayService();

    service.showOnOverlay(
      overlayState: overlay,
      videoAsset: 'assets/video_sdr/CaraMenggantiBan_sdr.mp4',
    );
    expect(service.isShowing, isTrue);
    expect(Vehicle3DSurfaceControl.fullScreenContentActive.value, isTrue);

    service.hide();
    expect(service.isShowing, isFalse);
    expect(Vehicle3DSurfaceControl.fullScreenContentActive.value, isFalse);
    await tester.pump(const Duration(milliseconds: 220));
  });
}
