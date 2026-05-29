import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:frontend/core/model/driver_preference.dart';
import 'package:frontend/core/navigation/app_language_control.dart';
import 'package:frontend/core/navigation/driver_session.dart';
import 'package:frontend/core/services/drive_pref_service.dart';
import 'package:frontend/core/services/faceid_api.dart';
import 'package:frontend/core/themes/car_theme.dart';
import 'package:frontend/core/themes/futuristic_particle_background.dart';
import 'package:frontend/core/themes/playful_background.dart';
import 'package:frontend/core/themes/retro_background.dart';
import 'package:frontend/core/widgets/in_app_keyboard.dart';
import 'package:frontend/features/auth/presentation/widget/profile_setting_panel.dart';
import 'package:frontend/features/auth/presentation/widget/scan_face_button.dart';
import 'package:frontend/features/face_recognition/presentation/widgets/live_camera_webview.dart';
import 'package:frontend/features/home/presentation/page/home_page.dart';

class AddDriverPage extends StatefulWidget {
  const AddDriverPage({super.key});

  @override
  State<AddDriverPage> createState() => _AddDriverPageState();
}

class _AddDriverPageState extends State<AddDriverPage> {
  final TextEditingController nameController = TextEditingController();

  bool isCapturing = false;
  bool isScanning = false; // 🔥 tambahan penting
  String? detectedDriverName;

  Timer? _timer;
  Timer? _recognitionTimer;
  double? confidence;

  int captureSeconds = 8;
  String phaseText = "Fill name and scan";

  int fanLevel = 3;
  int temperature = 19;
  int selectedCartridge = 1;
  int selectedTheme = 0;
  CarThemeData? _draftCustomTheme;
  bool _prefLoaded = false;

  @override
  void dispose() {
    _timer?.cancel();
    nameController.dispose();
    _recognitionTimer?.cancel(); // 🔥 tambah ini
    detectedDriverName = null; // 🔥 reset
    super.dispose();
  }

