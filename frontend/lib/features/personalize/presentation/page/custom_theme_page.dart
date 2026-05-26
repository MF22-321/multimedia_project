import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:frontend/core/themes/car_theme.dart';

class CustomThemePage extends StatefulWidget {
  const CustomThemePage({super.key});

  @override
  State<CustomThemePage> createState() => _CustomThemePageState();
}

class _CustomThemePageState extends State<CustomThemePage> {
  Color gradient1 = const Color(0xFF737373);
  Color gradient2 = const Color(0xFFBABABA);

  Color accentColor = Colors.blue;
  Color fontColor = Colors.white;

  File? backgroundImage;

  final ImagePicker picker = ImagePicker();

  /// LIVE UPDATE THEME
  void updateLiveTheme() {
    CarThemes.customTheme.value = CarThemeData(
      backgroundGradient: [gradient1, gradient2],
      accentColor: accentColor,
      buttonColor: accentColor,
      textColor: fontColor,
      backgroundImage: backgroundImage?.path,
    );

    CarThemes.currentTheme.value = CarThemeType.custom;
  }

  /// PICK IMAGE
  void pickImage() async {
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        backgroundImage = File(image.path);
      });

      updateLiveTheme();
    }
  }

  /// COLOR PICKER
  void openColorPicker(Color current, Function(Color) onSelect) {
    showDialog(
      context: context,
      builder: (context) {
        Color temp = current;

        return Dialog(
          backgroundColor: Colors.black87,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25.r),
          ),

          child: Container(
            width: 500.w,
            padding: EdgeInsets.all(30.w),

            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Pick Color",
                  style: TextStyle(
                    fontSize: 22.sp,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                SizedBox(height: 25.h),

                ColorPicker(
                  pickerColor: current,
                  onColorChanged: (color) {
                    temp = color;
                  },
                  pickerAreaHeightPercent: 0.6,
                  enableAlpha: false,
                ),

                SizedBox(height: 20.h),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Cancel"),
                    ),

                    SizedBox(width: 20.w),

                    ElevatedButton(
                      onPressed: () {
                        onSelect(temp);
                        Navigator.pop(context);
                      },
                      child: const Text("Select"),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// SAVE FINAL THEME
  void saveTheme() {
    updateLiveTheme();

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          /// BACKGROUND PREVIEW
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [gradient1, gradient2],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              image: backgroundImage != null
                  ? DecorationImage(
                      image: FileImage(backgroundImage!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
          ),

          /// CENTER PANEL
          Center(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  /// TITLE
                  Text(
                    "Custom Theme Editor",
                    style: TextStyle(
                      fontSize: 32.sp,
                      fontWeight: FontWeight.bold,
                      color: fontColor,
                    ),
                  ),

                  SizedBox(height: 40.h),

                  /// BACKGROUND
                  _sectionTitle("Background"),

                  SizedBox(height: 20.h),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _colorButton(
                        "Gradient 1",
                        gradient1,
                        () => openColorPicker(gradient1, (c) {
                          setState(() => gradient1 = c);
                          updateLiveTheme();
                        }),
                      ),

                      SizedBox(width: 30.w),

                      _colorButton(
                        "Gradient 2",
                        gradient2,
                        () => openColorPicker(gradient2, (c) {
                          setState(() => gradient2 = c);
                          updateLiveTheme();
                        }),
                      ),

                      SizedBox(width: 30.w),

                      _iconButton(Icons.image, "Background", pickImage),
                    ],
                  ),

                  SizedBox(height: 40.h),

                  /// ACCENT
                  _sectionTitle("Accent Color"),

                  SizedBox(height: 20.h),

                  _colorButton(
                    "Accent",
                    accentColor,
                    () => openColorPicker(accentColor, (c) {
                      setState(() => accentColor = c);
                      updateLiveTheme();
                    }),
                  ),

                  SizedBox(height: 25.h),

                  /// FONT
                  _sectionTitle("Font Color"),

                  SizedBox(height: 20.h),

                  _colorButton(
                    "Font",
                    fontColor,
                    () => openColorPicker(fontColor, (c) {
                      setState(() => fontColor = c);
                      updateLiveTheme();
                    }),
                  ),

                  SizedBox(height: 25.h),

                  /// SAVE BUTTON
                  GestureDetector(
                    onTap: saveTheme,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 80.w,
                        vertical: 18.h,
                      ),
                      decoration: BoxDecoration(
                        color: accentColor,
                        borderRadius: BorderRadius.circular(40.r),
                        boxShadow: [
                          BoxShadow(
                            color: accentColor.withValues(alpha: 0.5),
                            blurRadius: 25,
                          ),
                        ],
                      ),
                      child: Text(
                        "Save Theme",
                        style: TextStyle(
                          fontSize: 20.sp,
                          fontWeight: FontWeight.bold,
                          color: fontColor,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          /// BACK BUTTON
          Positioned(
            top: 40.h,
            left: 40.w,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () {
                Navigator.of(context).maybePop();
              },
              child: Row(
                children: [
                  Icon(Icons.arrow_back_ios, color: fontColor, size: 20.sp),
                  SizedBox(width: 8.w),
                  Text(
                    "Back",
                    style: TextStyle(
                      color: fontColor.withValues(alpha: 0.9),
                      fontSize: 16.sp,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Center(
      child: Text(
        title,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 20.sp,
          color: fontColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _colorButton(String label, Color color, VoidCallback onTap) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 80.w,
            height: 80.w,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(color: Colors.white),
            ),
          ),
        ),

        SizedBox(height: 10.h),

        Text(
          label,
          style: TextStyle(color: fontColor, fontSize: 14.sp),
        ),
      ],
    );
  }

  Widget _iconButton(IconData icon, String label, VoidCallback onTap) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 80.w,
            height: 80.w,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20.r),
            ),
            child: Icon(icon),
          ),
        ),

        SizedBox(height: 10.h),

        Text(
          label,
          style: TextStyle(color: fontColor, fontSize: 14.sp),
        ),
      ],
    );
  }
}
