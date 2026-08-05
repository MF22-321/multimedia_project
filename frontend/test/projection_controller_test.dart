import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/projection/data/projection_backend.dart';
import 'package:frontend/features/projection/domain/projection_models.dart';
import 'package:frontend/features/projection/presentation/projection_controller.dart';
import 'package:frontend/features/projection/presentation/projection_page.dart';

void main() {
  test('projection status parses native bridge payload', () {
    final status = ProjectionStatus.fromMap({
      'state': 'active',
      'target': 'android_auto',
      'textureId': 42,
      'sdkAvailable': true,
      'simulation': false,
      'transport': 'wired_usb',
      'usbPhoneDetected': true,
      'usbAccessoryMode': true,
      'usbDeviceName': 'Pixel_8',
      'usbVendorId': '18d1',
      'usbProductId': '2d00',
      'message': 'ready',
    });

    expect(status.state, ProjectionConnectionState.active);
    expect(status.target, ProjectionTarget.androidAuto);
    expect(status.textureId, 42);
    expect(status.sdkAvailable, isTrue);
    expect(status.isActive, isTrue);
    expect(status.usbPhoneDetected, isTrue);
    expect(status.usbAccessoryMode, isTrue);
    expect(status.transport, ProjectionTransport.wiredUsb);
    expect(status.usbIdentifier, '18d1:2d00');
    expect(status.wiredAndroidAutoReady, isTrue);
  });

  test('controller forwards lifecycle commands and preserves status', () async {
    final backend = _FakeProjectionBackend();
    final controller = ProjectionController(
      backend: backend,
      pollInterval: const Duration(days: 1),
    );

    await controller.initialize();
    expect(controller.status.state, ProjectionConnectionState.idle);

    await controller.connect(
      ProjectionTarget.carPlay,
      transport: ProjectionTransport.wiredUsb,
    );
    expect(controller.status.target, ProjectionTarget.carPlay);
    expect(controller.status.isActive, isTrue);

    await controller.suspend();
    expect(controller.status.state, ProjectionConnectionState.suspended);

    await controller.resume();
    expect(controller.status.state, ProjectionConnectionState.active);

    await controller.disconnect();
    expect(controller.status.state, ProjectionConnectionState.disconnected);
    expect(backend.disconnectCalls, 1);
    controller.dispose();
  });

  testWidgets('projection page can launch Android Auto simulator', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final backend = _FakeProjectionBackend();
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(1280, 720),
        builder: (context, child) => MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: ProjectionPage(backend: backend),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('connect-android-auto')));
    await tester.pump();

    expect(backend.startedTarget, ProjectionTarget.androidAuto);
    expect(backend.startedTransport, ProjectionTransport.wiredUsb);
    expect(
      find.byKey(const ValueKey('projection-simulator-surface')),
      findsOneWidget,
    );
    expect(find.text('Android Auto'), findsWidgets);
    expect(find.byKey(const ValueKey('wired-usb-status')), findsOneWidget);
  });

  testWidgets('projection page reports a detected wired Android phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final backend = _FakeProjectionBackend()
      ..status = const ProjectionStatus(
        state: ProjectionConnectionState.idle,
        simulation: true,
        usbPhoneDetected: true,
        usbDeviceName: 'Pixel_8',
        usbVendorId: '18d1',
        usbProductId: '4ee7',
      );
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(1280, 720),
        builder: (context, child) => MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: ProjectionPage(backend: backend),
        ),
      ),
    );
    await tester.pump();

    expect(find.textContaining('Pixel 8 · 18d1:4ee7'), findsOneWidget);
  });

  testWidgets('Android Auto launcher opens a dedicated Android-only page', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final backend = _FakeProjectionBackend();
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(1280, 720),
        builder: (context, child) => MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: ProjectionPage(
            backend: backend,
            initialTarget: ProjectionTarget.androidAuto,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('connect-android-auto')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('connect-android-auto-wireless')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('connect-carplay')), findsNothing);
    expect(backend.startedTarget, isNull);
  });

  testWidgets('Android Auto launcher selects wireless transport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final backend = _FakeProjectionBackend()
      ..status = const ProjectionStatus(
        state: ProjectionConnectionState.idle,
        sdkAvailable: true,
        simulation: false,
      );
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(1280, 720),
        builder: (context, child) => MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: ProjectionPage(
            backend: backend,
            initialTarget: ProjectionTarget.androidAuto,
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(
      find.byKey(const ValueKey('connect-android-auto-wireless')),
    );
    await tester.pump();

    expect(backend.startedTarget, ProjectionTarget.androidAuto);
    expect(backend.startedTransport, ProjectionTransport.wireless);
  });

  testWidgets('CarPlay launcher opens a dedicated Apple-only page', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final backend = _FakeProjectionBackend();
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(1280, 720),
        builder: (context, child) => MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: ProjectionPage(
            backend: backend,
            initialTarget: ProjectionTarget.carPlay,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('connect-carplay')), findsOneWidget);
    expect(find.byKey(const ValueKey('connect-android-auto')), findsNothing);
    expect(
      find.byKey(const ValueKey('carplay-connection-status')),
      findsOneWidget,
    );
    expect(backend.startedTarget, isNull);
  });

  testWidgets('native Android Auto session uses the fullscreen texture', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final backend = _FakeProjectionBackend()
      ..status = const ProjectionStatus(
        state: ProjectionConnectionState.active,
        target: ProjectionTarget.androidAuto,
        textureId: 42,
        sdkAvailable: true,
        simulation: false,
        message: 'Android Auto aktif',
      );
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(1280, 720),
        builder: (context, child) => MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: ProjectionPage(backend: backend),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('projection-fullscreen')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('projection-native-texture')),
      findsOneWidget,
    );
    expect(find.text('Pilih platform'), findsNothing);
    expect(find.text('Android Auto'), findsNothing);
    expect(find.text('Kembali ke HMI'), findsNothing);
    expect(
      find.byKey(const ValueKey('projection-fullscreen-back')),
      findsOneWidget,
    );
    final backSurface = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('projection-back-surface')),
    );
    final backDecoration = backSurface.decoration as BoxDecoration;
    expect(backDecoration.color, const Color(0xFF101318));
    expect(backDecoration.color!.a, 1.0);

    await tester.tap(
      find.byKey(const ValueKey('projection-fullscreen-disconnect')),
    );
    await tester.pump();
    expect(backend.disconnectCalls, 1);
  });
}

