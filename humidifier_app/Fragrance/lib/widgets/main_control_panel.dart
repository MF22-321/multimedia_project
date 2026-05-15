import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../models/auto_interval_option.dart';

class MainControlPanel extends StatelessWidget {
  final bool isPowerOn;
  final bool isAutoMode;
  final AutoIntervalOption selectedAutoInterval;
  final VoidCallback onTogglePower;
  final VoidCallback onToggleAuto;
  final ValueChanged<AutoIntervalOption> onSelectAutoInterval;
  final VoidCallback onSave;

  const MainControlPanel({
    super.key,
    required this.isPowerOn,
    required this.isAutoMode,
    required this.selectedAutoInterval,
    required this.onTogglePower,
    required this.onToggleAuto,
    required this.onSelectAutoInterval,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 320,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 22),
          decoration: BoxDecoration(
            color: AppColors.panel,
            border: Border.all(color: AppColors.border, width: 2),
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            children: [
              GestureDetector(
                onTap: onTogglePower,
                child: Container(
                  width: double.infinity,
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppColors.whiteSoft,
                    borderRadius: BorderRadius.circular(42),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.power_settings_new,
                      size: 72,
                      color: isPowerOn ? AppColors.green : Colors.black,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              GestureDetector(
                onTap: onToggleAuto,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: double.infinity,
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppColors.whiteSoft,
                    borderRadius: BorderRadius.circular(42),
                    border: Border.all(
                      color: isAutoMode
                          ? const Color(0xFF1E73F1)
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      'Auto',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        color: isAutoMode
                            ? AppColors.textDark
                            : AppColors.textDark.withOpacity(0.8),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              _AutoIntervalSegment(
                selected: selectedAutoInterval,
                onSelected: onSelectAutoInterval,
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: 320,
          height: 56,
          child: ElevatedButton(
            onPressed: onSave,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.panel,
              foregroundColor: AppColors.textDark,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
                side: const BorderSide(color: Color(0xFFB0B0B0)),
              ),
            ),
            child: const Text(
              'Save',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AutoIntervalSegment extends StatelessWidget {
  final AutoIntervalOption selected;
  final ValueChanged<AutoIntervalOption> onSelected;

  const _AutoIntervalSegment({
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.whiteSoft,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFFBDBDBD)),
      ),
      child: Row(
        children: [
          _SegmentItem(
            label: '10s',
            isSelected: selected == AutoIntervalOption.s10,
            onTap: () => onSelected(AutoIntervalOption.s10),
          ),
          _SegmentItem(
            label: '1m',
            isSelected: selected == AutoIntervalOption.m1,
            onTap: () => onSelected(AutoIntervalOption.m1),
          ),
          _SegmentItem(
            label: '5m',
            isSelected: selected == AutoIntervalOption.m5,
            onTap: () => onSelected(AutoIntervalOption.m5),
          ),
        ],
      ),
    );
  }
}

class _SegmentItem extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SegmentItem({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF1E73F1) : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.textDark,
              ),
            ),
          ),
        ),
      ),
    );
  }
}