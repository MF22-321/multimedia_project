import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:frontend/core/model/auto_interval_option.dart';
import 'package:frontend/core/services/mqtt_service.dart';
import 'package:frontend/core/themes/car_theme.dart';
import 'package:frontend/features/smart_fragrance/widget/fragrance_card.dart';
import 'package:frontend/features/smart_fragrance/widget/main_control_panel.dart';
import 'package:frontend/features/smart_fragrance/widget/speed_control_card.dart';

class SmartFragrancePage extends StatefulWidget {
  const SmartFragrancePage({super.key});

  @override
  State<SmartFragrancePage> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<SmartFragrancePage> {
  final MQTTService mqtt = MQTTService();
  StreamSubscription<Map<String, dynamic>>? _mqttSubscription;
  StreamSubscription<bool>? _mqttConnectionSubscription;

  bool coffeeEnabled = false;
  bool lavenderEnabled = false;

  int coffeeLevel = 75;
  int lavenderLevel = 50;

  int coffeeSpeed = 1;
  int lavenderSpeed = 1;

  bool mainPower = false;
  bool autoMode = false;
  AutoIntervalOption selectedAutoInterval = AutoIntervalOption.s10;
  int selectedCartridge = 0;

  bool isLoading = true;
  bool isUpdating = false;
  bool mqttConnected = false;

  @override
  void initState() {
    super.initState();
    _initMQTT();
  }

  Future<void> _initMQTT() async {
    _mqttConnectionSubscription = mqtt.connectionStream.listen((connected) {
      if (!mounted) return;
      setState(() => mqttConnected = connected);
    });

    final connected = await mqtt.connect();

    if (mounted) {
      setState(() {
        isLoading = false;
        mqttConnected = connected;
      });
    }

    _mqttSubscription = mqtt.stream.listen((data) {
      if (!mounted) return;

      setState(() {
        selectedCartridge =
            (data['selectedCartridge'] as num?)?.toInt() ?? selectedCartridge;
        mainPower = data['mainPower'] ?? mainPower;
        autoMode = data['autoMode'] ?? autoMode;
        selectedAutoInterval = AutoIntervalOptionX.fromFirebase(
          data['autoInterval'],
        );

        coffeeEnabled = data['motor1']?['enabled'] ?? coffeeEnabled;
        coffeeSpeed =
            ((data['motor1']?['speedLevel'] as num?)?.toInt() ?? coffeeSpeed)
                .clamp(1, 3)
                .toInt();

        lavenderEnabled = data['motor2']?['enabled'] ?? lavenderEnabled;
        lavenderSpeed =
            ((data['motor2']?['speedLevel'] as num?)?.toInt() ??
                    lavenderSpeed)
                .clamp(1, 3)
                .toInt();
      });
    });
  }

  Future<void> _publish(Map<String, dynamic> data) async {
    setState(() => isUpdating = true);

    final published = await mqtt.publish('humidifier/control', data);
    if (mounted) {
      setState(() => mqttConnected = published || mqtt.isConnected);
    }

    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => isUpdating = false);
    });
  }

  int _cartridgeForState({
    required bool coffee,
    required bool lavender,
  }) {
    if (coffee && lavender) return 3;
    if (coffee && !lavender) return 1;
    if (lavender && !coffee) return 2;
    return 0;
  }

  Map<String, dynamic> _statePayload({
    bool? power,
    bool? auto,
    AutoIntervalOption? interval,
    bool? coffee,
    bool? lavender,
    int? coffeeSpeedLevel,
    int? lavenderSpeedLevel,
  }) {
    final nextCoffee = coffee ?? coffeeEnabled;
    final nextLavender = lavender ?? lavenderEnabled;
    final nextCartridge = _cartridgeForState(
      coffee: nextCoffee,
      lavender: nextLavender,
    );
    final nextPower = power ?? nextCartridge != 0;

    return {
      'selectedCartridge': nextCartridge,
      'mainPower': nextPower,
      'autoMode': auto ?? autoMode,
      'autoInterval': (interval ?? selectedAutoInterval).firebaseValue,
      'motor1': {
        'enabled': nextCoffee,
        'speedLevel': coffeeSpeedLevel ?? coffeeSpeed,
      },
      'motor2': {
        'enabled': nextLavender,
        'speedLevel': lavenderSpeedLevel ?? lavenderSpeed,
      },
    };
  }

  Future<void> _toggleMainPower() async {
    final newValue = !mainPower;
    final nextCoffee = newValue && !coffeeEnabled && !lavenderEnabled
        ? true
        : coffeeEnabled;
    final nextLavender = newValue ? lavenderEnabled : false;

    setState(() {
      mainPower = newValue;
      coffeeEnabled = newValue ? nextCoffee : false;
      lavenderEnabled = nextLavender;
      selectedCartridge = _cartridgeForState(
        coffee: coffeeEnabled,
        lavender: lavenderEnabled,
      );
    });
    await _publish(
      _statePayload(
        power: newValue,
        coffee: newValue ? nextCoffee : false,
        lavender: nextLavender,
      ),
    );
  }

  Future<void> _toggleAutoMode() async {
    final newValue = !autoMode;
    setState(() => autoMode = newValue);

    await _publish(_statePayload(auto: newValue));
  }

  Future<void> _setAutoInterval(AutoIntervalOption option) async {
    setState(() => selectedAutoInterval = option);
    await _publish(_statePayload(interval: option));
  }

  Future<void> _toggleCoffeeEnabled() async {
    final newValue = !coffeeEnabled;
    final nextLavender = lavenderEnabled;
    final nextPower = newValue || nextLavender;

    setState(() {
      coffeeEnabled = newValue;
      selectedCartridge = _cartridgeForState(
        coffee: newValue,
        lavender: nextLavender,
      );
      mainPower = nextPower;
    });
    await _publish(
      _statePayload(
        power: nextPower,
        coffee: newValue,
        lavender: nextLavender,
      ),
    );
  }

  Future<void> _increaseCoffeeSpeed() async {
    if (coffeeSpeed >= 3) return;
    final newValue = coffeeSpeed + 1;
    setState(() => coffeeSpeed = newValue);
    await _publish(_statePayload(coffeeSpeedLevel: newValue));
  }

  Future<void> _decreaseCoffeeSpeed() async {
    if (coffeeSpeed <= 1) return;
    final newValue = coffeeSpeed - 1;
    setState(() => coffeeSpeed = newValue);
    await _publish(_statePayload(coffeeSpeedLevel: newValue));
  }

  Future<void> _toggleLavenderEnabled() async {
    final newValue = !lavenderEnabled;
    final nextCoffee = coffeeEnabled;
    final nextPower = nextCoffee || newValue;

    setState(() {
      lavenderEnabled = newValue;
      selectedCartridge = _cartridgeForState(
        coffee: nextCoffee,
        lavender: newValue,
      );
      mainPower = nextPower;
    });
    await _publish(
      _statePayload(
        power: nextPower,
        coffee: nextCoffee,
        lavender: newValue,
      ),
    );
  }

  Future<void> _increaseLavenderSpeed() async {
    if (lavenderSpeed >= 3) return;
    final newValue = lavenderSpeed + 1;
    setState(() => lavenderSpeed = newValue);
    await _publish(_statePayload(lavenderSpeedLevel: newValue));
  }

  Future<void> _decreaseLavenderSpeed() async {
    if (lavenderSpeed <= 1) return;
    final newValue = lavenderSpeed - 1;
    setState(() => lavenderSpeed = newValue);
    await _publish(_statePayload(lavenderSpeedLevel: newValue));
  }

  void _showAutoUpdateMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Auto-update mode active',
          style: TextStyle(fontSize: 14.sp),
        ),
        duration: const Duration(milliseconds: 900),
      ),
    );
  }

  @override
  void dispose() {
    _mqttSubscription?.cancel();
    _mqttConnectionSubscription?.cancel();
    mqtt.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: CarThemes.currentTheme,
      builder: (context, themeType, _) {
        return ValueListenableBuilder(
          valueListenable: CarThemes.customTheme,
          builder: (context, __, ___) {
            final theme = CarThemes.getTheme(themeType);
            final accent = getMusicAccentColor(themeType, theme);
            final panelColor = Colors.black.withValues(alpha: 0.24);
            final panelDarkColor = Colors.black.withValues(alpha: 0.38);
            final surfaceColor = Colors.white.withValues(alpha: 0.88);
            const surfaceTextColor = Color(0xFF111111);

            return Scaffold(
              backgroundColor: theme.backgroundGradient.first,
              body: isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2.w,
                        color: accent,
                      ),
                    )
                  : Stack(
              children: [
                Positioned.fill(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 500),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: theme.backgroundGradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      image: theme.backgroundImage != null
                          ? DecorationImage(
                              image: FileImage(File(theme.backgroundImage!)),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                  ),
                ),
                Column(
                  children: [
                    Container(
                      height: 110.h,
                      width: double.infinity,
                      color: Colors.black.withValues(alpha: 0.26),
                      alignment: Alignment.centerLeft,
                      padding: EdgeInsets.symmetric(horizontal: 44.w),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            behavior: HitTestBehavior.opaque,
                            child: Row(
                              children: [
                                Icon(
                                  Icons.arrow_back_ios,
                                  color: theme.textColor,
                                  size: 20.sp,
                                ),
                                SizedBox(width: 8.w),
                                Text(
                                  "Back",
                                  style: TextStyle(
                                    color: theme.textColor.withValues(
                                      alpha: 0.78,
                                    ),
                                    fontSize: 16.sp,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: 350.w),
                          Text(
                            "Smart Fragrance Control",
                            style: TextStyle(
                              fontSize: 32.sp,
                              fontWeight: FontWeight.w700,
                              color: theme.textColor,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 16.w,
                              vertical: 8.h,
                            ),
                            decoration: BoxDecoration(
                              color: mqttConnected
                                  ? accent.withValues(alpha: 0.22)
                                  : Colors.redAccent.withValues(alpha: 0.22),
                              borderRadius: BorderRadius.circular(20.r),
                              border: Border.all(
                                color: mqttConnected ? accent : Colors.redAccent,
                              ),
                            ),
                            child: Text(
                              mqttConnected ? 'MQTT Connected' : 'MQTT Offline',
                              style: TextStyle(
                                color: theme.textColor,
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 36.w,
                            vertical: 28.h,
                          ),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: 1400.w),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    children: [
                                      Wrap(
                                        spacing: 26.w,
                                        runSpacing: 26.h,
                                        children: [
                                          Column(
                                            children: [
                                              FragranceCard(
                                                title: 'Fragrance 1',
                                                slotNumber: '01',
                                                icon: Icons.air,
                                                levelPercent: coffeeLevel,
                                                fillPercent: coffeeLevel,
                                                isEnabled: coffeeEnabled,
                                                onToggle: _toggleCoffeeEnabled,
                                                accentColor: accent,
                                                textColor: theme.textColor,
                                                panelColor: panelColor,
                                                panelDarkColor: panelDarkColor,
                                              ),
                                              SizedBox(height: 28.h),
                                              SpeedControlCard(
                                                speedLevel: coffeeSpeed,
                                                onIncrease:
                                                    _increaseCoffeeSpeed,
                                                onDecrease:
                                                    _decreaseCoffeeSpeed,
                                                accentColor: accent,
                                                textColor: theme.textColor,
                                              ),
                                            ],
                                          ),
                                          Column(
                                            children: [
                                              FragranceCard(
                                                title: 'Fragrance 2',
                                                slotNumber: '02',
                                                icon: Icons.spa,
                                                levelPercent: lavenderLevel,
                                                fillPercent: lavenderLevel,
                                                isEnabled: lavenderEnabled,
                                                onToggle:
                                                    _toggleLavenderEnabled,
                                                accentColor: accent,
                                                textColor: theme.textColor,
                                                panelColor: panelColor,
                                                panelDarkColor: panelDarkColor,
                                              ),
                                              SizedBox(height: 28.h),
                                              SpeedControlCard(
                                                speedLevel: lavenderSpeed,
                                                onIncrease:
                                                    _increaseLavenderSpeed,
                                                onDecrease:
                                                    _decreaseLavenderSpeed,
                                                accentColor: accent,
                                                textColor: theme.textColor,
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(width: 40.w),
                                MainControlPanel(
                                  isPowerOn: mainPower,
                                  isAutoMode: autoMode,
                                  selectedAutoInterval: selectedAutoInterval,
                                  onTogglePower: _toggleMainPower,
                                  onToggleAuto: _toggleAutoMode,
                                  onSelectAutoInterval: _setAutoInterval,
                                  onSave: _showAutoUpdateMessage,
                                  accentColor: accent,
                                  textColor: theme.textColor,
                                  panelColor: panelColor,
                                  surfaceColor: surfaceColor,
                                  surfaceTextColor: surfaceTextColor,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (isUpdating)
                  Positioned(
                    top: 120.h,
                    right: 24.w,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 14.w,
                        vertical: 8.h,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        border: Border.all(color: accent.withValues(alpha: 0.4)),
                        borderRadius: BorderRadius.circular(20.r),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 14.w,
                            height: 14.w,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.w,
                              color: accent,
                            ),
                          ),
                          SizedBox(width: 10.w),
                          Text(
                            'Updating...',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12.sp,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            );
          },
        );
      },
    );
  }
}
