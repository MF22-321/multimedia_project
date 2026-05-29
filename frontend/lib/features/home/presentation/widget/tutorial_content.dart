import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:frontend/core/constant/video_assets.dart';
import 'package:frontend/core/localization/app_strings.dart';
import 'package:frontend/core/navigation/app_language_control.dart';
import 'package:frontend/core/navigation/driver_session.dart';
import 'package:frontend/core/services/drive_pref_service.dart';
import 'package:frontend/core/services/overlay_service.dart';
import 'package:frontend/core/themes/car_theme.dart';

class TutorialPage extends StatefulWidget {
  const TutorialPage({super.key});

  @override
  State<TutorialPage> createState() => _TutorialPageState();
}

class _TutorialPageState extends State<TutorialPage> {
  late Timer timer;

  DateTime now = DateTime.now();

  List<_TutorialItem> get tutorials => [
    _TutorialItem(
      title: AppStrings.openHood,
      description: AppStrings.choose(
        id: 'Panduan membuka kap mesin Veloz dengan aman.',
        en: 'Guide to safely open the Veloz engine hood.',
      ),
      image: 'https://images.unsplash.com/photo-1503376780353-7e6692767b70',
      action: _localizedOpenHoodAction,
    ),
    _TutorialItem(
      title: AppStrings.openFuelCap,
      description: AppStrings.choose(
        id: 'Panduan membuka dan menutup tutup tangki kendaraan.',
        en: 'Guide to open and close the vehicle fuel cap.',
      ),
      image: 'https://images.unsplash.com/photo-1492144534655-ae79c964c9d7',
      action: _localizedOpenFuelCapAction,
    ),
    _TutorialItem(
      title: AppStrings.choose(
        id: 'Cek Level Oli',
        en: 'Check Oil Level',
      ),
      description: AppStrings.choose(
        id: 'Langkah mengecek level oli mesin sebelum berkendara.',
        en: 'Steps to check engine oil level before driving.',
      ),
      image: 'https://images.unsplash.com/photo-1487754180451-c456f719a1fc',
      action: VehicleAction.checkOilLevel,
    ),
    _TutorialItem(
      title: AppStrings.choose(
        id: 'Mengganti Ban',
        en: 'Change Tire',
      ),
      description: AppStrings.choose(
        id: 'Panduan mengganti ban saat kondisi darurat.',
        en: 'Guide to change a tire during an emergency.',
      ),
      image: 'https://images.unsplash.com/photo-1600705722908-bab93dd6deab',
      action: VehicleAction.changeTire,
    ),
    _TutorialItem(
      title: AppStrings.choose(
        id: 'Menggunakan APAR',
        en: 'Use Fire Extinguisher',
      ),
      description: AppStrings.choose(
        id: 'Cara menggunakan APAR untuk penanganan awal kebakaran.',
        en: 'How to use a fire extinguisher for first response.',
      ),
      image: 'https://images.unsplash.com/photo-1578328819058-b69f3a3b0f6b',
      action: VehicleAction.useFireExtinguisher,
    ),
    _TutorialItem(
      title: AppStrings.choose(
        id: 'Menolong Kecelakaan',
        en: 'Help Accident',
      ),
      description: AppStrings.choose(
        id: 'Langkah aman membantu kondisi kecelakaan di jalan.',
        en: 'Safe steps to help during a road accident.',
      ),
      image: 'https://images.unsplash.com/photo-1502744688674-c619d1586c9e',
      action: VehicleAction.helpAccident,
    ),
  ];

  VehicleAction get _localizedOpenHoodAction {
    return AppLanguageControl.isEnglish
        ? VehicleAction.openHoodEng
        : VehicleAction.openHoodInd;
  }

  VehicleAction get _localizedOpenFuelCapAction {
    return AppLanguageControl.isEnglish
        ? VehicleAction.openTrunkEng
        : VehicleAction.openTrunkInd;
  }

