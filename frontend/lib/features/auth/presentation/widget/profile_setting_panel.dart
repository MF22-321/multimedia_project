// import 'package:flutter/material.dart';
// import 'package:flutter_screenutil/flutter_screenutil.dart';
// import 'package:frontend/core/themes/car_theme.dart';
// import 'package:frontend/features/auth/presentation/widget/fan_temperature_widget.dart';
// import 'package:frontend/features/auth/presentation/widget/multimedia_theme_section_widget.dart';
// import 'package:frontend/features/auth/presentation/widget/smart_fragrance_widget.dart';

// class ProfileSettingsPanel extends StatefulWidget {
//   const ProfileSettingsPanel({super.key});

//   @override
//   State<ProfileSettingsPanel> createState() => _ProfileSettingsPanelState();
// }

// class _ProfileSettingsPanelState extends State<ProfileSettingsPanel> {

//   int selectedCartridge = 2;
//   int fanLevel = 3;
//   int temperature = 19;
//   int selectedTheme = 0;

//   final List<String> themeImages = [
//     "assets/themes/theme_comfort.png",
//     "assets/themes/theme_sport.png",
//     "assets/themes/theme_futuristic.png",
//     "assets/themes/theme_retro.png",
//     "assets/themes/theme_playful.png",
//   ];

//   void changeTheme(int index) {

//     setState(() {
//       selectedTheme = index;
//     });

//     /// update global theme
//     CarThemes.currentTheme.value = CarThemeType.values[index];
//   }

//   @override
//   Widget build(BuildContext context) {

//     return Padding(
//       padding: const EdgeInsets.only(top: 20).w,

//       child: ValueListenableBuilder(
//         valueListenable: CarThemes.currentTheme,

//         builder: (context, themeType, _) {

//           final theme = CarThemes.getTheme(themeType);

//           return AnimatedContainer(
//             duration: const Duration(milliseconds: 400),

//             decoration: BoxDecoration(

//               gradient: LinearGradient(
//                 colors: theme.backgroundGradient,
//                 begin: Alignment.centerLeft,
//                 end: Alignment.bottomRight,
//               ),

//               borderRadius: BorderRadius.only(
//                 topLeft: Radius.circular(40.r),
//               ),

//               border: Border(
//                 top: BorderSide(color: theme.accentColor, width: 2.w),
//                 left: BorderSide(color: theme.accentColor, width: 2.w),
//               ),
//             ),

//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [

//                 /// HEADER
//                 SizedBox(height: 43.h),

//                 Padding(
//                   padding: const EdgeInsets.symmetric(horizontal: 20).w,
//                   child: Text(
//                     "Profile Settings",
//                     style: TextStyle(
//                       fontSize: 26.sp,
//                       fontWeight: FontWeight.bold,
//                       color: theme.textColor,
//                     ),
//                   ),
//                 ),

//                 SizedBox(height: 21.h),

//                 Divider(
//                   color: theme.accentColor,
//                   thickness: 2.h,
//                   height: 2.h,
//                 ),

//                 /// CONTENT
//                 Expanded(
//                   child: SingleChildScrollView(
//                     physics: const BouncingScrollPhysics(),

//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [

//                         /// SMART FRAGRANCE
//                         SmartFragranceSection(
//                           selectedCartridge: selectedCartridge,
//                           onSelect: (v) =>
//                               setState(() => selectedCartridge = v),
//                         ),
//                         Divider(
//                           color: theme.accentColor,
//                           thickness: 2.h,
//                           height: 0.h,
//                         ),

//                         /// FAN TEMP
//                         FanTemperatureSection(
//                           fanLevel: fanLevel,
//                           temperature: temperature,
//                           onFanPlus: () => setState(() => fanLevel++),
//                           onFanMinus: () => setState(() => fanLevel--),
//                           onTempPlus: () => setState(() => temperature++),
//                           onTempMinus: () => setState(() => temperature--),
//                         ),
//                                                 Divider(
//                           color: theme.accentColor,
//                           thickness: 2.h,
//                           height: 0.h,
//                         ),

//                         /// THEME
//                         MultimediaThemeSection(
//                           selectedTheme: selectedTheme,
//                           themeImages: themeImages,
//                           onThemeChanged: changeTheme,
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           );
//         },
//       ),
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:frontend/core/themes/car_theme.dart';
import 'package:frontend/features/auth/presentation/widget/fan_temperature_widget.dart';
import 'package:frontend/features/auth/presentation/widget/multimedia_theme_section_widget.dart';
import 'package:frontend/features/auth/presentation/widget/smart_fragrance_widget.dart';

class ProfileSettingsPanel extends StatelessWidget {
  final int selectedCartridge;
  final int fanLevel;
  final int temperature;
  final int selectedTheme;

  final Function(int) onCartridgeChanged;
  final VoidCallback onFanPlus;
  final VoidCallback onFanMinus;
  final VoidCallback onTempPlus;
  final VoidCallback onTempMinus;
  final Function(int) onThemeChanged;

  const ProfileSettingsPanel({
    super.key,
    required this.selectedCartridge,
    required this.fanLevel,
    required this.temperature,
    required this.selectedTheme,
    required this.onCartridgeChanged,
    required this.onFanPlus,
    required this.onFanMinus,
    required this.onTempPlus,
    required this.onTempMinus,
    required this.onThemeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final List<String> themeImages = [
      "assets/themes/theme_comfort.png",
      "assets/themes/theme_sport.png",
      "assets/themes/theme_futuristic.png",
      "assets/themes/theme_retro.png",
      "assets/themes/theme_playful.png",
    ];

    return Padding(
      padding: const EdgeInsets.only(top: 20).w,
      child: ValueListenableBuilder(
        valueListenable: CarThemes.currentTheme,
        builder: (context, themeType, _) {
          final theme = CarThemes.getTheme(themeType);

          return AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: theme.backgroundGradient,
                begin: Alignment.centerLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(40.r),
              ),
              border: Border(
                top: BorderSide(color: theme.accentColor, width: 2.w),
                left: BorderSide(color: theme.accentColor, width: 2.w),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// HEADER
                SizedBox(height: 43.h),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20).w,
                  child: Text(
                    "Profile Settings",
                    style: TextStyle(
                      fontSize: 26.sp,
                      fontWeight: FontWeight.bold,
                      color: theme.textColor,
                    ),
                  ),
                ),

                SizedBox(height: 21.h),

                Divider(
                  color: theme.accentColor,
                  thickness: 2.h,
                  height: 2.h,
                ),

                /// CONTENT
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        /// SMART FRAGRANCE
                        SmartFragranceSection(
                          selectedCartridge: selectedCartridge,
                          onSelect: onCartridgeChanged,
                        ),

                        Divider(
                          color: theme.accentColor,
                          thickness: 2.h,
                          height: 0.h,
                        ),

                        /// FAN TEMP
                        FanTemperatureSection(
                          fanLevel: fanLevel,
                          temperature: temperature,
                          onFanPlus: onFanPlus,
                          onFanMinus: onFanMinus,
                          onTempPlus: onTempPlus,
                          onTempMinus: onTempMinus,
                        ),

                        Divider(
                          color: theme.accentColor,
                          thickness: 2.h,
                          height: 0.h,
                        ),

                        /// THEME
                        MultimediaThemeSection(
                          selectedTheme: selectedTheme,
                          themeImages: themeImages,
                          onThemeChanged: onThemeChanged,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}