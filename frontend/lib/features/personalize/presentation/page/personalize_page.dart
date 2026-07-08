import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:frontend/core/localization/app_strings.dart';
import 'package:frontend/core/navigation/app_language_control.dart';
import 'package:frontend/core/navigation/app_routes.dart';
import 'package:frontend/core/navigation/driver_session.dart';
import 'package:frontend/core/services/drive_pref_service.dart';
import 'package:frontend/core/services/faceid_api.dart';
import 'package:frontend/core/model/driver_preference.dart';

import 'package:frontend/core/themes/car_theme.dart';
import 'package:frontend/core/themes/futuristic_particle_background.dart';
import 'package:frontend/core/themes/playful_background.dart';
import 'package:frontend/core/themes/retro_background.dart';

import 'package:frontend/features/auth/presentation/widget/profile_setting_panel.dart';
import 'package:frontend/features/face_recognition/presentation/widgets/live_camera_webview.dart';

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
  CarThemeData? _draftCustomTheme;

  String? driverName;

  @override
  void initState() {
    super.initState();

    DriverSession.currentDriver.addListener(_onDriverChanged);
    AppLanguageControl.languageCode.addListener(_onLanguageChanged);

    _initDriver();
  }

  @override
  void dispose() {
    DriverSession.currentDriver.removeListener(_onDriverChanged);
    AppLanguageControl.languageCode.removeListener(_onLanguageChanged);
    super.dispose();
  }

  void _onDriverChanged() {
    _initDriver();
  }

  void _onLanguageChanged() {
    if (mounted) setState(() {});
  }

  /// ================= INIT DRIVER =================
  Future<void> _initDriver() async {
    final name = DriverSession.currentDriver.value;

    if (!mounted) return;

    setState(() {
      driverName = name;
    });

    if (name == null) {
      setState(() {
        selectedTheme = CarThemes.currentTheme.value.index;
        _draftCustomTheme =
            CarThemes.currentTheme.value == CarThemeType.custom
            ? CarThemes.customTheme.value
            : null;
      });
      return;
    }

    final currentDriver = name; // 🔥 SIMPAN DULU

    final pref = DriverHiveService.load(name.toLowerCase());

    /// 🔥 CEK LAGI (ANTI RACE CONDITION)
    if (DriverSession.currentDriver.value != currentDriver) {
      return;
    }

    if (pref != null && mounted) {
      setState(() {
        selectedCartridge = pref.cartridge;
        fanLevel = pref.fanLevel;
        temperature = pref.temperature;
        selectedTheme = pref.themeIndex;
        _draftCustomTheme = pref.customThemeData;
      });

      AppLanguageControl.loadForCurrentDriver();

      WidgetsBinding.instance.addPostFrameCallback((_) {
        final customTheme = pref.customThemeData;
        if (customTheme != null) {
          CarThemes.customTheme.value = customTheme;
        }
        CarThemes.currentTheme.value = CarThemeType.values[pref.themeIndex];
      });
    }
  }

  /// ================= SAVE =================
  Future<void> _savePreference() async {
    final current = DriverSession.currentDriver.value;
    final customTheme = _draftCustomTheme ?? CarThemes.customTheme.value;

    if (current == null) {
      if (selectedTheme == CarThemeType.custom.index) {
        CarThemes.customTheme.value = customTheme;
      }
      CarThemes.currentTheme.value = CarThemeType.values[selectedTheme];

      debugPrint("✅ Applied guest preference for current session");

      if (mounted) Navigator.pop(context);
      return;
    }

    final rawName = current;
    final key = rawName.trim().toLowerCase();
    final existingPreference = DriverHiveService.load(key);

    await DriverHiveService.save(
      DriverPreference(
        name: key,
        displayName: rawName, // ✅ TIDAK AKAN KE-LOWERCASE LAGI
        fanLevel: fanLevel,
        temperature: temperature,
        cartridge: selectedCartridge,
        themeIndex: selectedTheme,
        languageCode:
            existingPreference?.languageCode ??
            AppLanguageControl.languageCode.value,
        customGradient1: customTheme.backgroundGradient.first.toARGB32(),
        customGradient2: customTheme.backgroundGradient.last.toARGB32(),
        customAccentColor: customTheme.accentColor.toARGB32(),
        customTextColor: customTheme.textColor.toARGB32(),
        customBackgroundImage: customTheme.backgroundImage,
      ),
    );

    /// 🔥 OPTIONAL (biar session selalu clean)
    DriverSession.setDriver(rawName);

    /// 🔥 APPLY THEME
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (selectedTheme == CarThemeType.custom.index) {
        CarThemes.customTheme.value = customTheme;
      }
      CarThemes.currentTheme.value = CarThemeType.values[selectedTheme];
    });

    debugPrint("✅ Saved preference for $rawName");

    if (mounted) Navigator.pop(context);
  }

  Future<void> _openDeleteAccountFlow() async {
    final activeDriver = DriverSession.currentDriver.value;
    if (activeDriver == null || activeDriver.trim().isEmpty) return;

    final verified = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DeleteDriverFaceDialog(driverName: activeDriver),
    );

    if (verified != true || !mounted) return;

    try {
      final result = await FaceIdApi.deleteDriver(activeDriver);
      final deletedDriver =
          result["driver_name"]?.toString().trim().isNotEmpty == true
          ? result["driver_name"].toString()
          : activeDriver;
      await DriverHiveService.delete(activeDriver);
      if (deletedDriver.trim().toLowerCase() !=
          activeDriver.trim().toLowerCase()) {
        await DriverHiveService.delete(deletedDriver);
      }
      DriverSession.clear();

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppStrings.accountDeleted)));

      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.driverSelect,
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.deleteAccountFailed(e))),
      );
    }
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
    final saveButtonTextColor =
        ThemeData.estimateBrightnessForColor(saveButtonColor) ==
            Brightness.dark
        ? Colors.white
        : Colors.black;

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
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
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
                                  AppStrings.back,
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
                      ),

                      SizedBox(height: 15.h),

                      /// TITLE
                      Text(
                        AppStrings.profile,
                        style: TextStyle(
                          fontSize: 26.sp,
                          fontWeight: FontWeight.bold,
                          color: previewTheme.textColor,
                        ),
                      ),

                      Divider(
                        color: previewAccent,
                        thickness: 2.h,
                        height: 30.h,
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
                                  '${AppStrings.hello},',
                                  style: TextStyle(
                                    fontSize: 32.sp,
                                    color: previewTheme.textColor,
                                  ),
                                ),

                                /// 🔥 DRIVER NAME
                                ValueListenableBuilder<String?>(
                                  valueListenable: DriverSession.currentDriver,
                                  builder: (context, driver, _) {
                                    if (driver == null) {
                                      return Text(
                                        AppStrings.guest,
                                        style: TextStyle(
                                          fontSize: 70.sp,
                                          fontWeight: FontWeight.bold,
                                          color: previewTheme.textColor,
                                        ),
                                      );
                                    }

                                    final pref = DriverHiveService.load(
                                      driver.toLowerCase(),
                                    );

                                    return Text(
                                      pref?.displayName ?? driver,
                                      style: TextStyle(
                                        fontSize: 70.sp,
                                        fontWeight: FontWeight.bold,
                                        color: previewTheme.textColor,
                                      ),
                                    );
                                  },
                                ),

                                SizedBox(height: 20.h),

                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          AppStrings.personalizeSettings,
                                          style: TextStyle(
                                            color: previewTheme.textColor
                                                .withValues(alpha: 0.74),
                                            fontSize: 18.sp,
                                          ),
                                        ),
                                        SizedBox(width: 10.w),
                                        Icon(
                                          Icons.arrow_forward,
                                          color: previewTheme.textColor
                                              .withValues(alpha: 0.74),
                                          size: 20.sp,
                                        ),
                                      ],
                                    ),

                                    SizedBox(height: 24.h),

                                    ValueListenableBuilder(
                                      valueListenable:
                                          AppLanguageControl.languageCode,
                                      builder: (context, languageCode, _) {
                                        return Container(
                                          padding: EdgeInsets.all(20.w),
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(24.r),
                                            color: Colors.white.withValues(
                                              alpha: 0.06,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      AppStrings.language,
                                                      style: TextStyle(
                                                        color: previewTheme
                                                            .textColor,
                                                        fontSize: 18.sp,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                    SizedBox(height: 6.h),
                                                    Text(
                                                      AppStrings.chooseLanguage,
                                                      style: TextStyle(
                                                        color: previewTheme
                                                            .textColor
                                                            .withValues(
                                                              alpha: 0.74,
                                                            ),
                                                        fontSize: 14.sp,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Container(
                                                padding: EdgeInsets.all(6.w),
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                    20.r,
                                                  ),
                                                  color: Colors.white.withValues(
                                                    alpha: 0.06,
                                                  ),
                                                ),
                                                child: Row(
                                                  children: [
                                                    GestureDetector(
                                                      onTap: () {
                                                        AppLanguageControl
                                                            .setLanguageForCurrentDriver(
                                                          AppLanguageControl
                                                              .defaultLanguageCode,
                                                        );
                                                      },
                                                      child: Container(
                                                        padding: EdgeInsets
                                                            .symmetric(
                                                          horizontal: 16.w,
                                                          vertical: 10.h,
                                                        ),
                                                        decoration: BoxDecoration(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                            16.r,
                                                          ),
                                                          color: languageCode ==
                                                                  AppLanguageControl
                                                                      .defaultLanguageCode
                                                              ? Colors.white
                                                                  .withValues(
                                                                    alpha: 0.14,
                                                                  )
                                                              : Colors.transparent,
                                                        ),
                                                        child: Text(
                                                          'Bahasa',
                                                          style: TextStyle(
                                                            color: previewTheme
                                                                .textColor,
                                                            fontWeight:
                                                                languageCode ==
                                                                        AppLanguageControl
                                                                            .defaultLanguageCode
                                                                    ? FontWeight.bold
                                                                    : FontWeight.w500,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    SizedBox(width: 10.w),
                                                    GestureDetector(
                                                      onTap: () {
                                                        AppLanguageControl
                                                            .setLanguageForCurrentDriver(
                                                          AppLanguageControl
                                                              .englishCode,
                                                        );
                                                      },
                                                      child: Container(
                                                        padding: EdgeInsets
                                                            .symmetric(
                                                          horizontal: 16.w,
                                                          vertical: 10.h,
                                                        ),
                                                        decoration: BoxDecoration(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                            16.r,
                                                          ),
                                                          color: languageCode ==
                                                                  AppLanguageControl
                                                                      .englishCode
                                                              ? Colors.white
                                                                  .withValues(
                                                                    alpha: 0.14,
                                                                  )
                                                              : Colors.transparent,
                                                        ),
                                                        child: Text(
                                                          'English',
                                                          style: TextStyle(
                                                            color: previewTheme
                                                                .textColor,
                                                            fontWeight:
                                                                languageCode ==
                                                                        AppLanguageControl
                                                                            .englishCode
                                                                    ? FontWeight.bold
                                                                    : FontWeight.w500,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),

                                    SizedBox(height: 60.h),
                                  ],
                                ),

                                ValueListenableBuilder<String?>(
                                  valueListenable: DriverSession.currentDriver,
                                  builder: (context, activeDriver, _) {
                                    return Wrap(
                                      spacing: 14.w,
                                      runSpacing: 12.h,
                                      children: [
                                        GestureDetector(
                                          onTap: _savePreference,
                                          child: AnimatedContainer(
                                            duration: const Duration(
                                              milliseconds: 250,
                                            ),
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 40.w,
                                              vertical: 16.h,
                                            ),
                                            decoration: BoxDecoration(
                                              color: saveButtonColor,
                                              borderRadius:
                                                  BorderRadius.circular(30.r),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: saveButtonColor
                                                      .withValues(alpha: 0.4),
                                                  blurRadius: 20,
                                                ),
                                              ],
                                            ),
                                            child: Text(
                                              AppStrings.saveSettings,
                                              style: TextStyle(
                                                color: saveButtonTextColor,
                                                fontSize: 18.sp,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                        if (activeDriver != null)
                                          GestureDetector(
                                            onTap: _openDeleteAccountFlow,
                                            child: AnimatedContainer(
                                              duration: const Duration(
                                                milliseconds: 250,
                                              ),
                                              padding: EdgeInsets.symmetric(
                                                horizontal: 28.w,
                                                vertical: 16.h,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.redAccent
                                                    .withValues(alpha: 0.18),
                                                borderRadius:
                                                    BorderRadius.circular(30.r),
                                                border: Border.all(
                                                  color: Colors.redAccent
                                                      .withValues(alpha: 0.72),
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.delete_outline,
                                                    color: Colors.redAccent,
                                                    size: 20.sp,
                                                  ),
                                                  SizedBox(width: 8.w),
                                                  Text(
                                                    AppStrings.deleteAccount,
                                                    style: TextStyle(
                                                      color: Colors.redAccent,
                                                      fontSize: 18.sp,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                      ],
                                    );
                                  },
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

class _DeleteDriverFaceDialog extends StatefulWidget {
  const _DeleteDriverFaceDialog({required this.driverName});

  final String driverName;

  @override
  State<_DeleteDriverFaceDialog> createState() =>
      _DeleteDriverFaceDialogState();
}

class _DeleteDriverFaceDialogState extends State<_DeleteDriverFaceDialog> {
  Timer? _timer;
  bool _verified = false;
  bool _deleting = false;
  String? _recognizedDriver;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  bool _sameDriver(String? recognized) {
    return recognized != null &&
        recognized.trim().toLowerCase() ==
            widget.driverName.trim().toLowerCase();
  }

  void _startPolling() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) async {
      try {
        final status = await FaceIdApi.getDriverStatus();
        final recognized = status["recognized"] == true;
        final name = status["driver"]?.toString();

        if (!mounted) return;

        setState(() {
          _recognizedDriver = name;
          _verified = recognized && _sameDriver(name);
          _error = null;
        });
      } catch (e) {
        if (!mounted) return;
        setState(() => _error = e);
      }
    });
  }

  void _confirmDelete() {
    if (!_verified || _deleting) return;

    setState(() => _deleting = true);
    _timer?.cancel();
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final statusText = _deleting
        ? AppStrings.deletingAccount
        : _verified
        ? AppStrings.faceVerified
        : AppStrings.verifyingFace;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: 170.w, vertical: 60.h),
      child: Container(
        padding: EdgeInsets.all(22.w),
        decoration: BoxDecoration(
          color: const Color(0xFF101010),
          borderRadius: BorderRadius.circular(24.r),
          border: Border.all(
            color: _verified ? Colors.greenAccent : Colors.redAccent,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 30,
            ),
          ],
        ),
        child: Row(
          children: [
            LiveCameraWS(
              url: FaceIdApi.cameraWs,
              width: 330.w,
              height: 330.h,
            ),
            SizedBox(width: 28.w),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.deleteDriverAccount,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 10.h),
                  Text(
                    AppStrings.deleteDriverPrompt(widget.driverName),
                    style: TextStyle(color: Colors.white70, fontSize: 15.sp),
                  ),
                  SizedBox(height: 22.h),
                  Container(
                    padding: EdgeInsets.all(14.w),
                    decoration: BoxDecoration(
                      color: (_verified ? Colors.greenAccent : Colors.white)
                          .withValues(alpha: _verified ? 0.13 : 0.07),
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _verified
                              ? Icons.verified_user
                              : Icons.face_retouching_natural,
                          color: _verified
                              ? Colors.greenAccent
                              : Colors.orangeAccent,
                          size: 24.sp,
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                statusText,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 4.h),
                              Text(
                                _recognizedDriver == null
                                    ? AppStrings.faceNotMatched
                                    : 'Detected: $_recognizedDriver',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12.sp,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_error != null) ...[
                    SizedBox(height: 12.h),
                    Text(
                      _error.toString(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontSize: 11.sp,
                      ),
                    ),
                  ],
                  SizedBox(height: 28.h),
                  Row(
                    children: [
                      TextButton(
                        onPressed: _deleting
                            ? null
                            : () => Navigator.of(context).pop(false),
                        child: Text(AppStrings.cancel),
                      ),
                      SizedBox(width: 14.w),
                      FilledButton.icon(
                        onPressed: _verified && !_deleting
                            ? _confirmDelete
                            : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor:
                              Colors.white.withValues(alpha: 0.12),
                          disabledForegroundColor: Colors.white38,
                        ),
                        icon: const Icon(Icons.delete_outline),
                        label: Text(AppStrings.deleteNow),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
