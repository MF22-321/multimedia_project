import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:frontend/core/provider/gps_provider.dart';
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
      MediaKit.ensureInitialized(); // ⬅️ WAJI
      
      
  await Hive.initFlutter();

  /// 🔥 buka box driver
  await Hive.openBox('drivers');

  /// Init window manager
  await windowManager.ensureInitialized();

  /// Lock orientation ke Landscape (Headunit Mode)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  /// Hilangkan status bar
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  /// Window options (Fullscreen Headunit)
  WindowOptions windowOptions = const WindowOptions(
    fullScreen: true,
    skipTaskbar: true,
    titleBarStyle: TitleBarStyle.hidden,
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();

    /// pindah ke monitor kedua
    await windowManager.setPosition(const Offset(1920, 0));

    /// resolusi monitor kedua
    await windowManager.setSize(const Size(2560, 1600));

    /// fullscreen
    await windowManager.setFullScreen(true);
  });

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {

    return MultiProvider(
      providers: [
        /// 🔥 VIDEO PROVIDER (AUTO INIT LAN)
        ChangeNotifierProvider(
          create: (_) => VideoProvider(),
        ),
        /// 🔥 GPS REALTIME
        ChangeNotifierProvider(
          create: (_) => GPSProvider(),
        ),

        /// 🔥 POTHOLE DATA
        ChangeNotifierProvider(
          create: (_) => PotholeProvider(),
        ),
      ],
      child: ScreenUtilInit(
        designSize: const Size(1280, 720),
        minTextAdapt: true,
        splitScreenMode: true,
        builder: (context, child) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: "Toyota Multimedia System",

            theme: ThemeData(
              brightness: Brightness.dark,
              scaffoldBackgroundColor: Colors.black,
              fontFamily: 'Roboto',
              useMaterial3: true,
            ),

            initialRoute: "/",

            routes: {
              "/": (context) => const BootPage(),
              "/warning": (context) => const WarningPage(),
              "/odd-even": (context) => const OddEvenPage(),
              "/driver-select": (context) => const DriverSelectPage(),
              "/add-driver": (context) => const AddDriverPage(),
              "/personalize": (context) => const PersonalizePage(),
              "/home": (context) => const HomePage(),
              '/fragrance_settings': (context) => const SmartFragrancePage(),
            },
          );
        },
      ),
    );
  }
}
