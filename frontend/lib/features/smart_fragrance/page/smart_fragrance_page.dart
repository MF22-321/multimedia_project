import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:frontend/core/model/auto_interval_option.dart';
import 'package:frontend/core/services/mqtt_service.dart';
import 'package:frontend/core/themes/app_colors.dart';
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

  bool coffeeEnabled = true;
  bool lavenderEnabled = false;

  int coffeeLevel = 75;
  int lavenderLevel = 50;

  int coffeeSpeed = 1;
  int lavenderSpeed = 1;

  bool mainPower = true;
  bool autoMode = false;
  AutoIntervalOption selectedAutoInterval = AutoIntervalOption.s10;

  bool isLoading = true;
  bool isUpdating = false;

  @override
  void initState() {
    super.initState();
    _initMQTT();
  }

  Future<void> _initMQTT() async {
    await mqtt.connect();

    if (mounted) {
      setState(() => isLoading = false);
    }

    mqtt.stream.listen((data) {
      if (!mounted) return;

      setState(() {
        mainPower = data['mainPower'] ?? mainPower;
        autoMode = data['autoMode'] ?? autoMode;

        coffeeEnabled = data['motor1']?['enabled'] ?? coffeeEnabled;
        coffeeSpeed = (data['motor1']?['speedLevel'] ?? coffeeSpeed).clamp(
          1,
          3,
        );

        lavenderEnabled = data['motor2']?['enabled'] ?? lavenderEnabled;
        lavenderSpeed = (data['motor2']?['speedLevel'] ?? lavenderSpeed).clamp(
          1,
          3,
        );
      });
    });
  }

  void _publish(Map<String, dynamic> data) {
    setState(() => isUpdating = true);

    mqtt.publish('humidifier/control', data);

    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => isUpdating = false);
    });
  }

  Future<void> _toggleMainPower() async {
    final newValue = !mainPower;
    setState(() => mainPower = newValue);
    _publish({'mainPower': newValue});
  }

  Future<void> _toggleAutoMode() async {
    final newValue = !autoMode;
    setState(() => autoMode = newValue);

    _publish({
      'autoMode': newValue,
      'autoInterval': selectedAutoInterval.firebaseValue,
    });
  }

  Future<void> _setAutoInterval(AutoIntervalOption option) async {
    setState(() => selectedAutoInterval = option);
    _publish({'autoInterval': option.firebaseValue});
  }

  Future<void> _toggleCoffeeEnabled() async {
    final newValue = !coffeeEnabled;
    setState(() => coffeeEnabled = newValue);
    _publish({
      'motor1': {'enabled': newValue},
    });
  }

  Future<void> _increaseCoffeeSpeed() async {
    if (coffeeSpeed >= 3) return;
    final newValue = coffeeSpeed + 1;
    setState(() => coffeeSpeed = newValue);
    _publish({
      'motor1': {'speedLevel': newValue},
    });
  }

  Future<void> _decreaseCoffeeSpeed() async {
    if (coffeeSpeed <= 1) return;
    final newValue = coffeeSpeed - 1;
    setState(() => coffeeSpeed = newValue);
    _publish({
      'motor1': {'speedLevel': newValue},
    });
  }

  Future<void> _toggleLavenderEnabled() async {
    final newValue = !lavenderEnabled;
    setState(() => lavenderEnabled = newValue);
    _publish({
      'motor2': {'enabled': newValue},
    });
  }

  Future<void> _increaseLavenderSpeed() async {
    if (lavenderSpeed >= 3) return;
    final newValue = lavenderSpeed + 1;
    setState(() => lavenderSpeed = newValue);
    _publish({
      'motor2': {'speedLevel': newValue},
    });
  }

  Future<void> _decreaseLavenderSpeed() async {
    if (lavenderSpeed <= 1) return;
    final newValue = lavenderSpeed - 1;
    setState(() => lavenderSpeed = newValue);
    _publish({
      'motor2': {'speedLevel': newValue},
    });
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
    mqtt.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: isLoading
          ? Center(child: CircularProgressIndicator(strokeWidth: 2.w))
          : Stack(
              children: [
                Column(
                  children: [
                    Container(
                      height: 110.h,
                      width: double.infinity,
                      color: AppColors.topBar,
                      alignment: Alignment.centerLeft,
                      padding: EdgeInsets.symmetric(horizontal: 44.w),
                      child: Row(
                        children: [
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
                          SizedBox(width: 350.w),
                          Text(
                            "Smart Fragrance Control",
                            style: TextStyle(
                              fontSize: 32.sp,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
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
                                                title: 'Coffee',
                                                icon: Icons.coffee,
                                                levelPercent: coffeeLevel,
                                                fillPercent: coffeeLevel,
                                                isEnabled: coffeeEnabled,
                                                onToggle: _toggleCoffeeEnabled,
                                              ),
                                              SizedBox(height: 28.h),
                                              SpeedControlCard(
                                                speedLevel: coffeeSpeed,
                                                onIncrease:
                                                    _increaseCoffeeSpeed,
                                                onDecrease:
                                                    _decreaseCoffeeSpeed,
                                              ),
                                            ],
                                          ),
                                          Column(
                                            children: [
                                              FragranceCard(
                                                title: 'Lavender',
                                                icon: Icons.local_florist,
                                                levelPercent: lavenderLevel,
                                                fillPercent: lavenderLevel,
                                                isEnabled: lavenderEnabled,
                                                onToggle:
                                                    _toggleLavenderEnabled,
                                              ),
                                              SizedBox(height: 28.h),
                                              SpeedControlCard(
                                                speedLevel: lavenderSpeed,
                                                onIncrease:
                                                    _increaseLavenderSpeed,
                                                onDecrease:
                                                    _decreaseLavenderSpeed,
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
                              color: Colors.white,
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
  }
}
