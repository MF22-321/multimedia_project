import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../controller/fragrance_controller.dart';
import '../widget/fragrance_card.dart';
import '../widget/system_control_panel.dart';

class FragranceControlPage extends StatefulWidget {
  const FragranceControlPage({
    this.connectOnStart = true,
    super.key,
  });

  final bool connectOnStart;

  @override
  State<FragranceControlPage> createState() => _FragranceControlPageState();
}

class _FragranceControlPageState extends State<FragranceControlPage> {
  late final FragranceController _controller;

  @override
  void initState() {
    super.initState();
    _controller = FragranceController();
    if (widget.connectOnStart) {
      unawaited(_controller.initialize());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/fragrance_background.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: ColoredBox(
          color: Color(0xBDF5F6F8),
          child: SafeArea(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final state = _controller.state;

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 720;
                    final isCompact = constraints.maxHeight < 760;
                    final horizontalPadding = isWide ? 32.0 : 20.0;
                    final verticalPadding = isCompact ? 14.0 : 24.0;
                    final sectionGap = isCompact ? 10.0 : 14.0;
                    final minimumContentHeight =
                        (constraints.maxHeight - (verticalPadding * 2))
                            .clamp(0.0, double.infinity);

                    return SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding,
                        verticalPadding,
                        horizontalPadding,
                        verticalPadding,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 980),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: minimumContentHeight,
                            ),
                            child: IntrinsicHeight(
                              child: Column(
                                children: [
                                  const _Header(),
                                  SizedBox(height: isCompact ? 10 : 14),
                                  _ConnectionStatus(
                                    status: _controller.connectionStatus,
                                    syncStatus: _controller.syncStatus,
                                  ),
                                  const Spacer(),
                                  SizedBox(height: isCompact ? 12 : 18),
                                  SystemControlPanel(
                                    state: state,
                                    syncStatus: _controller.syncStatus,
                                    onPowerChanged: _controller.toggleMainPower,
                                    onAutoChanged: _controller.toggleAutoMode,
                                    onIntervalChanged:
                                        _controller.setAutoInterval,
                                    onSave: _retryChanges,
                                  ),
                                  const Spacer(),
                                  SizedBox(height: sectionGap),
                                  if (isWide)
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: _cartridgeOneCard(
                                            state.coffeeEnabled,
                                            state.coffeeSpeed,
                                          ),
                                        ),
                                        SizedBox(width: sectionGap),
                                        Expanded(
                                          child: _cartridgeTwoCard(
                                            state.lavenderEnabled,
                                            state.lavenderSpeed,
                                          ),
                                        ),
                                      ],
                                    )
                                  else ...[
                                    _cartridgeOneCard(
                                      state.coffeeEnabled,
                                      state.coffeeSpeed,
                                    ),
                                    SizedBox(height: sectionGap),
                                    _cartridgeTwoCard(
                                      state.lavenderEnabled,
                                      state.lavenderSpeed,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _cartridgeOneCard(bool enabled, int speed) {
    return FragranceCard(
      name: 'Cartridge 1',
      icon: Icons.air_rounded,
      accent: AppColors.amber,
      enabled: enabled,
      speed: speed,
      onToggle: _controller.toggleCoffee,
      onSpeedChanged: _controller.setCoffeeSpeed,
    );
  }

  Widget _cartridgeTwoCard(bool enabled, int speed) {
    return FragranceCard(
      name: 'Cartridge 2',
      icon: Icons.air_rounded,
      accent: AppColors.lavender,
      enabled: enabled,
      speed: speed,
      onToggle: _controller.toggleLavender,
      onSpeedChanged: _controller.setLavenderSpeed,
    );
  }

  Future<void> _retryChanges() async {
    final published = await _controller.applyChanges();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(published ? 'Command sent' : 'Connection failed'),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final contentWidth = (screenSize.width - 40).clamp(280.0, 980.0);
    final logoByWidth = contentWidth * 0.14;
    final logoByHeight = screenSize.height * 0.06;
    final titleByWidth = contentWidth * 0.075;
    final titleByHeight = screenSize.height * 0.032;
    final logoSize = (logoByWidth < logoByHeight ? logoByWidth : logoByHeight)
        .clamp(42.0, 60.0);
    final titleSize =
        (titleByWidth < titleByHeight ? titleByWidth : titleByHeight)
            .clamp(23.0, 31.0);

    return Column(
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            'TOYOTA',
            textScaler: TextScaler.noScaling,
            style: TextStyle(
              color: AppColors.toyotaRed,
              fontSize: logoSize,
              fontWeight: FontWeight.w900,
              letterSpacing: 3.4,
              height: 0.95,
            ),
          ),
        ),
        SizedBox(height: screenSize.height < 760 ? 9 : 12),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            'In-Car Smart Fragrance',
            textAlign: TextAlign.center,
            textScaler: TextScaler.noScaling,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: titleSize,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.3,
              height: 1.05,
            ),
          ),
        ),
        SizedBox(height: screenSize.height < 760 ? 7 : 9),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.textPrimary,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text(
            'PROTOTYPE',
            style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _ConnectionStatus extends StatelessWidget {
  const _ConnectionStatus({
    required this.status,
    required this.syncStatus,
  });

  final FragranceConnectionStatus status;
  final FragranceSyncStatus syncStatus;

  @override
  Widget build(BuildContext context) {
    final presentation = _presentation();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
      decoration: BoxDecoration(
        color: presentation.color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: presentation.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            presentation.label,
            style: TextStyle(
              color: presentation.color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  ({String label, Color color}) _presentation() {
    if (status == FragranceConnectionStatus.deviceOnline) {
      return switch (syncStatus) {
        FragranceSyncStatus.sending => (
            label: 'Sending',
            color: AppColors.amber,
          ),
        FragranceSyncStatus.failed => (
            label: 'Retry',
            color: AppColors.danger,
          ),
        _ => (
            label: 'Connected',
            color: AppColors.green,
          ),
      };
    }

    return switch (status) {
      FragranceConnectionStatus.connecting => (
          label: 'Connecting',
          color: AppColors.amber,
        ),
      FragranceConnectionStatus.disconnected => (
          label: 'Offline',
          color: AppColors.danger,
        ),
      FragranceConnectionStatus.waitingForDevice => (
          label: 'Waiting',
          color: AppColors.cyan,
        ),
      FragranceConnectionStatus.deviceOffline => (
          label: 'Device offline',
          color: AppColors.danger,
        ),
      FragranceConnectionStatus.deviceOnline => throw StateError('Handled'),
    };
  }
}
