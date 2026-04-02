import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:frontend/core/services/faceid_api.dart';
import 'package:frontend/core/themes/car_theme.dart';
import 'package:frontend/core/themes/futuristic_particle_background.dart';
import 'package:frontend/core/themes/playful_background.dart';
import 'package:frontend/core/themes/retro_background.dart';
import 'package:frontend/features/auth/presentation/widget/profile_setting_panel.dart';
import 'package:frontend/features/auth/presentation/widget/scan_face_button.dart';
import 'package:frontend/features/face_recognition/presentation/widgets/live_camera_webview.dart';

class AddDriverPage extends StatefulWidget {
  const AddDriverPage({super.key});

  @override
  State<AddDriverPage> createState() => _AddDriverPageState();
}

class _AddDriverPageState extends State<AddDriverPage> {
  final TextEditingController nameController = TextEditingController();

  bool isCapturing = false;
  bool isScanning = false; // 🔥 tambahan penting

  Timer? _timer;

  int captureSeconds = 8;
  String phaseText = "Fill name and scan";

  @override
  void dispose() {
    _timer?.cancel();
    nameController.dispose();
    super.dispose();
  }

  /// ================= ENROLL =================
  Future<void> handleEnroll() async {
    if (isCapturing) return; // 🔥 biar ga spam

    final name = nameController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Name is required")),
      );
      return;
    }

    setState(() {
      isCapturing = true;
      captureSeconds = 8;
      phaseText = "Capturing...";
    });

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        captureSeconds = (8 - timer.tick).clamp(0, 8);
      });

      if (timer.tick >= 8) timer.cancel();
    });

    try {
      final result = await FaceIdApi.enrollLiveBurst(
        driverName: name,
        durationSec: 8,
        targetSamples: 60,
      );

      if (!mounted) return;

      if (result["success"] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Driver registered successfully")),
        );
      }
    } catch (e) {
      debugPrint("Enroll error: $e");
    } finally {
      _timer?.cancel();

      if (!mounted) return;

      setState(() {
        isCapturing = false;
        isScanning = true; // 🔥 tetap camera mode
        phaseText = "Scanning...";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          /// ================= BACKGROUND =================
          ValueListenableBuilder(
            valueListenable: CarThemes.currentTheme,
            builder: (context, themeType, _) {
              final theme = CarThemes.getTheme(themeType);

              return Stack(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: theme.backgroundGradient,
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      image: theme.backgroundImage != null
                          ? DecorationImage(
                              image: FileImage(File(theme.backgroundImage!)),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                  ),

                  if (themeType == CarThemeType.futuristic)
                    const Positioned.fill(
                      child: FuturisticParticlesBackground(),
                    ),
                  if (themeType == CarThemeType.retro)
                    const Positioned.fill(
                      child: RetroParticlesBackground(),
                    ),
                  if (themeType == CarThemeType.playful)
                    const Positioned.fill(
                      child: PlayfulParticlesBackground(),
                    ),
                ],
              );
            },
          ),

          /// ================= CONTENT =================
          Row(
            children: [
              /// LEFT PANEL
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(40.w),
                  child: ValueListenableBuilder(
                    valueListenable: CarThemes.currentTheme,
                    builder: (context, themeType, _) {
                      final theme = CarThemes.getTheme(themeType);

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          /// BACK
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Row(
                              children: [
                                Icon(Icons.arrow_back_ios,
                                    color: Colors.white, size: 20.sp),
                                SizedBox(width: 8.w),
                                Text(
                                  "Back",
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 16.sp,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          SizedBox(height: 20.h),

                          /// TITLE
                          Text(
                            "Profile\nAdd New Driver",
                            style: TextStyle(
                              fontSize: 28.sp,
                              fontWeight: FontWeight.bold,
                              color: theme.textColor,
                            ),
                          ),

                          Divider(color: theme.accentColor, thickness: 2.h),

                          SizedBox(height: 60.h),

                          /// NAME
                          Text(
                            "Name",
                            style: TextStyle(
                              fontSize: 20.sp,
                              color: theme.textColor,
                            ),
                          ),

                          SizedBox(height: 20.h),

                          TextField(
                            controller: nameController,
                            onChanged: (_) => setState(() {}),
                            style: const TextStyle(color: Colors.black),
                            decoration: InputDecoration(
                              hintText: "Enter name",
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20.r),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),

                          SizedBox(height: 40.h),

                          /// ================= CAMERA =================
                          Center(
                            child: (isCapturing || isScanning)
                                ? Column(
                                    children: [
                                      SizedBox(
                                        width: 260,
                                        height: 260,
                                        child: Stack(
                                          children: [
                                            Positioned.fill(
                                              child: LiveCameraWS(
                                                url: FaceIdApi.cameraWs,
                                              ),
                                            ),

                                            /// TIMER
                                            if (isCapturing)
                                              Center(
                                                child: Text(
                                                  "$captureSeconds",
                                                  style: const TextStyle(
                                                    fontSize: 50,
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),

                                      SizedBox(height: 10.h),

                                      Text(
                                        phaseText,
                                        style: const TextStyle(
                                            color: Colors.white),
                                      ),
                                    ],
                                  )
                                : ScanFaceButton(
                                    driverName: nameController.text,
                                    onFaceStable: () {
                                      setState(() {
                                        isScanning = true;
                                      });

                                      handleEnroll();
                                    },
                                  ),
                          ),

                          const Spacer(),

                          /// SAVE BUTTON
                          GestureDetector(
                            onTap: () {
                              debugPrint(
                                  "Saved driver: ${nameController.text}");
                              Navigator.pop(context);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              padding: EdgeInsets.symmetric(
                                horizontal: 40.w,
                                vertical: 16.h,
                              ),
                              decoration: BoxDecoration(
                                color: theme.buttonColor,
                                borderRadius: BorderRadius.circular(30.r),
                              ),
                              child: const Text(
                                "Save Driver",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),

              /// RIGHT PANEL
              const Expanded(child: ProfileSettingsPanel()),
            ],
          ),
        ],
      ),
    );
  }
}