  /// ================= ENROLL =================
  Future<void> handleEnroll() async {
    setState(() {
      detectedDriverName = null;
      confidence = null;
      _prefLoaded = false;
    });

    if (isCapturing) return; // 🔥 biar ga spam

    final name = nameController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Name is required")));
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

      if (mounted) {
        setState(() {
          isCapturing = false;
          isScanning = true; // 🔥 tetap camera mode
          phaseText = "Scanning...";
        });
        _startRecognitionPolling(); // ✅ aman
      }
    }
  }

  void _startRecognitionPolling() {
    _recognitionTimer?.cancel();

    _recognitionTimer = Timer.periodic(const Duration(milliseconds: 400), (
      _,
    ) async {
      try {
        final result = await FaceIdApi.getDriverStatus();

        final recognized = result["recognized"] == true;
        final name = result["driver"];
        final conf = result["confidence"];

        if (recognized && name != null) {
          final previousDriverName = detectedDriverName;

          /// 🔥 1. TAMPILKAN NAMA REALTIME
          setState(() {
            detectedDriverName = name.toString();
            if (conf is num) {
              confidence = conf.toDouble();
            }
            if (previousDriverName != detectedDriverName) {
              _prefLoaded = false;
            }
          });

          /// 🔥 2. LOAD PREFERENCE (JIKA ADA)
          final pref = DriverHiveService.load(name.toLowerCase());

          if (pref != null && !_prefLoaded) {
            setState(() {
              fanLevel = pref.fanLevel;
              temperature = pref.temperature;
              selectedCartridge = pref.cartridge;
              selectedTheme = pref.themeIndex;
              _draftCustomTheme = pref.customThemeData;
            });

            _prefLoaded = true;
          }
        } else {
          /// 🔥 RESET kalau tidak ada face
          setState(() {
            detectedDriverName = null;
            confidence = null;
          });
        }
      } catch (e) {
        debugPrint("Recognition error: $e");
      }
    });
  }

  Future<void> _saveDriver() async {
    if (detectedDriverName == null) return;

    final current = detectedDriverName!;
    final rawName = current; // 🔥 langsung pakai hasil face
    final key = rawName.trim().toLowerCase();
    final existingPreference = DriverHiveService.load(key);
    final customTheme = _draftCustomTheme ?? CarThemes.customTheme.value;

    await DriverHiveService.save(
      DriverPreference(
        name: key,
        displayName: rawName,
        fanLevel: fanLevel,
        temperature: temperature,
        cartridge: selectedCartridge,
        themeIndex: selectedTheme,
        languageCode:
            existingPreference?.languageCode ??
            AppLanguageControl.defaultLanguageCode,
        customGradient1: customTheme.backgroundGradient.first.toARGB32(),
        customGradient2: customTheme.backgroundGradient.last.toARGB32(),
        customAccentColor: customTheme.accentColor.toARGB32(),
        customTextColor: customTheme.textColor.toARGB32(),
        customBackgroundImage: customTheme.backgroundImage,
      ),
    );

    if (!mounted) return;

    DriverSession.setDriver(rawName);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (selectedTheme == CarThemeType.custom.index) {
        CarThemes.customTheme.value = customTheme;
      }
      CarThemes.currentTheme.value = CarThemeType.values[selectedTheme];
    });

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const HomePage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final previewThemeType = CarThemeType.values[selectedTheme];
    final previewTheme =
        previewThemeType == CarThemeType.custom && _draftCustomTheme != null
        ? _draftCustomTheme!
        : CarThemes.getTheme(previewThemeType);
    final previewAccent = getMusicAccentColor(previewThemeType, previewTheme);
    final saveButtonColor = previewThemeType == CarThemeType.comfort
        ? previewAccent
        : previewTheme.buttonColor;

    return Scaffold(
      body: Stack(
        children: [
          /// ================= BACKGROUND =================
          Stack(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: previewTheme.backgroundGradient,
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  image: previewTheme.backgroundImage != null
                      ? DecorationImage(
                          image: FileImage(File(previewTheme.backgroundImage!)),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
              ),

              if (previewThemeType == CarThemeType.futuristic)
                const Positioned.fill(child: FuturisticParticlesBackground()),
              if (previewThemeType == CarThemeType.retro)
                const Positioned.fill(child: RetroParticlesBackground()),
              if (previewThemeType == CarThemeType.playful)
                const Positioned.fill(child: PlayfulParticlesBackground()),
            ],
          ),

          /// ================= CONTENT =================
          Row(
            children: [
              /// LEFT PANEL
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(40.w),
                  child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          /// BACK
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => Navigator.pop(context),
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 4.w,
                                vertical: 8.h,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.arrow_back_ios,
                                    color: previewTheme.textColor,
                                    size: 20.sp,
                                  ),
                                  SizedBox(width: 8.w),
                                  Text(
                                    "Back",
                                    style: TextStyle(
                                      color: previewTheme.textColor.withValues(
                                        alpha: 0.74,
                                      ),
                                      fontSize: 16.sp,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          SizedBox(height: 20.h),

                          /// TITLE
                          Text(
                            "Profile\nAdd New Driver",
                            style: TextStyle(
                              fontSize: 28.sp,
                              fontWeight: FontWeight.bold,
                              color: previewTheme.textColor,
                            ),
                          ),

                          Divider(color: previewAccent, thickness: 2.h),

                          SizedBox(height: 30.h),

                          /// NAME
                          Text(
                            "Name",
                            style: TextStyle(
                              fontSize: 20.sp,
                              color: previewTheme.textColor,
                            ),
                          ),

                          SizedBox(height: 20.h),

                          TextField(
                            controller: nameController,
                            readOnly: true,
                            showCursor: true,
                            onTap: () {
                              showInAppKeyboard(
                                context: context,
                                controller: nameController,
                                title: "Enter driver name",
                                accentColor: previewAccent,
                                onChanged: (_) => setState(() {}),
                              );
                            },
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
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 30, // 🔥 tinggi box
                                horizontal: 20,
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
                                        width:
                                            400.w, // 🔥 lebih besar & konsisten
                                        height:
                                            300.h, // 🔥 konsisten & lebih besar
                                        child: Stack(
                                          children: [
                                            /// 🎥 CAMERA
                                            Positioned.fill(
                                              child: LiveCameraWS(
                                                url: FaceIdApi.cameraWs,
                                              ),
                                            ),

                                            /// 🔥 DRIVER NAME (NEW)
                                            if (detectedDriverName != null)
                                              Positioned(
                                                bottom: 80,
                                                left: 0,
                                                right: 0,
                                                child: Center(
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 16,
                                                          vertical: 8,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.green
                                                          .withValues(
                                                            alpha: 0.9,
                                                          ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            12,
                                                          ),
                                                    ),
                                                    child: Text(
                                                      detectedDriverName!,
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),

                                            if (confidence != null)
                                              Positioned(
                                                bottom: 30,
                                                left: 0,
                                                right: 0,
                                                child: Center(
                                                  child: Text(
                                                    "Confidence: ${confidence!.toStringAsFixed(2)}",
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                                ),
                                              ),

                                            /// 🔥 STATUS REGISTERED (NEW)
                                            if (!isCapturing &&
                                                detectedDriverName != null)
                                              Positioned(
                                                bottom: 50,
                                                left: 0,
                                                right: 0,
                                                child: Center(
                                                  child: Text(
                                                    "Registered ✅",
                                                    style: TextStyle(
                                                      color: Colors.greenAccent,
                                                      fontSize: 12.sp,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ),

                                            /// ⏱ TIMER (tetap ada)
                                            if (isCapturing)
                                              Center(
                                                child: Text(
                                                  "$captureSeconds",
                                                  style: const TextStyle(
                                                    fontSize: 60,
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
                                          color: Colors.white,
                                        ),
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
                            onTap: _saveDriver,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              padding: EdgeInsets.symmetric(
                                horizontal: 40.w,
                                vertical: 16.h,
                              ),
                              decoration: BoxDecoration(
                                color: saveButtonColor,
                                borderRadius: BorderRadius.circular(30.r),
                              ),
                              child: Text(
                                "Save Driver",
                                style: TextStyle(
                                  color:
                                      ThemeData.estimateBrightnessForColor(
                                                saveButtonColor,
                                              ) ==
                                              Brightness.dark
                                          ? Colors.white
                                          : Colors.black,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                  ),
                ),
              ),

              /// RIGHT PANEL
              Expanded(
                child: ProfileSettingsPanel(
                  selectedCartridge: selectedCartridge,
                  fanLevel: fanLevel,
                  temperature: temperature,
                  selectedTheme: selectedTheme,
                  previewThemeType: previewThemeType,
                  previewTheme: previewTheme,
                  customThemeData: _draftCustomTheme,
                  onCustomThemeSaved: (theme) {
                    setState(() {
                      _draftCustomTheme = theme;
                      selectedTheme = CarThemeType.custom.index;
                    });
                  },

                  onCartridgeChanged: (v) {
                    setState(() => selectedCartridge = v);
                  },

                  onFanPlus: () => setState(() => fanLevel++),
                  onFanMinus: () => setState(() => fanLevel--),

                  onTempPlus: () => setState(() => temperature++),
                  onTempMinus: () => setState(() => temperature--),

                  onThemeChanged: (index) {
                    setState(() {
                      selectedTheme = index;
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
