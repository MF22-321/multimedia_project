import 'package:flutter/material.dart';
import 'features/faceid/presentation/pages/add_driver_page.dart';
import 'features/faceid/presentation/pages/face_scan_page.dart';
import 'features/drowsiness/presentation/pages/home_page.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Face Drowsiness',
      debugShowCheckedModeBanner: false,
      initialRoute: FaceScanPage.routeName,
      routes: {
        FaceScanPage.routeName: (_) => const FaceScanPage(),
        AddDriverPage.routeName: (_) => const AddDriverPage(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == HomePage.routeName) {
          final args = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (_) => HomePage(
              driverName: args["driver_name"] as String,
            ),
          );
        }
        return null;
      },
    );
  }
}