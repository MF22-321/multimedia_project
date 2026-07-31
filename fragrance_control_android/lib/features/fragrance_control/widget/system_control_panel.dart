import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../controller/fragrance_controller.dart';
import '../model/fragrance_state.dart';

class SystemControlPanel extends StatelessWidget {
  const SystemControlPanel({
    required this.state,
    required this.syncStatus,
    required this.onPowerChanged,
    required this.onAutoChanged,
    required this.onIntervalChanged,
    required this.onSave,
    super.key,
  });

  final FragranceState state;
  final FragranceSyncStatus syncStatus;
  final VoidCallback onPowerChanged;
  final VoidCallback onAutoChanged;
  final ValueChanged<AutoInterval> onIntervalChanged;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A1D21).withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PowerButton(
            value: state.mainPower,
            onTap: onPowerChanged,
          ),
          const Divider(height: 28, color: AppColors.border),
          _ControlRow(
            icon: Icons.autorenew_rounded,
            iconColor: AppColors.cyan,
            title: 'Auto',
            value: state.autoMode,
            enabled: state.mainPower,
            onTap: onAutoChanged,
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            child: state.autoMode && state.mainPower
                ? Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<AutoInterval>(
                        segments: AutoInterval.values
                            .map(
                              (interval) => ButtonSegment(
                                value: interval,
                                label: Text(interval.mqttValue),
                              ),
                            )
                            .toList(),
                        selected: {state.autoInterval},
                        showSelectedIcon: false,
                        onSelectionChanged: (selection) {
                          onIntervalChanged(selection.first);
                        },
                        style: ButtonStyle(
                          visualDensity: VisualDensity.comfortable,
                          side: WidgetStateProperty.all(
                            const BorderSide(color: AppColors.border),
                          ),
                        ),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          if (syncStatus == FragranceSyncStatus.sending) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(
              minHeight: 3,
              borderRadius: BorderRadius.all(Radius.circular(4)),
              color: AppColors.toyotaRed,
              backgroundColor: AppColors.surfaceRaised,
            ),
          ],
          if (syncStatus == FragranceSyncStatus.failed) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onSave,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  side: const BorderSide(color: AppColors.danger),
                  minimumSize: const Size.fromHeight(46),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PowerButton extends StatelessWidget {
  const _PowerButton({
    required this.value,
    required this.onTap,
  });

  final bool value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          width: double.infinity,
          height: 58,
          decoration: BoxDecoration(
            color: value ? AppColors.toyotaRed : AppColors.surfaceRaised,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: value ? AppColors.toyotaRed : AppColors.border,
            ),
            boxShadow: value
                ? [
                    BoxShadow(
                      color: AppColors.toyotaRed.withValues(alpha: 0.2),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.power_settings_new_rounded,
                color: value ? Colors.white : AppColors.textPrimary,
              ),
              const SizedBox(width: 10),
              Text(
                value ? 'POWER ON' : 'POWER OFF',
                style: TextStyle(
                  color: value ? Colors.white : AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ControlRow extends StatelessWidget {
  const _ControlRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final bool value;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.38,
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Switch.adaptive(
            value: value,
            activeTrackColor: AppColors.toyotaRed,
            onChanged: enabled ? (_) => onTap() : null,
          ),
        ],
      ),
    );
  }
}
