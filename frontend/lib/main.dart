import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:frontend/core/navigation/app_routes.dart';
import 'package:frontend/core/navigation/hmi_page_route.dart';
import 'package:frontend/core/navigation/vehicle_3d_route_observer.dart';
import 'package:frontend/core/provider/gps_provider.dart';
import 'package:frontend/core/provider/music_provider.dart';
import 'package:frontend/core/provider/pothole_provider.dart';
import 'package:frontend/features/personalize/presentation/page/personalize_page.dart';
import 'package:frontend/features/projection/domain/projection_models.dart';
import 'package:frontend/features/projection/presentation/projection_page.dart';
import 'package:frontend/core/services/multimedia_tcp_server.dart';
import 'package:frontend/features/smart_fragrance/page/smart_fragrance_page.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';
import 'package:provider/provider.dart';

import 'package:frontend/features/auth/presentation/page/add_driver_page.dart';
import 'package:frontend/features/auth/presentation/page/driver_select_page.dart';
import 'package:frontend/features/home/presentation/page/home_page.dart';
import 'package:frontend/features/odd_even/presentation/pages/odd_event_page.dart';
import 'package:frontend/features/warning/presentation/pages/warning_page.dart';
import 'features/boot/presentation/pages/boot_page.dart';

import 'package:frontend/features/video/provider/video_provider.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  final tcpPort =
      int.tryParse(Platform.environment['MULTIMEDIA_TCP_PORT'] ?? '') ?? 5050;
  await MultimediaTcpServer.instance.start(port: tcpPort);

  final isolatedDataPath = Platform.environment['HMI_ISOLATED_DATA_PATH'];
  if (isolatedDataPath != null && isolatedDataPath.isNotEmpty) {
    await Directory(isolatedDataPath).create(recursive: true);
    Hive.init(isolatedDataPath);
  } else {
    await Hive.initFlutter();
  }
  await Hive.openBox('drivers');

  await windowManager.ensureInitialized();

  /// Landscape mode
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  /// Hide status bar
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  /// Head-unit fullscreen mode.
  const WindowOptions windowOptions = WindowOptions(
    fullScreen: true,
    skipTaskbar: true,
    titleBarStyle: TitleBarStyle.hidden,
    backgroundColor: Colors.black,
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    /// tampilkan window
    await windowManager.show();

    /// fokus
    await windowManager.focus();

    await windowManager.setFullScreen(true);

    await windowManager.setResizable(false);
  });

  runApp(
    MyApp(
      projectionAutostart:
          Platform.environment['PROJECTION_AUTOSTART_ANDROID_AUTO'] == '1',
      homeAutostart:
          Platform.environment['HMI_AUTOSTART_HOME'] == '1' ||
          args.contains('--hmi-autostart-home'),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
    this.projectionAutostart = false,
    this.homeAutostart = false,
  });

  final bool projectionAutostart;
  final bool homeAutostart;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) {
            final provider = MusicProvider();

            provider.startListening();

            return provider;
          },
        ),

        ChangeNotifierProvider(create: (_) => VideoProvider()),
        ChangeNotifierProvider(create: (_) => GPSProvider()),
        ChangeNotifierProvider(create: (_) => PotholeProvider()),
      ],
      child: ScreenUtilInit(
        designSize: const Size(1280, 720),
        minTextAdapt: true,
        splitScreenMode: true,
        builder: (context, child) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: "Toyota Multimedia System",
            navigatorObservers: [vehicle3DRouteObserver, hmiNavigationObserver],

            builder: (context, child) {
              return MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(1.0)),
                child: child!,
              );
            },

            theme: ThemeData(
              brightness: Brightness.dark,
              scaffoldBackgroundColor: Colors.black,
              fontFamily: 'Roboto',
              useMaterial3: true,
              pageTransitionsTheme: const PageTransitionsTheme(
                builders: <TargetPlatform, PageTransitionsBuilder>{
                  TargetPlatform.linux: HmiPageTransitionsBuilder(),
                },
              ),
            ),

            // Keep the initial route at "/". Flutter expands a named initial
            // route such as "/home" into both "/" and "/home"; that left the
            // hidden BootPage timer alive and it replaced Home with Warning
            // six seconds later during automated smoke tests/autostart.
            initialRoute: AppRoutes.boot,

            routes: {
              AppRoutes.boot: (context) => projectionAutostart
                  ? const ProjectionPage(
                      autoStartAndroidAuto: true,
                      initialTarget: ProjectionTarget.androidAuto,
                    )
                  : homeAutostart
                  ? const HomePage()
                  : const BootPage(),
              AppRoutes.warning: (context) => const WarningPage(),
              AppRoutes.oddEven: (context) => const OddEvenPage(),
              AppRoutes.driverSelect: (context) => const DriverSelectPage(),
              AppRoutes.addDriver: (context) => const AddDriverPage(),
              AppRoutes.personalize: (context) => const PersonalizePage(),
              AppRoutes.home: (context) => const HomePage(),
              AppRoutes.fragranceSettings: (context) =>
                  const SmartFragrancePage(),
              AppRoutes.projection: (context) => ProjectionPage(
                autoStartAndroidAuto: projectionAutostart,
                initialTarget: ProjectionTarget.androidAuto,
              ),
            },
          );
        },
      ),
    );
  }
}
