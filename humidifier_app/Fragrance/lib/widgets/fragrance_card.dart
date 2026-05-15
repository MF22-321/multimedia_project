import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class FragranceCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final int levelPercent;
  final int fillPercent;
  final bool isEnabled;
  final VoidCallback onToggle;

  const FragranceCard({
    super.key,
    required this.title,
    required this.icon,
    required this.levelPercent,
    required this.fillPercent,
    required this.isEnabled,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final int safeLevel = levelPercent.clamp(0, 100);

    return Container(
      width: 340,
      height: 370,
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(40),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(40),
        child: Stack(
          children: [
            Positioned(
              left: 10,
              top: 18,
              bottom: 18,
              child: _LeftLevelIndicator(levelPercent: safeLevel),
            ),

            Positioned(
              left: 84,
              top: 0,
              right: 0,
              bottom: 0,
              child: Container(
                decoration: const BoxDecoration(
                  color: AppColors.panelDark,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(54),
                    topRight: Radius.circular(40),
                    bottomRight: Radius.circular(40),
                    bottomLeft: Radius.zero,
                  ),
                ),
              ),
            ),

            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.only(
                  left: 106,
                  right: 24,
                  top: 22,
                  bottom: 18,
                ),
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.topLeft,
                      child: Icon(
                        Icons.water_drop_outlined,
                        size: 28,
                        color: Colors.white.withOpacity(0.95),
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      icon,
                      size: 62,
                      color: const Color(0xFFC28A63),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.textLight,
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 34),
                    Transform.scale(
                      scale: 1.18,
                      child: Switch(
                        value: isEnabled,
                        onChanged: (_) => onToggle(),
                        activeColor: AppColors.whiteSoft,
                        activeTrackColor: AppColors.green,
                        inactiveThumbColor: AppColors.whiteSoft,
                        inactiveTrackColor: Colors.white24,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LeftLevelIndicator extends StatelessWidget {
  final int levelPercent;

  const _LeftLevelIndicator({
    required this.levelPercent,
  });

  @override
  Widget build(BuildContext context) {
    final double level = levelPercent.clamp(0, 100) / 100.0;

    return SizedBox(
      width: 66,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const double topLabelArea = 30;
          const double bottomLabelArea = 34;
          const double railTop = 54;
          const double railBottom = 54;

          final double railHeight =
              constraints.maxHeight - railTop - railBottom;
          final double bubbleTop =
              railTop + ((railHeight - 64) * (1 - level)).clamp(0.0, railHeight - 64);

          return Stack(
            clipBehavior: Clip.none,
            children: [
              const Positioned(
                left: 25,
                top: 0,
                child: Text(
                  'F',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF403B3B),
                  ),
                ),
              ),

              Positioned(
                left: 27,
                top: railTop,
                bottom: railBottom,
                child: Container(
                  width: 10,
                  decoration: BoxDecoration(
                    color: const Color(0xFF403B3B),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),

              Positioned(
                left: 0,
                top: bubbleTop,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeInOut,
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF403B3B),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      '$levelPercent%',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF403B3B),
                      ),
                    ),
                  ),
                ),
              ),

              Positioned(
                left: 25,
                bottom: 0,
                child: const Text(
                  'E',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF403B3B),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}