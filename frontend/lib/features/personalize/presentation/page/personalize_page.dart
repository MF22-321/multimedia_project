import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:frontend/core/navigation/driver_session.dart';
import 'package:frontend/core/services/drive_pref_service.dart';
import 'package:frontend/core/storage/driver_preference.dart';

import 'package:frontend/core/themes/car_theme.dart';
import 'package:frontend/core/themes/futuristic_particle_background.dart';
import 'package:frontend/core/themes/playful_background.dart';
import 'package:frontend/core/themes/retro_background.dart';

import 'package:frontend/features/auth/presentation/widget/profile_setting_panel.dart';

class PersonalizePage extends StatefulWidget {
  const PersonalizePage({super.key});

  @override
  State<PersonalizePage> createState() => _PersonalizePageState();
}

class _PersonalizePageState extends State<PersonalizePage> {
  int selectedCartridge = 2;
  int fanLevel = 3;
  int temperature = 19;
  int selectedTheme = 0;

  String? driverName;

  @override
  void initState() {
    super.initState();

    DriverSession.currentDriver.addListener(_onDriverChanged);

    _initDriver();
  }

  @override
  void dispose() {
    DriverSession.currentDriver.removeListener(_onDriverChanged);
    super.dispose();
  }

  void _onDriverChanged() {
    _initDriver();
  }

  /// ================= INIT DRIVER =================
  Future<void> _initDriver() async {
    final name = DriverSession.currentDriver.value;

    if (!mounted) return;

    setState(() {
      driverName = name;
    });

    if (name == null) return;

    final pref = await DriverPrefService.load(name.toLowerCase());

    if (pref != null && mounted) {
      setState(() {
        selectedCartridge = pref.cartridge;
        fanLevel = pref.fanLevel;
        temperature = pref.temperature;
        selectedTheme = pref.themeIndex;
      });

      /// 🔥 APPLY THEME (SAFE)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        CarThemes.currentTheme.value = CarThemeType.values[pref.themeIndex];
      });
    }
  }

  /// ================= SAVE =================
  Future<void> _savePreference() async {
    if (driverName == null) {
      debugPrint("❌ No driver");
      return;
    }

    final current = DriverSession.currentDriver.value;

    if (current == null) return;

    /// 🔥 LOAD DATA LAMA (SOURCE OF TRUTH)
    final existingPref = await DriverPrefService.load(current.toLowerCase());

    /// 🔥 AMBIL displayName ASLI
    final rawName = existingPref?.displayName ?? current;

    /// 🔑 KEY tetap lowercase
    final key = rawName.trim().toLowerCase();

    await DriverPrefService.save(
      DriverPreference(
        name: key,
        displayName: rawName, // ✅ TIDAK AKAN KE-LOWERCASE LAGI
        fanLevel: fanLevel,
        temperature: temperature,
        cartridge: selectedCartridge,
        themeIndex: selectedTheme,
      ),
    );

    /// 🔥 OPTIONAL (biar session selalu clean)
    DriverSession.setDriver(rawName);

    /// 🔥 APPLY THEME
    WidgetsBinding.instance.addPostFrameCallback((_) {
      CarThemes.currentTheme.value = CarThemeType.values[selectedTheme];
    });

    debugPrint("✅ Saved preference for $rawName");

    if (mounted) Navigator.pop(context);
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
                    const Positioned.fill(child: RetroParticlesBackground()),

                  if (themeType == CarThemeType.playful)
                    const Positioned.fill(child: PlayfulParticlesBackground()),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      /// BACK
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Row(
                          children: [
                            Icon(
                              Icons.arrow_back_ios,
                              color: Colors.white,
                              size: 20.sp,
                            ),
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

                      SizedBox(height: 15.h),

                      /// TITLE
                      Text(
                        "Profile",
                        style: TextStyle(
                          fontSize: 26.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),

                      ValueListenableBuilder(
                        valueListenable: CarThemes.currentTheme,
                        builder: (context, themeType, _) {
                          final theme = CarThemes.getTheme(themeType);

                          return Divider(
                            color: theme.accentColor,
                            thickness: 2.h,
                            height: 30.h,
                          );
                        },
                      ),

                      /// CONTENT
                      Expanded(
                        child: Center(
                          child: SizedBox(
                            width: 420.w,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Hello,",
                                  style: TextStyle(
                                    fontSize: 32.sp,
                                    color: Colors.white,
                                  ),
                                ),

                                /// 🔥 DRIVER NAME
                                ValueListenableBuilder<String?>(
                                  valueListenable: DriverSession.currentDriver,
                                  builder: (context, driver, _) {
                                    if (driver == null) {
                                      return Text(
                                        "Guest",
                                        style: TextStyle(
                                          fontSize: 70.sp,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      );
                                    }

                                    return FutureBuilder<DriverPreference?>(
                                      future: DriverPrefService.load(
                                        driver.toLowerCase(),
                                      ),
                                      builder: (context, snapshot) {
                                        final pref = snapshot.data;

                                        return Text(
                                          pref?.displayName ?? driver,
                                          style: TextStyle(
                                            fontSize: 70.sp,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        );
                                      },
                                    );
                                  },
                                ),

                                SizedBox(height: 20.h),

                                Row(
                                  children: [
                                    Text(
                                      "Personalize your settings",
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 18.sp,
                                      ),
                                    ),
                                    SizedBox(width: 10.w),
                                    Icon(
                                      Icons.arrow_forward,
                                      color: Colors.white70,
                                      size: 20.sp,
                                    ),
                                  ],
                                ),

                                SizedBox(height: 60.h),

                                /// SAVE BUTTON
                                GestureDetector(
                                  onTap: _savePreference,
                                  child: ValueListenableBuilder(
                                    valueListenable: CarThemes.currentTheme,
                                    builder: (context, themeType, _) {
                                      final theme = CarThemes.getTheme(
                                        themeType,
                                      );

                                      return AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 250,
                                        ),
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 40.w,
                                          vertical: 16.h,
                                        ),
                                        decoration: BoxDecoration(
                                          color: theme.buttonColor,
                                          borderRadius: BorderRadius.circular(
                                            30.r,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: theme.buttonColor
                                                  .withOpacity(0.4),
                                              blurRadius: 20,
                                            ),
                                          ],
                                        ),
                                        child: Text(
                                          "Save Settings",
                                          style: TextStyle(
                                            color:
                                                themeType ==
                                                        CarThemeType.comfort ||
                                                    themeType ==
                                                        CarThemeType.futuristic
                                                ? Colors.black
                                                : Colors.white,
                                            fontSize: 18.sp,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
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

                  onCartridgeChanged: (v) {
                    setState(() => selectedCartridge = v);
                  },

                  onFanPlus: () => setState(() => fanLevel++),
                  onFanMinus: () => setState(() => fanLevel--),

                  onTempPlus: () => setState(() => temperature++),
                  onTempMinus: () => setState(() => temperature--),

                  /// 🔥 THEME CHANGE (REALTIME)
                  onThemeChanged: (index) {
                    setState(() {
                      selectedTheme = index;
                    });

                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      CarThemes.currentTheme.value = CarThemeType.values[index];
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
