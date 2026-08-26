import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:frontend/core/models/vehicle_3d_mesh.dart';
import 'package:frontend/core/navigation/app_navigation.dart';
import 'package:frontend/core/navigation/vehicle_3d_route_observer.dart';
import 'package:frontend/core/navigation/vehicle_3d_surface_control.dart';
import 'package:frontend/core/services/vehicle_3d_controller.dart';
import 'package:frontend/core/themes/ambient_motion_control.dart';
import 'package:frontend/core/widgets/vehicle_3d_viewer.dart';
import 'package:frontend/features/vehicle_analysis/presentation/vehicle_analysis_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test.vehicle3d/control');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() {
    AppNavigation.currentIndex.value = 2;
    Vehicle3DSurfaceControl.fullScreenContentActive.value = false;
  });

  tearDown(() async {
    AppNavigation.currentIndex.value = 2;
    Vehicle3DSurfaceControl.fullScreenContentActive.value = false;
    messenger.setMockMethodCallHandler(channel, null);
  });

  test(
    'controller initializes native texture and forwards interaction',
    () async {
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        if (call.method == 'initialize') {
          return <String, dynamic>{
            'available': true,
            'textureId': 73,
            'renderer': 'native_opengl',
            'model': 'procedural_veloz_concept_preview',
          };
        }
        return true;
      });
      final controller = Vehicle3DController(channel: channel);

      expect(
        await controller.initialize(width: 800, height: 450, autoRotate: false),
        isTrue,
      );
      expect(controller.textureId, 73);
      expect(controller.renderer, 'native_opengl');
      await controller.setTransform(yaw: 1.2, pitch: 0.2, zoom: 1.4);
      await controller.setAutoRotate(false);
      await controller.setActive(true);
      await controller.reset();

      expect(calls.map((call) => call.method), <String>[
        'initialize',
        'setTransform',
        'setAutoRotate',
        'setActive',
        'reset',
      ]);
      expect(calls.first.arguments, <String, dynamic>{
        'width': 800,
        'height': 450,
        'autoRotate': false,
      });
      controller.dispose();
    },
  );

  test('controller keeps PNG fallback when native renderer fails', () async {
    messenger.setMockMethodCallHandler(channel, (_) async {
      throw PlatformException(code: 'gpu', message: 'renderer unavailable');
    });
    final controller = Vehicle3DController(channel: channel);

    expect(await controller.initialize(), isFalse);
    expect(controller.available, isFalse);
    expect(controller.renderer, 'fallback_png');
    expect(controller.error, contains('renderer unavailable'));
    controller.dispose();
  });

  test('controller forwards focused view and native vehicle taps', () async {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'initializeDirectView') {
        return <String, dynamic>{
          'available': true,
          'renderer': 'gtk_gl_area_zbuffer',
          'model': 'toyota_veloz_2022_glb_hd',
        };
      }
      return true;
    });
    final controller = Vehicle3DController(channel: channel);

    expect(await controller.initializeDirectView(), isTrue);
    await controller.setViewTransform(
      yaw: 2.1,
      pitch: 0.05,
      zoom: 1.48,
      focusX: -0.95,
      focusY: 0.36,
    );

    expect(controller.viewYaw, 2.1);
    expect(controller.viewPitch, 0.05);
    expect(controller.viewZoom, 1.48);
    expect(controller.viewFocusX, -0.95);
    expect(controller.viewFocusY, 0.36);
    expect(controller.viewRevision, 1);
    expect(calls.last.arguments, <String, dynamic>{
      'yaw': 2.1,
      'pitch': 0.05,
      'zoom': 1.48,
      'focusX': -0.95,
      'focusY': 0.36,
    });

    Offset? tappedAt;
    var nativeTapResponded = false;
    var tapRanAfterResponse = false;
    controller.setVehicleTapHandler((position) {
      tappedAt = position;
      tapRanAfterResponse = nativeTapResponded;
    });
    final nativeMessage = const StandardMethodCodec().encodeMethodCall(
      const MethodCall('vehicleTapped', <String, dynamic>{
        'x': 0.24,
        'y': 0.72,
      }),
    );
    await messenger.handlePlatformMessage(channel.name, nativeMessage, (_) {
      nativeTapResponded = true;
    });
    await Future<void>.delayed(Duration.zero);
    expect(tappedAt, const Offset(0.24, 0.72));
    expect(tapRanAfterResponse, isTrue);

    controller.setVehicleTapHandler(null);
    controller.dispose();
  });

  testWidgets('direct renderer never flashes the procedural mini car', (
    tester,
  ) async {
    final initialization = Completer<Map<String, dynamic>>();
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'initializeDirectView') {
        return initialization.future;
      }
      return true;
    });
    final controller = Vehicle3DController(channel: channel);

    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [vehicle3DRouteObserver],
        home: SizedBox(
          width: 450,
          height: 220,
          child: Vehicle3DViewer(
            controller: controller,
            useNativeView: true,
            showBadge: false,
            showResetButton: false,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('vehicle-3d-direct-pending')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('vehicle-3d-canvas')), findsNothing);
    expect(find.byKey(const ValueKey('vehicle-3d-fallback')), findsNothing);
    expect(find.byKey(const ValueKey('vehicle-3d-direct-input')), findsNothing);

    initialization.complete(<String, dynamic>{
      'available': true,
      'renderer': 'gtk_gl_area_zbuffer',
      'model': 'toyota_veloz_2022_glb_hd',
    });
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('vehicle-3d-direct-pending')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('vehicle-3d-canvas')), findsNothing);
    expect(find.byKey(const ValueKey('vehicle-3d-fallback')), findsNothing);
    expect(
      find.byKey(const ValueKey('vehicle-3d-direct-input')),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    controller.dispose();
  });

  testWidgets('direct GPU view forwards bounds, gesture, and visibility', (
    tester,
  ) async {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'initializeDirectView') {
        return <String, dynamic>{
          'available': true,
          'renderer': 'gtk_gl_area_zbuffer',
          'model': 'toyota_veloz_2022_glb_hd',
        };
      }
      return true;
    });
    final controller = Vehicle3DController(channel: channel);
    Offset? tappedAt;

    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [vehicle3DRouteObserver],
        home: Center(
          child: SizedBox(
            width: 450,
            height: 220,
            child: Vehicle3DViewer(
              controller: controller,
              useNativeView: true,
              showBadge: false,
              showResetButton: false,
              onTap: (position) => tappedAt = position,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 250));

    expect(
      find.byKey(const ValueKey('vehicle-3d-direct-input')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('vehicle-3d-canvas')), findsNothing);
    expect(calls.any((call) => call.method == 'setDirectViewBounds'), isTrue);
    final firstBounds = calls.indexWhere(
      (call) => call.method == 'setDirectViewBounds',
    );
    final firstVisible = calls.indexWhere(
      (call) =>
          call.method == 'setDirectViewVisible' &&
          (call.arguments as Map<dynamic, dynamic>)['visible'] == true,
    );
    expect(firstVisible, greaterThan(firstBounds));

    calls.clear();
    Vehicle3DSurfaceControl.fullScreenContentActive.value = true;
    await tester.pump();
    expect(
      calls.any(
        (call) =>
            call.method == 'setDirectViewVisible' &&
            (call.arguments as Map<dynamic, dynamic>)['visible'] == false,
      ),
      isTrue,
      reason: 'A full-screen SOP overlay must park the native car.',
    );
    calls.clear();
    Vehicle3DSurfaceControl.fullScreenContentActive.value = false;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(
      calls.any(
        (call) =>
            call.method == 'setDirectViewVisible' &&
            (call.arguments as Map<dynamic, dynamic>)['visible'] == true,
      ),
      isTrue,
      reason: 'Closing SOP playback should restore the Home car.',
    );

    await tester.tap(find.byKey(const ValueKey('vehicle-3d-direct-input')));
    expect(tappedAt?.dx, closeTo(0.5, 0.01));
    expect(tappedAt?.dy, closeTo(0.5, 0.01));

    final directInput = find.byKey(const ValueKey('vehicle-3d-direct-input'));
    final gesture = await tester.startGesture(tester.getCenter(directInput));
    await gesture.moveBy(const Offset(120, 12));
    await tester.pump(const Duration(milliseconds: 40));
    expect(AmbientMotionControl.paused.value, isTrue);
    await gesture.up();
    expect(AmbientMotionControl.paused.value, isTrue);
    await tester.pump(const Duration(milliseconds: 120));
    expect(AmbientMotionControl.paused.value, isFalse);
    expect(calls.any((call) => call.method == 'setTransform'), isTrue);
    expect(
      calls.any(
        (call) =>
            call.method == 'setInteractionActive' &&
            (call.arguments as Map<dynamic, dynamic>)['active'] == true,
      ),
      isTrue,
    );
    expect(
      calls.any(
        (call) =>
            call.method == 'setInteractionActive' &&
            (call.arguments as Map<dynamic, dynamic>)['active'] == false,
      ),
      isTrue,
    );

    calls.clear();
    controller.setDirectBoundsOverride(const Rect.fromLTWH(24, 96, 700, 420));
    await tester.pump();
    await tester.pump();
    final overlayBounds = calls.lastWhere(
      (call) => call.method == 'setDirectViewBounds',
    );
    expect(overlayBounds.arguments, <String, dynamic>{
      'x': 24,
      'y': 96,
      'width': 700,
      'height': 420,
    });
    expect(
      calls.any(
        (call) =>
            call.method == 'setDirectViewVisible' &&
            (call.arguments as Map<dynamic, dynamic>)['visible'] == true,
      ),
      isTrue,
      reason: 'The moved Tire Pressure surface must be revealed after bounds.',
    );

    calls.clear();
    Vehicle3DSurfaceControl.fullScreenContentActive.value = true;
    await tester.pump();
    expect(
      calls.any(
        (call) =>
            call.method == 'setDirectViewVisible' &&
            (call.arguments as Map<dynamic, dynamic>)['visible'] == false,
      ),
      isTrue,
      reason: 'SOP must also cover a surface borrowed by Tire Pressure.',
    );
    calls.clear();
    Vehicle3DSurfaceControl.fullScreenContentActive.value = false;
    await tester.pump();
    expect(
      calls.any(
        (call) =>
            call.method == 'setDirectViewVisible' &&
            (call.arguments as Map<dynamic, dynamic>)['visible'] == true,
      ),
      isTrue,
      reason: 'Closing SOP must restore the borrowed Tire Pressure surface.',
    );

    // The analysis overlay borrows the persistent surface. A late Home
    // navigation/lifecycle callback may not park it during inspection.
    calls.clear();
    AppNavigation.currentIndex.value = 4;
    await tester.pump();
    expect(
      calls.any(
        (call) =>
            call.method == 'setDirectViewVisible' &&
            (call.arguments as Map<dynamic, dynamic>)['visible'] == false,
      ),
      isFalse,
    );
    AppNavigation.currentIndex.value = 2;
    await tester.pump();

    calls.clear();
    controller.setDirectBoundsOverride(null);
    await tester.pump();
    await tester.pump();
    expect(calls.any((call) => call.method == 'setDirectViewBounds'), isTrue);
    expect(
      calls.any(
        (call) =>
            call.method == 'setDirectViewVisible' &&
            (call.arguments as Map<dynamic, dynamic>)['visible'] == true,
      ),
      isTrue,
      reason: 'Returning Home must reveal the shared surface again.',
    );

    calls.clear();
    AppNavigation.currentIndex.value = 4;
    await tester.pump();
    expect(
      calls.any(
        (call) =>
            call.method == 'setDirectViewVisible' &&
            (call.arguments as Map<dynamic, dynamic>)['visible'] == false,
      ),
      isTrue,
    );
    AppNavigation.currentIndex.value = 2;
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(); // Completes the async bounds MethodChannel callback.
    expect(
      calls.any(
        (call) =>
            call.method == 'setDirectViewVisible' &&
            (call.arguments as Map<dynamic, dynamic>)['visible'] == true,
      ),
      isTrue,
      reason: calls
          .map((call) => '${call.method}: ${call.arguments}')
          .join(', '),
    );

    calls.clear();
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    final pushed = navigator.push<void>(
      MaterialPageRoute<void>(builder: (_) => const Scaffold()),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 250));
    expect(
      calls.any(
        (call) =>
            call.method == 'setDirectViewVisible' &&
            (call.arguments as Map<dynamic, dynamic>)['visible'] == false,
      ),
      isTrue,
    );

    // The direct GtkGLArea sits above Flutter. It must remain hidden for the
    // whole route transition, otherwise it flashes through Driver Select.
    calls.clear();
    navigator.pop();
    await pushed;
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      calls.any(
        (call) =>
            call.method == 'setDirectViewVisible' &&
            (call.arguments as Map<dynamic, dynamic>)['visible'] == true,
      ),
      isFalse,
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 250));
    expect(
      calls.any(
        (call) =>
            call.method == 'setDirectViewVisible' &&
            (call.arguments as Map<dynamic, dynamic>)['visible'] == true,
      ),
      isTrue,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(
      calls.any(
        (call) =>
            call.method == 'setDirectViewVisible' &&
            (call.arguments as Map<dynamic, dynamic>)['visible'] == false,
      ),
      isTrue,
    );
    controller.dispose();
  });

  test('full-detail Toyota Veloz GLB mesh asset is valid', () async {
    final mesh = await Vehicle3DMesh.fromAsset(
      'assets/models/toyota_veloz_2022_source.sdtmesh',
    );

    expect(mesh.vertexCount, 468864);
    expect(mesh.triangleCount, 156288);
    expect(mesh.positions.length, mesh.vertexCount * 3);
    expect(mesh.normals.length, mesh.vertexCount * 3);
    expect(mesh.surfaces.length, mesh.vertexCount);
    expect(mesh.surfaces.any((surface) => (surface & 0xFF) == 0), isTrue);
  });

  testWidgets('viewer displays native Texture when plugin is ready', (
    tester,
  ) async {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'initialize') {
        return <String, dynamic>{
          'available': true,
          'textureId': 91,
          'renderer': 'native_opengl',
          'model': 'procedural_veloz_concept_preview',
        };
      }
      return true;
    });
    final controller = Vehicle3DController(channel: channel);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 640,
            height: 360,
            child: Vehicle3DViewer(
              controller: controller,
              autoRotate: true,
              useNativeTexture: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Texture), findsOneWidget);
    expect(find.text('3D · DRAG / PINCH'), findsOneWidget);
    expect(
      tester.widget<Texture>(find.byType(Texture)).filterQuality,
      FilterQuality.low,
    );
    expect(find.byType(AnimatedSwitcher), findsNothing);
    await tester.drag(find.byType(Texture), const Offset(64, 16));
    await tester.pump(const Duration(milliseconds: 40));
    expect(calls.any((call) => call.method == 'setTransform'), isTrue);
    expect(
      calls.any(
        (call) =>
            call.method == 'setAutoRotate' &&
            (call.arguments as Map<dynamic, dynamic>)['enabled'] == false,
      ),
      isTrue,
    );
    await tester.pump(const Duration(seconds: 4));
    expect(
      calls.any(
        (call) =>
            call.method == 'setAutoRotate' &&
            (call.arguments as Map<dynamic, dynamic>)['enabled'] == true,
      ),
      isTrue,
    );
    await tester.tap(find.byIcon(Icons.threesixty));
    await tester.pump();
    expect(calls.any((call) => call.method == 'reset'), isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets('tire pressure page repositions and reveals shared GPU view', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    // Give this behavior-focused test enough horizontal room that localized
    // diagnostics copy does not obscure gesture assertions with layout noise.
    tester.view.physicalSize = const Size(1600, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return true;
    });
    final controller = Vehicle3DController(channel: channel)..available = true;

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(1280, 720),
        builder: (_, _) => MaterialApp(
          home: VehicleAnalysisPage(
            controller: controller,
            externalNativeView: true,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    final boundsIndex = calls.indexWhere(
      (call) => call.method == 'setDirectViewBounds',
    );
    final visibleIndex = calls.indexWhere(
      (call) =>
          call.method == 'setDirectViewVisible' &&
          (call.arguments as Map<dynamic, dynamic>)['visible'] == true,
    );
    expect(boundsIndex, isNonNegative);
    expect(visibleIndex, greaterThan(boundsIndex));
    expect(
      calls.any(
        (call) =>
            call.method == 'setViewTransform' &&
            (call.arguments as Map<dynamic, dynamic>)['zoom'] == 0.92,
      ),
      isTrue,
    );

    calls.clear();
    final dragTarget = find.byWidgetPredicate(
      (widget) => widget is GestureDetector && widget.onScaleUpdate != null,
    );
    expect(dragTarget, findsOneWidget);
    final gesture = await tester.startGesture(tester.getCenter(dragTarget));
    for (var sample = 0; sample < 12; sample++) {
      await gesture.moveBy(const Offset(4, 1));
    }
    expect(AmbientMotionControl.paused.value, isTrue);
    expect(
      calls.where((call) => call.method == 'setViewTransform'),
      isEmpty,
      reason: 'Pointer samples must be coalesced until the display frame.',
    );
    await tester.pump(const Duration(microseconds: 16667));
    expect(
      calls.where((call) => call.method == 'setViewTransform').length,
      1,
      reason: 'Tire Pressure should send at most one native update per vsync.',
    );
    expect(
      calls.any(
        (call) =>
            call.method == 'setDirectViewVisible' &&
            (call.arguments as Map<dynamic, dynamic>)['visible'] == false,
      ),
      isFalse,
    );
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 120));
    expect(AmbientMotionControl.paused.value, isFalse);

    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets('viewer disables continuous native rotation by default', (
    tester,
  ) async {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'initialize') {
        return <String, dynamic>{
          'available': true,
          'textureId': 92,
          'renderer': 'native_opengl',
          'model': 'procedural_veloz_concept_preview',
        };
      }
      return true;
    });
    final controller = Vehicle3DController(channel: channel);

    await tester.pumpWidget(
      MaterialApp(
        home: Vehicle3DViewer(controller: controller, useNativeTexture: true),
      ),
    );
    await tester.pumpAndSettle();

    final initialize = calls.singleWhere((call) => call.method == 'initialize');
    expect(
      (initialize.arguments as Map<dynamic, dynamic>)['autoRotate'],
      isFalse,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets('viewer uses compositor-safe Flutter canvas by default', (
    tester,
  ) async {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return true;
    });
    final controller = Vehicle3DController(channel: channel);
    Offset? tappedAt;

    await tester.pumpWidget(
      MaterialApp(
        home: Vehicle3DViewer(
          controller: controller,
          onTap: (position) => tappedAt = position,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('vehicle-3d-canvas')), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
    expect(find.byType(Texture), findsNothing);
    // Asset parsing is asynchronous; both labels represent the same Canvas
    // renderer before and after the imported GLB becomes available.
    expect(find.textContaining('DRAG / PINCH'), findsOneWidget);
    expect(calls, isEmpty);
    await tester.tap(find.byKey(const ValueKey('vehicle-3d-canvas')));
    expect(tappedAt?.dx, closeTo(0.5, 0.01));
    expect(tappedAt?.dy, closeTo(0.5, 0.01));
    await tester.drag(
      find.byKey(const ValueKey('vehicle-3d-canvas')),
      const Offset(64, 16),
    );
    await tester.pump();
    expect(calls, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });
}
