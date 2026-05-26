import 'dart:async';
import 'package:flutter/material.dart';
import 'package:frontend/core/navigation/app_routes.dart';
import 'package:frontend/features/boot/presentation/widget/dotted_background.dart';
import 'package:frontend/features/boot/presentation/widget/toyota_logo_animation.dart';

class BootPage extends StatefulWidget {
  const BootPage({super.key});

  @override
  State<BootPage> createState() => _BootPageState();
}

class _BootPageState extends State<BootPage> {
  @override
  void initState() {
    super.initState();

    Timer(const Duration(seconds: 6), () {
      if (mounted) {
        Navigator.pushReplacementNamed(context, AppRoutes.warning);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          /// 1️⃣ Gradient Background
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                colors: [Color(0xFF111111), Colors.black],
                radius: 0.8,
                center: Alignment.center,
              ),
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.6),
                  ],
                  radius: 1.0,
                ),
              ),
            ),
          ),
          const Positioned.fill(child: DottedBackground()),
          const Center(child: ToyotaLogoAnimation()),
        ],
      ),
    );
  }
}
