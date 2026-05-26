import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';

import 'package:frontend/core/localization/app_strings.dart';
import 'package:frontend/core/themes/car_theme.dart';

class CustomThemePage extends StatefulWidget {
  const CustomThemePage({super.key, this.initialTheme});

  final CarThemeData? initialTheme;

  @override
  State<CustomThemePage> createState() => _CustomThemePageState();
}

class _CustomThemePageState extends State<CustomThemePage> {
  Color gradient1 = const Color(0xFF111827);
  Color gradient2 = const Color(0xFF475569);
  Color accentColor = const Color(0xFF6CB4FF);
  Color fontColor = Colors.white;

  File? backgroundImage;

  final ImagePicker picker = ImagePicker();

  final List<_ThemePreset> _presets = const [
    _ThemePreset(
      name: 'Midnight',
      gradient1: Color(0xFF07111F),
      gradient2: Color(0xFF3C4858),
      accent: Color(0xFF6CB4FF),
      text: Colors.white,
    ),
    _ThemePreset(
      name: 'Graphite',
      gradient1: Color(0xFF18181B),
      gradient2: Color(0xFF71717A),
      accent: Color(0xFFA7F3D0),
      text: Colors.white,
    ),
    _ThemePreset(
      name: 'Crimson',
      gradient1: Color(0xFF1B0608),
      gradient2: Color(0xFF3F1D26),
      accent: Color(0xFFFF5C7A),
      text: Colors.white,
    ),
    _ThemePreset(
      name: 'Glacier',
      gradient1: Color(0xFFE5EDF5),
      gradient2: Color(0xFF7A91A8),
      accent: Color(0xFF246BFE),
      text: Color(0xFF0F172A),
    ),
  ];

  @override
  void initState() {
    super.initState();
    final current = widget.initialTheme ?? CarThemes.customTheme.value;
    gradient1 = current.backgroundGradient.first;
    gradient2 = current.backgroundGradient.length > 1
        ? current.backgroundGradient[1]
        : current.backgroundGradient.first;
    accentColor = current.accentColor;
    fontColor = current.textColor;

    final imagePath = current.backgroundImage;
    if (imagePath != null && imagePath.isNotEmpty) {
      backgroundImage = File(imagePath);
    }
  }

  CarThemeData _buildThemeData() {
    return CarThemeData(
      backgroundGradient: [gradient1, gradient2],
      accentColor: accentColor,
      buttonColor: accentColor,
      textColor: fontColor,
      backgroundImage: backgroundImage?.path,
    );
  }

  Future<void> pickImage() async {
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 92,
    );

    if (image == null) return;

