import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:frontend/core/localization/app_strings.dart';
import 'package:frontend/core/services/ambient_light_mqtt_service.dart';
import 'package:frontend/core/themes/car_theme.dart';

int _red(Color color) => (color.toARGB32() >> 16) & 0xff;
int _green(Color color) => (color.toARGB32() >> 8) & 0xff;
int _blue(Color color) => color.toARGB32() & 0xff;

class AmbientLightContent extends StatefulWidget {
  const AmbientLightContent({super.key});

  @override
  State<AmbientLightContent> createState() => _AmbientLightContentState();
}

class _AmbientLightContentState extends State<AmbientLightContent>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glowController;

  bool _powerOn = true;
  int _brightness = 200;
  Color _selectedColor = const Color(0xFF5CE1FF);
  String _selectedPreset = 'AURORA';
  bool _sending = false;
  int _sendTicket = 0;

  static const List<_AmbientPreset> _presets = [
    _AmbientPreset('AURORA', 'Aurora', Icons.auto_awesome_rounded),
    _AmbientPreset('RAINBOW', 'Rainbow', Icons.gradient_rounded),
    _AmbientPreset('COMET', 'Comet', Icons.bolt_rounded),
    _AmbientPreset('BREATHE', 'Breathe', Icons.blur_on_rounded),
    _AmbientPreset('OCEAN', 'Ocean', Icons.water_rounded),
    _AmbientPreset('FIRE', 'Fire', Icons.local_fire_department_rounded),
    _AmbientPreset('HAPPY', 'Happy', Icons.sentiment_very_satisfied_rounded),
    _AmbientPreset('SAD', 'Sad', Icons.nightlight_round),
  ];

  static const List<Color> _swatches = [
    Color(0xFF5CE1FF),
    Color(0xFF70FFB5),
    Color(0xFFFFD166),
    Color(0xFFFF6B7A),
    Color(0xFFB69CFF),
    Color(0xFFFF7AD9),
    Color(0xFFFFFFFF),
    Color(0xFF86A8FF),
  ];

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  Future<void> _send(Future<bool> Function() action) async {
    final ticket = ++_sendTicket;
    setState(() => _sending = true);

    try {
      final ok = await action();
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? 'Ambient command sent' : 'Ambient command failed'),
          duration: const Duration(milliseconds: 900),
        ),
      );
    } finally {
      if (mounted && ticket == _sendTicket) {
        setState(() => _sending = false);
      }
    }
  }

  Future<void> _applyColor(Color color) async {
    setState(() {
      _powerOn = true;
      _selectedColor = color;
      _selectedPreset = 'RGB';
    });

    await _send(
      () => AmbientLightMqttService.instance.setColor(
        color,
        brightness: _brightness,
      ),
    );
  }

  void _previewColor(Color color) {
    setState(() {
      _powerOn = true;
      _selectedColor = color;
      _selectedPreset = 'RGB';
    });
  }

  Future<void> _applyPreset(String command) async {
    setState(() {
      _powerOn = true;
      _selectedPreset = command;
    });

    await _send(
      () => AmbientLightMqttService.instance.setPreset(
        command,
        brightness: _brightness,
      ),
    );
  }

  Future<void> _applyPower(bool enabled) async {
    setState(() => _powerOn = enabled);
    await _send(() => AmbientLightMqttService.instance.setPower(enabled));
  }

  Future<void> _syncCurrentColor() async {
    if (!_powerOn) return;
    await _send(
      () => AmbientLightMqttService.instance.setColor(
        _selectedColor,
        brightness: _brightness,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: CarThemes.currentTheme,
      builder: (context, themeType, _) {
        final theme = CarThemes.getTheme(themeType);
        final accent = themeType == CarThemeType.comfort
            ? const Color(0xFFBFD7FF)
            : theme.accentColor;

        return Scaffold(
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: theme.backgroundGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(46.w, 30.h, 46.w, 34.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _TopBar(theme: theme, accent: accent),
                    SizedBox(height: 22.h),
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            flex: 9,
                            child: _PreviewPanel(
                              controller: _glowController,
                              color: _selectedColor,
                              accent: accent,
                              theme: theme,
                              preset: _selectedPreset,
                              brightness: _brightness,
                              powerOn: _powerOn,
                              sending: _sending,
                              onPowerChanged: _applyPower,
                            ),
                          ),
                          SizedBox(width: 24.w),
                          Expanded(
                            flex: 12,
                            child: Column(
                              children: [
                                Flexible(
                                  flex: 8,
                                  child: _PresetPanel(
                                    theme: theme,
                                    accent: accent,
                                    presets: _presets,
                                    selectedPreset: _selectedPreset,
                                    onPreset: _applyPreset,
                                  ),
                                ),
                                SizedBox(height: 18.h),
                                Flexible(
                                  flex: 7,
                                  child: _ColorPanel(
                                    theme: theme,
                                    accent: accent,
                                    swatches: _swatches,
                                    color: _selectedColor,
                                    brightness: _brightness,
                                    onColor: _applyColor,
                                    onBrightness: (value) {
                                      setState(() => _brightness = value.round());
                                    },
                                    onBrightnessEnd: (_) => _syncCurrentColor(),
                                    onPreviewColor: _previewColor,
                                    onColorEnd: () {
                                      unawaited(_syncCurrentColor());
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.theme, required this.accent});

  final CarThemeData theme;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          tooltip: AppStrings.back,
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          color: theme.textColor,
        ),
        SizedBox(width: 16.w),
        Container(
          width: 58.w,
          height: 58.w,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(8.r),
            border: Border.all(color: accent.withValues(alpha: 0.34)),
          ),
          child: Icon(Icons.light_mode_rounded, color: accent, size: 30.sp),
        ),
        SizedBox(width: 18.w),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppStrings.ambientLight,
              style: TextStyle(
                color: theme.textColor,
                fontSize: 36.sp,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              'RGB cabin control + animated presets',
              style: TextStyle(
                color: theme.textColor.withValues(alpha: 0.62),
                fontSize: 15.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PreviewPanel extends StatelessWidget {
  const _PreviewPanel({
    required this.controller,
    required this.color,
    required this.accent,
    required this.theme,
    required this.preset,
    required this.brightness,
    required this.powerOn,
    required this.sending,
    required this.onPowerChanged,
  });

  final AnimationController controller;
  final Color color;
  final Color accent;
  final CarThemeData theme;
  final String preset;
  final int brightness;
  final bool powerOn;
  final bool sending;
  final ValueChanged<bool> onPowerChanged;

  @override
  Widget build(BuildContext context) {
    final orbSize = math.min(290.w, 0.25.sw).toDouble();
    final coreSize = orbSize * 0.58;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final t = controller.value;
        final pulse = 0.60 + (math.sin(t * math.pi * 2) + 1) * 0.18;
        final activeColor = powerOn ? color : Colors.white24;

        return Container(
          padding: EdgeInsets.all(22.w),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.26),
            borderRadius: BorderRadius.circular(8.r),
            border: Border.all(color: activeColor.withValues(alpha: 0.28)),
            boxShadow: [
              BoxShadow(
                color: activeColor.withValues(alpha: powerOn ? 0.28 : 0.04),
                blurRadius: powerOn ? 34 : 10,
                spreadRadius: powerOn ? 2 : 0,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _StatusChip(
                    icon: powerOn ? Icons.power_settings_new : Icons.power_off,
                    label: powerOn ? 'Online' : 'Standby',
                    color: activeColor,
                  ),
                  const Spacer(),
                  Switch(
                    value: powerOn,
                    activeThumbColor: accent,
                    activeTrackColor: accent.withValues(alpha: 0.38),
                    onChanged: sending ? null : onPowerChanged,
                  ),
                ],
              ),
              const Spacer(),
              Center(
                child: Container(
                  width: orbSize,
                  height: orbSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        activeColor.withValues(alpha: powerOn ? pulse : 0.12),
                        activeColor.withValues(alpha: powerOn ? 0.28 : 0.04),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Center(
                    child: Container(
                      width: coreSize,
                      height: coreSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: activeColor.withValues(alpha: powerOn ? 0.24 : 0.08),
                        border: Border.all(
                          color: activeColor.withValues(alpha: 0.52),
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        Icons.light_mode_rounded,
                        color: powerOn ? activeColor : Colors.white38,
                        size: 64.sp,
                      ),
                    ),
                  ),
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: _Readout(
                      label: 'Preset',
                      value: preset,
                      color: activeColor,
                    ),
                  ),
                  SizedBox(width: 14.w),
                  Expanded(
                    child: _Readout(
                      label: 'Brightness',
                      value: '$brightness',
                      color: activeColor,
                    ),
                  ),
                  SizedBox(width: 14.w),
                  Expanded(
                    child: _Readout(
                      label: 'RGB',
                      value: '${_red(color)}/${_green(color)}/${_blue(color)}',
                      color: activeColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PresetPanel extends StatelessWidget {
  const _PresetPanel({
    required this.theme,
    required this.accent,
    required this.presets,
    required this.selectedPreset,
    required this.onPreset,
  });

  final CarThemeData theme;
  final Color accent;
  final List<_AmbientPreset> presets;
  final String selectedPreset;
  final ValueChanged<String> onPreset;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      theme: theme,
      title: 'Animation presets',
      subtitle: 'Mood lighting scenes for the cabin',
      expandChild: true,
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        itemCount: presets.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          crossAxisSpacing: 10.w,
          mainAxisSpacing: 10.h,
          childAspectRatio: 1.95,
        ),
        itemBuilder: (context, index) {
          final preset = presets[index];
          final active = selectedPreset == preset.command;

          return InkWell(
            borderRadius: BorderRadius.circular(8.r),
            onTap: () => onPreset(preset.command),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: active
                    ? accent.withValues(alpha: 0.22)
                    : Colors.white.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(
                  color: active
                      ? accent.withValues(alpha: 0.72)
                      : Colors.white.withValues(alpha: 0.08),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    preset.icon,
                    color: active ? accent : theme.textColor.withValues(alpha: 0.78),
                    size: 22.sp,
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    preset.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: theme.textColor,
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ColorPanel extends StatelessWidget {
  const _ColorPanel({
    required this.theme,
    required this.accent,
    required this.swatches,
    required this.color,
    required this.brightness,
    required this.onColor,
    required this.onBrightness,
    required this.onBrightnessEnd,
    required this.onPreviewColor,
    required this.onColorEnd,
  });

  final CarThemeData theme;
  final Color accent;
  final List<Color> swatches;
  final Color color;
  final int brightness;
  final ValueChanged<Color> onColor;
  final ValueChanged<double> onBrightness;
  final ValueChanged<double> onBrightnessEnd;
  final ValueChanged<Color> onPreviewColor;
  final VoidCallback onColorEnd;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      theme: theme,
      title: 'RGB control',
      subtitle: 'Fine tune color and intensity',
      expandChild: false,
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 10.w,
              runSpacing: 10.h,
              children: swatches.map((swatch) {
                final active = swatch.toARGB32() == color.toARGB32();

                return InkWell(
                  borderRadius: BorderRadius.circular(8.r),
                  onTap: () => onColor(swatch),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 38.w,
                    height: 38.w,
                    decoration: BoxDecoration(
                      color: swatch,
                      borderRadius: BorderRadius.circular(8.r),
                      border: Border.all(
                        color: active ? Colors.white : Colors.white24,
                        width: active ? 3 : 1,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            SizedBox(height: 14.h),
            _RgbSlider(
              label: 'Red',
              value: _red(color),
              color: const Color(0xFFFF6B7A),
              onChanged: (value) => onPreviewColor(
                Color.fromARGB(255, value.round(), _green(color), _blue(color)),
              ),
              onChangeEnd: (_) => onColorEnd(),
            ),
            _RgbSlider(
              label: 'Green',
              value: _green(color),
              color: const Color(0xFF70FFB5),
              onChanged: (value) => onPreviewColor(
                Color.fromARGB(255, _red(color), value.round(), _blue(color)),
              ),
              onChangeEnd: (_) => onColorEnd(),
            ),
            _RgbSlider(
              label: 'Blue',
              value: _blue(color),
              color: const Color(0xFF5CE1FF),
              onChanged: (value) => onPreviewColor(
                Color.fromARGB(255, _red(color), _green(color), value.round()),
              ),
              onChangeEnd: (_) => onColorEnd(),
            ),
            SizedBox(height: 2.h),
            Row(
              children: [
                Icon(Icons.wb_sunny_rounded, color: accent, size: 20.sp),
                SizedBox(width: 10.w),
                Text(
                  'Brightness',
                  style: TextStyle(
                    color: theme.textColor,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: Slider(
                    min: 30,
                    max: 255,
                    value: brightness.toDouble(),
                    activeColor: accent,
                    inactiveColor: Colors.white.withValues(alpha: 0.14),
                    onChanged: onBrightness,
                    onChangeEnd: onBrightnessEnd,
                  ),
                ),
                SizedBox(
                  width: 44.w,
                  child: Text(
                    '$brightness',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: theme.textColor.withValues(alpha: 0.74),
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RgbSlider extends StatelessWidget {
  const _RgbSlider({
    required this.label,
    required this.value,
    required this.color,
    required this.onChanged,
    required this.onChangeEnd,
  });

  final String label;
  final int value;
  final Color color;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 50.w,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Slider(
            min: 0,
            max: 255,
            value: value.toDouble(),
            activeColor: color,
            inactiveColor: Colors.white.withValues(alpha: 0.12),
            onChanged: onChanged,
            onChangeEnd: onChangeEnd,
          ),
        ),
        SizedBox(
          width: 36.w,
          child: Text(
            '$value',
            textAlign: TextAlign.right,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.70),
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.theme,
    required this.title,
    required this.subtitle,
    required this.child,
    this.expandChild = false,
  });

  final CarThemeData theme;
  final String title;
  final String subtitle;
  final Widget child;
  final bool expandChild;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: theme.textColor,
              fontSize: 19.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            subtitle,
            style: TextStyle(
              color: theme.textColor.withValues(alpha: 0.55),
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 14.h),
          if (expandChild) Expanded(child: child) else child,
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 9.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: color.withValues(alpha: 0.34)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18.sp),
          SizedBox(width: 8.w),
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: 12.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _Readout extends StatelessWidget {
  const _Readout({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.50),
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 7.h),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontSize: 15.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _AmbientPreset {
  const _AmbientPreset(this.command, this.label, this.icon);

  final String command;
  final String label;
  final IconData icon;
}
