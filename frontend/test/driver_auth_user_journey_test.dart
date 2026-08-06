import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/navigation/app_routes.dart';
import 'package:frontend/core/navigation/driver_session.dart';
import 'package:frontend/features/auth/presentation/page/driver_select_page.dart';

Widget _app({
  required Future<List<String>> Function() loadDrivers,
  required Future<Map<String, dynamic>> Function() loadStatus,
  Duration interval = const Duration(milliseconds: 20),
}) {
  return ScreenUtilInit(
    designSize: const Size(1280, 720),
    builder: (_, __) => MaterialApp(
      home: DriverSelectPage(
        loadDrivers: loadDrivers,
        loadDriverStatus: loadStatus,
        detectionInterval: interval,
      ),
      routes: {
        AppRoutes.home: (_) => const Scaffold(body: Text('HOME_READY')),
        AppRoutes.addDriver: (_) =>
            const Scaffold(body: Text('REGISTER_READY')),
      },
    ),
  );
}

void main() {
  setUp(DriverSession.clear);
  tearDown(DriverSession.clear);

  testWidgets('daftar akun tampil setelah backend berhasil dimuat', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        loadDrivers: () async => ['Alya', 'Budi'],
        loadStatus: () async => {'recognized': false},
      ),
    );
    await tester.pump();

    expect(find.text('Alya'), findsOneWidget);
    expect(find.text('Budi'), findsOneWidget);
    expect(find.text('Tambah Akun'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('login manual menyimpan sesi dan membuka home', (tester) async {
    await tester.pumpWidget(
      _app(
        loadDrivers: () async => ['  Alya  '],
        loadStatus: () async => {'recognized': false},
      ),
    );
    await tester.pump();
    await tester.tap(find.text('  Alya  '));
    await tester.pumpAndSettle();

    expect(DriverSession.currentDriver.value, 'Alya');
    expect(find.text('HOME_READY'), findsOneWidget);
  });

  testWidgets('login wajah hanya menerima identitas yang terdaftar', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        loadDrivers: () async => ['Alya'],
        loadStatus: () async => {'recognized': true, 'driver': 'alya'},
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 25));
    await tester.pumpAndSettle();

    expect(DriverSession.currentDriver.value, 'alya');
    expect(find.text('HOME_READY'), findsOneWidget);
  });

  testWidgets('hasil wajah stale/terhapus tidak dapat login', (tester) async {
    await tester.pumpWidget(
      _app(
        loadDrivers: () async => ['Alya'],
        loadStatus: () async => {'recognized': true, 'driver': 'Mantan User'},
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(DriverSession.currentDriver.value, isNull);
    expect(find.text('HOME_READY'), findsNothing);
    expect(find.text('Mantan User'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('mode tamu membersihkan sesi driver sebelumnya', (tester) async {
    DriverSession.setDriver('Alya');
    await tester.pumpWidget(
      _app(
        loadDrivers: () async => ['Alya'],
        loadStatus: () async => {'recognized': false},
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Masuk sebagai tamu'));
    await tester.pumpAndSettle();

    expect(DriverSession.currentDriver.value, isNull);
    expect(find.text('HOME_READY'), findsOneWidget);
  });

  testWidgets('tombol tambah akun membuka halaman registrasi', (tester) async {
    await tester.pumpWidget(
      _app(
        loadDrivers: () async => [],
        loadStatus: () async => {'recognized': false},
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Tambah Akun'));
    await tester.pumpAndSettle();

    expect(find.text('REGISTER_READY'), findsOneWidget);
  });

  testWidgets('backend daftar gagal tidak membuat halaman crash', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        loadDrivers: () async => throw Exception('backend offline'),
        loadStatus: () async => {'recognized': false},
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Tambah Akun'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