class _FakeProjectionBackend implements ProjectionBackend {
  ProjectionStatus status = const ProjectionStatus(
    state: ProjectionConnectionState.idle,
    simulation: true,
    message: 'simulator ready',
  );
  ProjectionTarget? startedTarget;
  ProjectionTransport? startedTransport;
  int disconnectCalls = 0;

  @override
  Future<ProjectionStatus> initialize() async => status;

  @override
  Future<ProjectionStatus> start(
    ProjectionTarget target, {
    ProjectionTransport transport = ProjectionTransport.wiredUsb,
  }) async {
    startedTarget = target;
    startedTransport = transport;
    status = ProjectionStatus(
      state: ProjectionConnectionState.active,
      target: target,
      transport: transport,
      simulation: true,
      message: 'active',
    );
    return status;
  }

  @override
  Future<ProjectionStatus> disconnect() async {
    disconnectCalls++;
    status = const ProjectionStatus(
      state: ProjectionConnectionState.disconnected,
      simulation: true,
    );
    return status;
  }

  @override
  Future<ProjectionStatus> getStatus() async => status;

  @override
  Future<ProjectionStatus> resume() async {
    status = status.copyWith(state: ProjectionConnectionState.active);
    return status;
  }

  @override
  Future<void> sendTouch({
    required double x,
    required double y,
    required String action,
  }) async {}

  @override
  Future<ProjectionStatus> suspend() async {
    status = status.copyWith(state: ProjectionConnectionState.suspended);
    return status;
  }
}
