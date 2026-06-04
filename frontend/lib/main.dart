import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:frontend/core/navigation/app_routes.dart';
import 'package:frontend/core/provider/gps_provider.dart';
import 'package:frontend/core/provider/music_provider.dart';
import 'package:frontend/core/provider/pothole_provider.dart';
import 'package:frontend/features/personalize/presentation/page/personalize_page.dart';
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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  await Hive.initFlutter();
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

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

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
            ),

            initialRoute: AppRoutes.boot,

            routes: {
              AppRoutes.boot: (context) => const BootPage(),
              AppRoutes.warning: (context) => const WarningPage(),
              AppRoutes.oddEven: (context) => const OddEvenPage(),
              AppRoutes.driverSelect: (context) => const DriverSelectPage(),
              AppRoutes.addDriver: (context) => const AddDriverPage(),
              AppRoutes.personalize: (context) => const PersonalizePage(),
              AppRoutes.home: (context) => const HomePage(),
              AppRoutes.fragranceSettings: (context) =>
                  const SmartFragrancePage(),
            },
          );
        },
      ),
    );
  }
}