    setState(() {
      backgroundImage = File(image.path);
    });
  }

  void clearImage() {
    setState(() {
      backgroundImage = null;
    });
  }

  void applyPreset(_ThemePreset preset) {
    setState(() {
      backgroundImage = null;
      gradient1 = preset.gradient1;
      gradient2 = preset.gradient2;
      accentColor = preset.accent;
      fontColor = preset.text;
    });
  }

  void openColorPicker({
    required String title,
    required Color current,
    required ValueChanged<Color> onSelect,
  }) {
    showDialog(
      context: context,
      builder: (context) {
        Color temp = current;

        return Dialog(
          backgroundColor: const Color(0xFF111111),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.r),
          ),
          child: SizedBox(
            width: 520.w,
            child: Padding(
              padding: EdgeInsets.all(24.w),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 22.sp,
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  SizedBox(height: 18.h),
                  ColorPicker(
                    pickerColor: current,
                    onColorChanged: (color) => temp = color,
                    pickerAreaHeightPercent: 0.62,
                    enableAlpha: false,
                    labelTypes: const [],
                    displayThumbColor: true,
                  ),
                  SizedBox(height: 18.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(AppStrings.cancel),
                      ),
                      SizedBox(width: 12.w),
                      FilledButton(
                        onPressed: () {
                          onSelect(temp);
                          Navigator.pop(context);
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: accentColor,
                          foregroundColor: _foregroundFor(accentColor),
                        ),
                        child: const Text('Select'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void saveTheme() {
    Navigator.pop(context, _buildThemeData());
  }

  Color _foregroundFor(Color color) {
    return color.computeLuminance() > 0.55 ? Colors.black : Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    final foreground = _foregroundFor(accentColor);

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: _BackgroundCanvas()),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.all(28.w),
              child: Column(
                children: [
                  _TopBar(fontColor: fontColor),
                  SizedBox(height: 20.h),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          flex: 7,
                          child: _LivePreview(
                            gradient1: gradient1,
                            gradient2: gradient2,
                            accentColor: accentColor,
                            fontColor: fontColor,
                            backgroundImage: backgroundImage,
                          ),
                        ),
                        SizedBox(width: 22.w),
                        SizedBox(
                          width: 410.w,
                          child: _ControlPanel(
                            gradient1: gradient1,
                            gradient2: gradient2,
                            accentColor: accentColor,
                            fontColor: fontColor,
                            foreground: foreground,
                            backgroundImage: backgroundImage,
                            presets: _presets,
                            onPresetTap: applyPreset,
                            onPickImage: pickImage,
                            onClearImage: clearImage,
                            onSave: saveTheme,
                            onGradient1Tap: () => openColorPicker(
                              title: 'Gradient 1',
                              current: gradient1,
                              onSelect: (color) {
                                setState(() {
                                  backgroundImage = null;
                                  gradient1 = color;
                                });
                              },
                            ),
                            onGradient2Tap: () => openColorPicker(
                              title: 'Gradient 2',
                              current: gradient2,
                              onSelect: (color) {
                                setState(() {
                                  backgroundImage = null;
                                  gradient2 = color;
                                });
                              },
                            ),
                            onAccentTap: () => openColorPicker(
                              title: 'Accent',
                              current: accentColor,
                              onSelect: (color) {
                                setState(() => accentColor = color);
                              },
                            ),
                            onFontTap: () => openColorPicker(
                              title: 'Text Color',
                              current: fontColor,
                              onSelect: (color) {
                                setState(() => fontColor = color);
                              },
                            ),
                          ),
                        ),
                      ],
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
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.fontColor});

  final Color fontColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46.h,
      child: Row(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(14.r),
            onTap: () => Navigator.of(context).maybePop(),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
              child: Row(
                children: [
                  Icon(Icons.arrow_back_ios_new, color: fontColor, size: 18.sp),
                  SizedBox(width: 8.w),
                  Text(
                    AppStrings.back,
                    style: TextStyle(
                      color: fontColor.withValues(alpha: 0.88),
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          Text(
            AppStrings.customTheme,
            style: TextStyle(
              color: fontColor,
              fontSize: 24.sp,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _BackgroundCanvas extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF050505),
      child: CustomPaint(
        painter: _GridPainter(),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _LivePreview extends StatelessWidget {
  const _LivePreview({
    required this.gradient1,
    required this.gradient2,
    required this.accentColor,
    required this.fontColor,
    required this.backgroundImage,
  });

  final Color gradient1;
  final Color gradient2;
  final Color accentColor;
  final Color fontColor;
  final File? backgroundImage;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(26.r),
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 350),
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
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withValues(alpha: 0.10),
                    Colors.black.withValues(alpha: 0.42),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.all(26.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _PreviewIcon(icon: Icons.map, accentColor: accentColor),
                      SizedBox(width: 14.w),
                      Text(
                        'Multimedia Cockpit',
                        style: TextStyle(
                          color: fontColor,
                          fontSize: 28.sp,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const Spacer(),
                      _PreviewPill(
                        icon: Icons.gps_fixed,
                        label: 'Online',
                        accentColor: accentColor,
                        fontColor: fontColor,
                      ),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: _PreviewPanel(
                          accentColor: accentColor,
                          fontColor: fontColor,
                        ),
                      ),
                      SizedBox(width: 18.w),
                      _PreviewDock(
                        accentColor: accentColor,
                        fontColor: fontColor,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                  borderRadius: BorderRadius.circular(26.r),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ControlPanel extends StatelessWidget {
  const _ControlPanel({
    required this.gradient1,
    required this.gradient2,
    required this.accentColor,
    required this.fontColor,
    required this.foreground,
    required this.backgroundImage,
    required this.presets,
    required this.onPresetTap,
    required this.onPickImage,
    required this.onClearImage,
    required this.onGradient1Tap,
    required this.onGradient2Tap,
    required this.onAccentTap,
    required this.onFontTap,
    required this.onSave,
  });

  final Color gradient1;
  final Color gradient2;
  final Color accentColor;
  final Color fontColor;
  final Color foreground;
  final File? backgroundImage;
  final List<_ThemePreset> presets;
  final ValueChanged<_ThemePreset> onPresetTap;
  final VoidCallback onPickImage;
  final VoidCallback onClearImage;
  final VoidCallback onGradient1Tap;
  final VoidCallback onGradient2Tap;
  final VoidCallback onAccentTap;
  final VoidCallback onFontTap;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: const Color(0xFF101010).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Theme Studio',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24.sp,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 18.h),
            _PanelSection(
              title: 'Background Image',
              child: _ImagePickerTile(
                image: backgroundImage,
                accentColor: accentColor,
                onPickImage: onPickImage,
                onClearImage: onClearImage,
              ),
            ),
            SizedBox(height: 18.h),
            _PanelSection(
              title: 'Quick Presets',
              child: Wrap(
                spacing: 10.w,
                runSpacing: 10.h,
                children: presets
                    .map(
                      (preset) => _PresetChip(
                        preset: preset,
                        onTap: () => onPresetTap(preset),
                      ),
                    )
                    .toList(),
              ),
            ),
            SizedBox(height: 18.h),
            _PanelSection(
              title: 'Colors',
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _ColorTile(
                          label: 'Gradient 1',
                          color: gradient1,
                          onTap: onGradient1Tap,
                        ),
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: _ColorTile(
                          label: 'Gradient 2',
                          color: gradient2,
                          onTap: onGradient2Tap,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 10.h),
                  Row(
                    children: [
                      Expanded(
                        child: _ColorTile(
                          label: 'Accent',
                          color: accentColor,
                          onTap: onAccentTap,
                        ),
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: _ColorTile(
                          label: 'Text',
                          color: fontColor,
                          onTap: onFontTap,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 22.h),
            SizedBox(
              width: double.infinity,
              height: 52.h,
              child: FilledButton.icon(
                onPressed: onSave,
                style: FilledButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: foreground,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                ),
                icon: const Icon(Icons.check),
                label: Text(
                  'Save Theme',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImagePickerTile extends StatelessWidget {
  const _ImagePickerTile({
    required this.image,
    required this.accentColor,
    required this.onPickImage,
    required this.onClearImage,
  });

  final File? image;
  final Color accentColor;
  final VoidCallback onPickImage;
  final VoidCallback onClearImage;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 150.h,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: accentColor.withValues(alpha: 0.32)),
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        children: [
          Positioned.fill(
            child: image != null
                ? Image.file(image!, fit: BoxFit.cover)
                : DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0.09),
                          Colors.white.withValues(alpha: 0.02),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: image == null ? 0 : 0.25),
              ),
            ),
          ),
          Center(
            child: FilledButton.icon(
              onPressed: onPickImage,
              style: FilledButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor:
                    accentColor.computeLuminance() > 0.55
                        ? Colors.black
                        : Colors.white,
              ),
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: Text(image == null ? 'Upload Image' : 'Change Image'),
            ),
          ),
          if (image != null)
            Positioned(
              top: 10.h,
              right: 10.w,
              child: IconButton.filledTonal(
                onPressed: onClearImage,
                icon: const Icon(Icons.close),
              ),
            ),
        ],
      ),
    );
  }
}

class _PanelSection extends StatelessWidget {
  const _PanelSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: Colors.white70,
            fontSize: 13.sp,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: 10.h),
        child,
      ],
    );
  }
}

class _ColorTile extends StatelessWidget {
  const _ColorTile({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16.r),
      child: Container(
        height: 74.h,
        padding: EdgeInsets.all(10.w),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            Container(
              width: 42.w,
              height: 42.w,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
              ),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({required this.preset, required this.onTap});

  final _ThemePreset preset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14.r),
      child: Container(
        width: 176.w,
        height: 58.h,
        padding: EdgeInsets.symmetric(horizontal: 10.w),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            Container(
              width: 38.w,
              height: 38.w,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(11.r),
                gradient: LinearGradient(
                  colors: [preset.gradient1, preset.gradient2],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Align(
                alignment: Alignment.bottomRight,
                child: Container(
                  width: 14.w,
                  height: 14.w,
                  decoration: BoxDecoration(
                    color: preset.accent,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black),
                  ),
                ),
              ),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Text(
                preset.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewIcon extends StatelessWidget {
  const _PreviewIcon({required this.icon, required this.accentColor});

  final IconData icon;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48.w,
      height: 48.w,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.34),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: accentColor.withValues(alpha: 0.45)),
      ),
      child: Icon(icon, color: accentColor, size: 25.sp),
    );
  }
}

class _PreviewPill extends StatelessWidget {
  const _PreviewPill({
    required this.icon,
    required this.label,
    required this.accentColor,
    required this.fontColor,
  });

  final IconData icon;
  final String label;
  final Color accentColor;
  final Color fontColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.36),
        borderRadius: BorderRadius.circular(18.r),
      ),
      child: Row(
        children: [
          Icon(icon, color: accentColor, size: 18.sp),
          SizedBox(width: 8.w),
          Text(
            label,
            style: TextStyle(
              color: fontColor,
              fontSize: 13.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewPanel extends StatelessWidget {
  const _PreviewPanel({required this.accentColor, required this.fontColor});

  final Color accentColor;
  final Color fontColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 154.h,
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.34),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Now Driving',
            style: TextStyle(
              color: fontColor.withValues(alpha: 0.74),
              fontSize: 12.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 10.h),
          Text(
            'Comfort cabin ready',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: fontColor,
              fontSize: 24.sp,
              fontWeight: FontWeight.w900,
            ),
          ),
          const Spacer(),
          LinearProgressIndicator(
            value: 0.68,
            minHeight: 6.h,
            borderRadius: BorderRadius.circular(99),
            backgroundColor: Colors.white.withValues(alpha: 0.12),
            valueColor: AlwaysStoppedAnimation<Color>(accentColor),
          ),
        ],
      ),
    );
  }
}

class _PreviewDock extends StatelessWidget {
  const _PreviewDock({required this.accentColor, required this.fontColor});

  final Color accentColor;
  final Color fontColor;

  @override
  Widget build(BuildContext context) {
    final items = [
      Icons.music_note,
      Icons.navigation,
      Icons.air,
      Icons.settings,
    ];

    return Container(
      width: 252.w,
      height: 78.h,
      padding: EdgeInsets.symmetric(horizontal: 14.w),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(22.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: items
            .map(
              (icon) => Container(
                width: 44.w,
                height: 44.w,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14.r),
                ),
                child: Icon(icon, color: accentColor, size: 22.sp),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.035)
      ..strokeWidth = 1;
    const gap = 42.0;

    for (double x = 0; x < size.width; x += gap) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    for (double y = 0; y < size.height; y += gap) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ThemePreset {
  const _ThemePreset({
    required this.name,
    required this.gradient1,
    required this.gradient2,
    required this.accent,
    required this.text,
  });

  final String name;
  final Color gradient1;
  final Color gradient2;
  final Color accent;
  final Color text;
}
