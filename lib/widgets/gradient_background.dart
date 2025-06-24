import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

class GradientBackground extends StatelessWidget {
  final Widget child;

  const GradientBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          // colors: [
          //   AppColors.vanilla,
          //   AppColors.icterine,
          //   // AppColors.rose,
          // ],

          //           colors: [
          //   AppColors.vanilla,
          //   AppColors.beige,
          //   AppColors.lavender,
          // ],
          colors: [
            Color(0xFFFFE5D9), // Light Blush
            Color(0xFFFFF6C3), // Vanilla Cream
          ],

          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(child: child),
    );
  }
}
