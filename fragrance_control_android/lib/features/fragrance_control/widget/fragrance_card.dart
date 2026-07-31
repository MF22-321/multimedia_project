import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class FragranceCard extends StatelessWidget {
  const FragranceCard({
    required this.name,
    required this.icon,
    required this.accent,
    required this.enabled,
    required this.speed,
    required this.onToggle,
    required this.onSpeedChanged,
    super.key,
  });

  final String name;
  final IconData icon;
  final Color accent;
  final bool enabled;
  final int speed;
  final VoidCallback onToggle;
  final ValueChanged<int> onSpeedChanged;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: enabled ? accent.withValues(alpha: 0.7) : AppColors.border,
          width: enabled ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A1D21).withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: enabled ? 0.13 : 0.07),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  icon,
                  color: enabled ? accent : AppColors.textSecondary,
                  size: 25,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  name,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Switch.adaptive(
                value: enabled,
                activeTrackColor: accent,
                onChanged: (_) => onToggle(),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _SpeedSelector(
            value: speed,
            accent: accent,
            enabled: enabled,
            onChanged: onSpeedChanged,
          ),
        ],
      ),
    );
  }
}

class _SpeedSelector extends StatelessWidget {
  const _SpeedSelector({
    required this.value,
    required this.accent,
    required this.enabled,
    required this.onChanged,
  });

  final int value;
  final Color accent;
  final bool enabled;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final canDecrease = enabled && value > 1;
    final canIncrease = enabled && value < 3;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: enabled ? 1 : 0.42,
      child: Container(
        height: 66,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: AppColors.surfaceRaised,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Semantics(
                label: 'Fragrance intensity level $value of 3',
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    const SizedBox(width: 4),
                    Flexible(
                      child: _IntensityMeter(
                        value: value,
                        enabled: enabled,
                        accent: accent,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '$value',
                      style: TextStyle(
                        color: enabled ? accent : AppColors.textSecondary,
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _LevelButton(
              icon: Icons.remove_rounded,
              tooltip: 'Decrease level',
              enabled: canDecrease,
              accent: accent,
              onTap: () => onChanged(value - 1),
            ),
            const SizedBox(width: 6),
            _LevelButton(
              icon: Icons.add_rounded,
              tooltip: 'Increase level',
              enabled: canIncrease,
              accent: accent,
              onTap: () => onChanged(value + 1),
            ),
          ],
        ),
      ),
    );
  }
}

class _IntensityMeter extends StatelessWidget {
  const _IntensityMeter({
    required this.value,
    required this.enabled,
    required this.accent,
  });

  final int value;
  final bool enabled;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final progress = enabled ? value / 3 : 0.0;

    return Container(
      constraints: const BoxConstraints(maxWidth: 92),
      height: 30,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: enabled
              ? accent.withValues(alpha: 0.55)
              : AppColors.textSecondary.withValues(alpha: 0.28),
          width: 1.5,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(end: progress),
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeOutCubic,
                  builder: (context, animatedProgress, _) {
                    return Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: animatedProgress,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                accent.withValues(alpha: 0.72),
                                accent,
                              ],
                            ),
                          ),
                          child: const SizedBox.expand(),
                        ),
                      ),
                    );
                  },
                ),
              ),
              for (var index = 1; index < 3; index++)
                Positioned(
                  left: (constraints.maxWidth * index / 3) - 0.75,
                  top: 3,
                  bottom: 3,
                  child: Container(
                    width: 1.5,
                    color: AppColors.surface.withValues(alpha: 0.82),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _LevelButton extends StatelessWidget {
  const _LevelButton({
    required this.icon,
    required this.tooltip,
    required this.enabled,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final bool enabled;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: enabled ? onTap : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: enabled ? AppColors.surface : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: enabled
                    ? accent.withValues(alpha: 0.18)
                    : Colors.transparent,
              ),
              boxShadow: enabled
                  ? [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              icon,
              color: enabled
                  ? accent
                  : AppColors.textSecondary.withValues(alpha: 0.35),
              size: 27,
            ),
          ),
        ),
      ),
    );
  }
}
