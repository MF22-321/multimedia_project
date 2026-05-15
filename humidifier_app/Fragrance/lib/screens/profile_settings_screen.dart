import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'home_screen.dart';

class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  final DatabaseReference _deviceRef =
      FirebaseDatabase.instance.ref('device');

  StreamSubscription<DatabaseEvent>? _deviceSub;
  Timer? _coffeeTimer;

  int selectedCartridge = 0;
  bool drowsinessEnabled = true;
  bool drowsinessPopupVisible = false;
  String drowsinessStatus = 'idle';

  bool isLoading = true;
  bool isUpdating = false;
  bool _dialogShowing = false;

  @override
  void initState() {
    super.initState();
    _listenDevice();
  }

  void _listenDevice() {
    _deviceSub = _deviceRef.onValue.listen((event) {
      final raw = event.snapshot.value;

      if (raw == null || raw is! Map) {
        if (!mounted) return;
        setState(() {
          selectedCartridge = 0;
          drowsinessEnabled = true;
          drowsinessPopupVisible = false;
          drowsinessStatus = 'idle';
          isLoading = false;
        });
        return;
      }

      final data = Map<String, dynamic>.from(raw);
      final drowsiness = data['drowsiness'] is Map
          ? Map<String, dynamic>.from(data['drowsiness'] as Map)
          : <String, dynamic>{};

      if (!mounted) return;

      setState(() {
        selectedCartridge = ((data['selectedCartridge'] ?? 0) as num).toInt();
        drowsinessEnabled = (drowsiness['enabled'] ?? true) as bool;
        drowsinessPopupVisible =
            (drowsiness['popupVisible'] ?? false) as bool;
        drowsinessStatus = (drowsiness['status'] ?? 'idle') as String;
        isLoading = false;
      });

      if (drowsinessPopupVisible && !_dialogShowing && drowsinessEnabled) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _showDrowsinessDialog();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _deviceSub?.cancel();
    _coffeeTimer?.cancel();
    super.dispose();
  }

  Future<void> _setAllFragranceOff() async {
    await _deviceRef.update({
      'selectedCartridge': 0,
      'mainPower': false,
      'autoMode': false,
      'motor1/enabled': false,
      'motor1/speedLevel': 1,
      'motor2/enabled': false,
      'motor2/speedLevel': 1,
    });
  }

  Future<void> _toggleShortcutCartridge(int cartridge) async {
    setState(() => isUpdating = true);

    try {
      if (selectedCartridge == cartridge) {
        await _setAllFragranceOff();
      } else if (cartridge == 1) {
        await _deviceRef.update({
          'selectedCartridge': 1,
          'mainPower': true,
          'autoMode': false,
          'motor1/enabled': true,
          'motor1/speedLevel': 3,
          'motor2/enabled': false,
          'motor2/speedLevel': 1,
        });
      } else if (cartridge == 2) {
        await _deviceRef.update({
          'selectedCartridge': 2,
          'mainPower': true,
          'autoMode': false,
          'motor1/enabled': false,
          'motor1/speedLevel': 1,
          'motor2/enabled': true,
          'motor2/speedLevel': 3,
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update shortcut: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() => isUpdating = false);
    }
  }

  Future<void> _triggerDummyDrowsinessEvent() async {
    if (!drowsinessEnabled) return;

    final eventId = DateTime.now().millisecondsSinceEpoch;

    await _deviceRef.update({
      'drowsiness/popupVisible': true,
      'drowsiness/status': 'pending',
      'drowsiness/eventId': eventId,
      'drowsiness/triggeredAt': eventId,
    });
  }

  Future<void> _acceptDrowsinessEvent() async {
    final acceptedAt = DateTime.now().millisecondsSinceEpoch;

    await _deviceRef.update({
      'drowsiness/popupVisible': false,
      'drowsiness/status': 'accepted',
      'selectedCartridge': 1,
      'mainPower': true,
      'autoMode': false,
      'motor1/enabled': true,
      'motor1/speedLevel': 3,
      'motor2/enabled': false,
      'motor2/speedLevel': 1,
    });

    _coffeeTimer?.cancel();
    _coffeeTimer = Timer(const Duration(minutes: 1), () async {
      await _deviceRef.update({
        'drowsiness/status': 'completed',
      });
      await _setAllFragranceOff();
    });
  }

  Future<void> _dismissDrowsinessEvent() async {
    await _deviceRef.update({
      'drowsiness/popupVisible': false,
      'drowsiness/status': 'dismissed',
    });
  }

  Future<void> _toggleDrowsinessFeature() async {
    final newValue = !drowsinessEnabled;
    await _deviceRef.update({
      'drowsiness/enabled': newValue,
      'drowsiness/popupVisible': false,
      'drowsiness/status': newValue ? 'idle' : 'disabled',
    });
  }

  void _showDrowsinessDialog() {
    _dialogShowing = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 16,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                colors: [
                  Colors.black.withOpacity(0.75),
                  Colors.black.withOpacity(0.60),
                ],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Hati-hati Anda sedang mengantuk!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 18),
                const Icon(
                  Icons.sentiment_dissatisfied,
                  size: 110,
                  color: Colors.white,
                ),
                const SizedBox(height: 22),
                const Text(
                  'Mau mengaktifkan Smart Fragrance untuk mengurangi kantuk Anda?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 26),
                Row(
                  children: [
                    Expanded(
                      child: _DialogActionButton(
                        label: 'YA',
                        backgroundColor: const Color(0xFFC90000),
                        onTap: () async {
                          Navigator.of(context).pop();
                          _dialogShowing = false;
                          await _acceptDrowsinessEvent();
                        },
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _DialogActionButton(
                        label: 'TIDAK',
                        backgroundColor: const Color(0xFFBDBDBD),
                        textColor: Colors.white,
                        onTap: () async {
                          Navigator.of(context).pop();
                          _dialogShowing = false;
                          await _dismissDrowsinessEvent();
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: _DialogActionButton(
                    label: 'Nonaktifkan Drowsiness Detection',
                    backgroundColor: const Color(0xFF6D6D6D),
                    textColor: Colors.white,
                    onTap: () async {
                      Navigator.of(context).pop();
                      _dialogShowing = false;
                      await _toggleDrowsinessFeature();
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ).then((_) {
      _dialogShowing = false;
    });
  }

  void _openCustomSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const HomeScreen(),
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
                Row(
                  children: [
                    Expanded(
                      flex: 5,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(36, 44, 28, 36),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Profile',
                              style: TextStyle(
                                color: AppColors.textLight,
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Container(
                              height: 2,
                              width: double.infinity,
                              color: Colors.white70,
                            ),
                            const Spacer(),
                            const Text(
                              'Hello,',
                              style: TextStyle(
                                color: AppColors.textLight,
                                fontSize: 34,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Raihan',
                              style: TextStyle(
                                color: AppColors.textLight,
                                fontSize: 68,
                                fontWeight: FontWeight.w700,
                                height: 0.95,
                              ),
                            ),
                            const SizedBox(height: 18),
                            Row(
                              children: const [
                                Text(
                                  'Personalized your settings',
                                  style: TextStyle(
                                    color: AppColors.textLight,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(width: 10),
                                Icon(
                                  Icons.arrow_forward,
                                  color: AppColors.textLight,
                                ),
                              ],
                            ),
                            const SizedBox(height: 40),
                            SizedBox(
                              width: 220,
                              height: 58,
                              child: ElevatedButton(
                                onPressed: _openCustomSettings,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.whiteSoft,
                                  foregroundColor: AppColors.textDark,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(28),
                                  ),
                                ),
                                child: const Text(
                                  'Save Settings',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                            const Spacer(),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      width: 2,
                      color: Colors.white70,
                    ),
                    Expanded(
                      flex: 6,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 44, 36, 36),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Profile Settings',
                              style: TextStyle(
                                color: AppColors.textLight,
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Container(
                              height: 2,
                              width: double.infinity,
                              color: Colors.white70,
                            ),
                            const SizedBox(height: 28),
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: AppColors.background.withOpacity(0.25),
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Expanded(
                                    child: Text(
                                      'Smart Fragrance\nControl',
                                      style: TextStyle(
                                        color: AppColors.textLight,
                                        fontSize: 22,
                                        fontWeight: FontWeight.w700,
                                        height: 1.3,
                                      ),
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      const Text(
                                        'Select\nCartridge',
                                        textAlign: TextAlign.right,
                                        style: TextStyle(
                                          color: AppColors.textLight,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          _CartridgeButton(
                                            label: '1',
                                            isSelected: selectedCartridge == 1,
                                            onTap: () =>
                                                _toggleShortcutCartridge(1),
                                          ),
                                          const SizedBox(width: 18),
                                          _CartridgeButton(
                                            label: '2',
                                            isSelected: selectedCartridge == 2,
                                            onTap: () =>
                                                _toggleShortcutCartridge(2),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 18),
                                      SizedBox(
                                        width: 220,
                                        height: 42,
                                        child: ElevatedButton(
                                          onPressed: _openCustomSettings,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors.whiteSoft,
                                            foregroundColor: AppColors.textDark,
                                            elevation: 0,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(24),
                                            ),
                                          ),
                                          child: const Text(
                                            'Custom Settings',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: AppColors.background.withOpacity(0.25),
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      drowsinessEnabled
                                          ? 'Drowsiness Detection: ON'
                                          : 'Drowsiness Detection: OFF',
                                      style: const TextStyle(
                                        color: AppColors.textLight,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  SizedBox(
                                    width: 180,
                                    height: 46,
                                    child: ElevatedButton(
                                      onPressed: _triggerDummyDrowsinessEvent,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            const Color(0xFF8E1C1C),
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(24),
                                        ),
                                      ),
                                      child: const Text(
                                        'Trigger Event',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Status: $drowsinessStatus',
                              style: const TextStyle(
                                color: AppColors.textLight,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const Spacer(),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                if (isUpdating)
                  Positioned(
                    top: 24,
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

class _CartridgeButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _CartridgeButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: AppColors.whiteSoft,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? const Color(0xFF4A90E2) : Colors.white30,
            width: isSelected ? 3 : 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF4A90E2).withOpacity(0.20),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.textDark,
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _DialogActionButton extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color textColor;
  final VoidCallback onTap;

  const _DialogActionButton({
    required this.label,
    required this.backgroundColor,
    this.textColor = Colors.white,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 62,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: textColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}