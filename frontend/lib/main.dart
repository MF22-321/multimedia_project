import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:frontend/features/auth/presentation/page/add_driver_page.dart';
import 'package:frontend/features/auth/presentation/page/driver_select_page.dart';
import 'package:frontend/features/home/presentation/page/home_page.dart';
import 'package:frontend/features/odd_even/presentation/pages/odd_event_page.dart';
import 'package:frontend/features/warning/presentation/pages/warning_page.dart';
import 'features/boot/presentation/pages/boot_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  /// Lock orientation ke Landscape (Headunit Mode)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  /// Full immersive mode (hilang status bar)
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(1280, 720), // Headunit standard
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: "Toyota Multimedia System",

          /// Theme global
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
            "/home": (context) => const HomePage(),
            
          },
        );
      },
    );
  }
}


