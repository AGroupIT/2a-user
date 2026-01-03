import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  static const brandOrangeDark = Color(0xFFFE3301);
  static const brandOrange = Color(0xFFFF5E04);
  static const brandOrangeLight = Color(0xFFFF8800);

  static const brandBg = Color(0xFFF2F2F7);

  static const textPrimary = Color(0xFF111111);
  static const textSecondary = Color(0xFF6B7280);

  static const brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [brandOrangeDark, brandOrangeLight],
  );
}

