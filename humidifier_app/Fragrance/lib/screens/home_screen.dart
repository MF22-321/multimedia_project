import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import '../models/auto_interval_option.dart';
import '../theme/app_colors.dart';
import '../widgets/fragrance_card.dart';
import '../widgets/main_control_panel.dart';
import '../widgets/speed_control_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DatabaseReference _deviceRef =
      FirebaseDatabase.instance.ref('device');

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
    _loadFromFirebase();
  }

  Future<void> _loadFromFirebase() async {
    try {
      final snapshot = await _deviceRef.get();

      if (!snapshot.exists) {
        if (!mounted) return;
        setState(() => isLoading = false);
        return;
      }

      final raw = snapshot.value;
      if (raw is! Map) {
        if (!mounted) return;
        setState(() => isLoading = false);
        return;
      }

      final data = Map<String, dynamic>.from(raw);

      final motor1 = data['motor1'] is Map
          ? Map<String, dynamic>.from(data['motor1'] as Map)
          : <String, dynamic>{};

      final motor2 = data['motor2'] is Map
          ? Map<String, dynamic>.from(data['motor2'] as Map)
          : <String, dynamic>{};

      if (!mounted) return;

      setState(() {
        mainPower = (data['mainPower'] ?? true) as bool;
        autoMode = (data['autoMode'] ?? false) as bool;
        selectedAutoInterval =
            AutoIntervalOptionX.fromFirebase(data['autoInterval']);

        coffeeEnabled = (motor1['enabled'] ?? false) as bool;
        coffeeSpeed = ((motor1['speedLevel'] ?? 1) as num)
            .toInt()
            .clamp(1, 3);

        lavenderEnabled = (motor2['enabled'] ?? false) as bool;
        lavenderSpeed = ((motor2['speedLevel'] ?? 1) as num)
            .toInt()
            .clamp(1, 3);

        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load Firebase data: $e')),
      );
    }
  }

  Future<void> _updateFirebase(Map<String, Object?> updates) async {
    try {
      if (!mounted) return;
      setState(() => isUpdating = true);

      if (updates.isNotEmpty) {
        await _deviceRef.update(updates);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update Firebase: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() => isUpdating = false);
    }
  }

  Future<void> _toggleMainPower() async {
  final newValue = !mainPower;
  setState(() => mainPower = newValue);
  await _updateFirebase({
    'mainPower': newValue,
    'selectedCartridge': 0,
  });
}

  Future<void> _toggleAutoMode() async {
  final newValue = !autoMode;
  setState(() => autoMode = newValue);

  await _updateFirebase({
    'autoMode': newValue,
    'autoInterval': selectedAutoInterval.firebaseValue,
    'selectedCartridge': 0,
  });
}

  Future<void> _setAutoInterval(AutoIntervalOption option) async {
  setState(() => selectedAutoInterval = option);

  await _updateFirebase({
    'autoInterval': option.firebaseValue,
    'selectedCartridge': 0,
  });
}

  Future<void> _toggleCoffeeEnabled() async {
  final newValue = !coffeeEnabled;
  setState(() => coffeeEnabled = newValue);
  await _updateFirebase({
    'motor1/enabled': newValue,
    'selectedCartridge': 0,
  });
}

  Future<void> _increaseCoffeeSpeed() async {
  if (coffeeSpeed >= 3) return;
  final newValue = coffeeSpeed + 1;
  setState(() => coffeeSpeed = newValue);
  await _updateFirebase({
    'motor1/speedLevel': newValue,
    'selectedCartridge': 0,
  });
}

  Future<void> _decreaseCoffeeSpeed() async {
  if (coffeeSpeed <= 1) return;
  final newValue = coffeeSpeed - 1;
  setState(() => coffeeSpeed = newValue);
  await _updateFirebase({
    'motor1/speedLevel': newValue,
    'selectedCartridge': 0,
  });
}

  Future<void> _toggleLavenderEnabled() async {
  final newValue = !lavenderEnabled;
  setState(() => lavenderEnabled = newValue);
  await _updateFirebase({
    'motor2/enabled': newValue,
    'selectedCartridge': 0,
  });
}

  Future<void> _increaseLavenderSpeed() async {
    if (lavenderSpeed >= 3) return;
    final newValue = lavenderSpeed + 1;
    setState(() => lavenderSpeed = newValue);
    await _updateFirebase({
      'motor2/speedLevel': newValue,
      'selectedCartridge': 0,
    });
  }

  Future<void> _decreaseLavenderSpeed() async {
  if (lavenderSpeed <= 1) return;
  final newValue = lavenderSpeed - 1;
  setState(() => lavenderSpeed = newValue);
  await _updateFirebase({
    'motor2/speedLevel': newValue,
    'selectedCartridge': 0,
  });
}

  void _showAutoUpdateMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Auto-update mode active'),
        duration: Duration(milliseconds: 900),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                Column(
                  children: [
                    Container(
                      height: 110,
                      width: double.infinity,
                      color: AppColors.topBar,
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 44),
                      child: const Text(
                        'Smart Fragrance',
                        style: TextStyle(
                          color: AppColors.textLight,
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 36,
                            vertical: 28,
                          ),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1400),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    children: [
                                      Wrap(
                                        spacing: 26,
                                        runSpacing: 26,
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
                                              const SizedBox(height: 28),
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
                                              const SizedBox(height: 28),
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
                                const SizedBox(width: 40),
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
                    top: 120,
                    right: 24,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.65),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Updating...',
                            style: TextStyle(color: Colors.white),
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