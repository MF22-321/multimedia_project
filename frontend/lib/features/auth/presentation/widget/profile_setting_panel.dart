import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:frontend/features/auth/presentation/widget/fan_temperature_widget.dart';
import 'package:frontend/features/auth/presentation/widget/multimedia_theme_section_widget.dart';
import 'package:frontend/features/auth/presentation/widget/smart_fragrance_widget.dart';

class ProfileSettingsPanel extends StatefulWidget {
  const ProfileSettingsPanel({super.key});

  @override
  State<ProfileSettingsPanel> createState() => _ProfileSettingsPanelState();
}

class _ProfileSettingsPanelState extends State<ProfileSettingsPanel> {
  int selectedCartridge = 2;
  int fanLevel = 3;
  int temperature = 19;
  int selectedTheme = 1;

  final List<List<Color>> themes = [
    [Color(0xFF1E3C72), Color(0xFF2A5298)],
    [Color(0xFF232526), Color(0xFF414345)],
    [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
    [Color(0xFF11998E), Color(0xFF38EF7D)],
    [Color(0xFFFF512F), Color(0xFFDD2476)],
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20).w,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF737373), Color(0xFFBABABA), ],
             stops: [0.0, 0.96],
            begin: Alignment.centerLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.only(topLeft: Radius.circular(40.r)),
          border: Border(
            top: BorderSide(color: Colors.white, width: 2.w),
            left: BorderSide(color: Colors.white, width: 2.w),
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
                  color: Colors.white,
                ),
              ),
            ),
      
            SizedBox(height: 21.h),
            Divider(color: Colors.white, thickness: 2.h,   height: 2.h,),
      
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    /// SMART FRAGRANCE
                    SmartFragranceSection(
                      selectedCartridge: selectedCartridge,
                      onSelect: (v) => setState(() => selectedCartridge = v),
                    ),
      
                    FanTemperatureSection(
                      fanLevel: fanLevel,
                      temperature: temperature,
                      onFanPlus: () => setState(() => fanLevel++),
                      onFanMinus: () => setState(() => fanLevel--),
                      onTempPlus: () => setState(() => temperature++),
                      onTempMinus: () => setState(() => temperature--),
                    ),
      
                    MultimediaThemeSection(
                      selectedTheme: selectedTheme,
                      themes: themes,
                      onThemeChanged: (i) => setState(() => selectedTheme = i),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

}