  @override
  void initState() {
    super.initState();
    AppLanguageControl.languageCode.addListener(_refreshLanguageText);

    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        now = DateTime.now();
      });
    });
  }

  @override
  void dispose() {
    timer.cancel();
    AppLanguageControl.languageCode.removeListener(_refreshLanguageText);

    super.dispose();
  }

  void _refreshLanguageText() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final currentTheme = CarThemes.currentTheme.value;

    final theme = CarThemes.getTheme(currentTheme);

    final accentColor = currentTheme == CarThemeType.comfort
        ? const Color(0xFF6CB4FF)
        : theme.accentColor;

    return Scaffold(
      backgroundColor: Colors.black,

      body: Container(
        width: double.infinity,
        height: double.infinity,

        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,

            end: Alignment.bottomRight,

            colors: theme.backgroundGradient,
          ),
        ),

        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(24.w),

            child: Row(
              children: [
                /// =========================
                /// CONTENT
                /// =========================
                Expanded(
                  child: Container(
                    padding: EdgeInsets.all(28.w),

                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(40.r),

                      color: Colors.white.withValues(alpha: 0.05),

                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),

                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [
                        /// =========================
                        /// TOP BAR
                        /// =========================
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,

                          children: [
                            /// USER
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 18.w,

                                vertical: 14.h,
                              ),

                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(22.r),

                                color: Colors.white.withValues(alpha: 0.06),
                              ),

                              child: Row(
                                children: [
                                  ValueListenableBuilder<String?>(
                                    valueListenable:
                                        DriverSession.currentDriver,
                                    builder: (context, driver, _) {
                                      final displayName = _displayDriverName(
                                        driver,
                                      );

                                      return Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          CircleAvatar(
                                            radius: 20.r,
                                            backgroundColor: accentColor,
                                            child: Text(
                                              displayName
                                                  .substring(0, 1)
                                                  .toUpperCase(),
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 16.sp,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),

                                          SizedBox(width: 12.w),

                                          ConstrainedBox(
                                            constraints: BoxConstraints(
                                              maxWidth: 240.w,
                                            ),
                                            child: Text(
                                              '${AppStrings.hello}, $displayName',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 18.sp,
                                                fontWeight: FontWeight.w600,
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

                            /// TIME
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,

                              children: [
                                Text(
                                  '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',

                                  style: TextStyle(
                                    color: Colors.white,

                                    fontSize: 26.sp,

                                    fontWeight: FontWeight.bold,
                                  ),
                                ),

                                SizedBox(height: 4.h),

                                Text(
                                  '${now.day}/${now.month}/${now.year}',

                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.6),

                                    fontSize: 14.sp,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),

                        SizedBox(height: 34.h),

                        /// =========================
                        /// HEADER
                        /// =========================
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () {
                                Navigator.pop(context);
                              },

                              child: Container(
                                width: 60.w,
                                height: 60.w,

                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,

                                  color: Colors.white.withValues(alpha: 0.08),
                                ),

                                child: Icon(
                                  Icons.arrow_back_ios_new,

                                  color: accentColor,

                                  size: 24.sp,
                                ),
                              ),
                            ),

                            SizedBox(width: 20.w),

                            Text(
                              AppStrings.videoTutorial,

                              style: TextStyle(
                                color: Colors.white,

                                fontSize: 15.sp,
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: 36.h),

                        /// =========================
                        /// VIDEO GRID
                        /// =========================
                        Expanded(
                          child: GridView.builder(
                            physics: const BouncingScrollPhysics(),

                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,

                                  crossAxisSpacing: 24.w,

                                  mainAxisSpacing: 24.h,

                                  childAspectRatio: 2.2,
                                ),

                            itemCount: tutorials.length,

                            itemBuilder: (context, index) {
                              final item = tutorials[index];

                              return GestureDetector(
                                onTap: () {
                                  final videoAsset =
                                      VideoAssets.actionVideoMap[item.action];

                                  if (videoAsset == null) return;

                                  VideoOverlayService().show(
                                    context: context,
                                    videoAsset: videoAsset,
                                  );
                                },

                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 250),

                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(30.r),

                                    color: Colors.white.withValues(alpha: 0.05),

                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.08,
                                      ),
                                    ),

                                    boxShadow: [
                                      BoxShadow(
                                        color: accentColor.withValues(
                                          alpha: 0.08,
                                        ),

                                        blurRadius: 24,
                                      ),
                                    ],
                                  ),

                                  child: Row(
                                    children: [
                                      /// IMAGE
                                      Expanded(
                                        flex: 5,

                                        child: ClipRRect(
                                          borderRadius: BorderRadius.only(
                                            topLeft: Radius.circular(30.r),

                                            bottomLeft: Radius.circular(30.r),
                                          ),

                                          child: Stack(
                                            fit: StackFit.expand,

                                            children: [
                                              Image.network(
                                                item.image,

                                                fit: BoxFit.cover,
                                              ),

                                              Container(
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    begin: Alignment.topCenter,

                                                    end: Alignment.bottomCenter,

                                                    colors: [
                                                      Colors.black.withValues(
                                                        alpha: 0.05,
                                                      ),

                                                      Colors.black.withValues(
                                                        alpha: 0.55,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),

                                              Center(
                                                child: Container(
                                                  width: 70.w,

                                                  height: 70.w,

                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,

                                                    color: Colors.white,

                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: accentColor
                                                            .withValues(
                                                              alpha: 0.35,
                                                            ),

                                                        blurRadius: 25,
                                                      ),
                                                    ],
                                                  ),

                                                  child: Icon(
                                                    Icons.play_arrow_rounded,

                                                    color: accentColor,

                                                    size: 42.sp,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),

                                      /// TEXT
                                      Expanded(
                                        flex: 4,

                                        child: Padding(
                                          padding: EdgeInsets.all(24.w),

                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,

                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,

                                            children: [
                                              Text(
                                                item.title,

                                                style: TextStyle(
                                                  color: Colors.white,

                                                  fontSize: 28.sp,

                                                  fontWeight: FontWeight.bold,

                                                  height: 1.3,
                                                ),
                                              ),

                                              SizedBox(height: 14.h),

                                              Text(
                                                item.description,

                                                style: TextStyle(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.55),

                                                  fontSize: 15.sp,

                                                  height: 1.5,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _displayDriverName(String? driver) {
    if (driver == null ||
        driver.trim().isEmpty ||
        driver.trim().toLowerCase() == 'guest') {
      return AppStrings.guest;
    }

    final pref = DriverHiveService.load(driver);
    final displayName = pref?.displayName.trim();

    if (displayName != null && displayName.isNotEmpty) {
      return displayName;
    }

    return driver;
  }
}

class _TutorialItem {
  const _TutorialItem({
    required this.title,
    required this.description,
    required this.image,
    required this.action,
  });

  final String title;
  final String description;
  final String image;
  final VehicleAction action;
}
