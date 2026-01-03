import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppBackground extends StatelessWidget {
  const AppBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.brandBg,
                  const Color(0xFFE8F0FF),
                  const Color(0xFFF5E6FF),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),
          Positioned(
            top: 120,
            left: -80,
            child: _Blob(
              size: 280,
              colors: [
                const Color(0xFF4A90E2).withOpacity(0.15),
                const Color(0xFF4A90E2).withOpacity(0.0),
              ],
            ),
          ),
          Positioned(
            bottom: 200,
            right: -100,
            child: _Blob(
              size: 320,
              colors: [
                const Color(0xFF9B59B6).withOpacity(0.12),
                const Color(0xFF9B59B6).withOpacity(0.0),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  final double size;
  final List<Color> colors;

  const _Blob({
    required this.size,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: colors,
            stops: const [0, 1],
          ),
        ),
      ),
    );
  }
}
