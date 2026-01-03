import 'package:flutter/material.dart';

import '../../core/ui/app_colors.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme:
          ColorScheme.fromSeed(
            seedColor: AppColors.brandOrange,
            brightness: Brightness.light,
          ).copyWith(
            primary: AppColors.brandOrange,
            secondary: AppColors.brandOrangeLight,
          ),
    );

    return base.copyWith(
      scaffoldBackgroundColor: Colors.transparent,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        indicatorColor: AppColors.brandOrange.withValues(alpha: 0.14),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? AppColors.brandOrange : AppColors.textSecondary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 24,
            color: isSelected ? AppColors.brandOrange : AppColors.textSecondary,
          );
        }),
      ),
      cardTheme: CardThemeData(
        color: Colors.white.withValues(alpha: 0.72),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: Colors.white.withValues(alpha: 0.45),
            width: 0.8,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.75),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.70)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.70)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: AppColors.brandOrange,
            width: 1.5,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return AppColors.brandOrange.withValues(alpha: 0.5);
            }
            if (states.contains(WidgetState.pressed)) {
              return AppColors.brandOrangeDark;
            }
            if (states.contains(WidgetState.hovered)) {
              return AppColors.brandOrange.withValues(alpha: 0.9);
            }
            return AppColors.brandOrange;
          }),
          foregroundColor: WidgetStateProperty.all(Colors.white),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          ),
          textStyle: WidgetStateProperty.all(
            const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          elevation: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) return 0;
            return 2;
          }),
          shadowColor: WidgetStateProperty.all(
            AppColors.brandOrange.withValues(alpha: 0.3),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return Colors.white.withValues(alpha: 0.5);
            }
            if (states.contains(WidgetState.pressed)) {
              return AppColors.brandOrange.withValues(alpha: 0.1);
            }
            if (states.contains(WidgetState.hovered)) {
              return AppColors.brandOrange.withValues(alpha: 0.05);
            }
            return Colors.white;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return AppColors.brandOrange.withValues(alpha: 0.5);
            }
            return AppColors.brandOrange;
          }),
          side: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return BorderSide(
                color: AppColors.brandOrange.withValues(alpha: 0.3),
                width: 1.5,
              );
            }
            return const BorderSide(color: AppColors.brandOrange, width: 1.5);
          }),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          ),
          textStyle: WidgetStateProperty.all(
            const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return AppColors.brandOrange.withValues(alpha: 0.5);
            }
            return AppColors.brandOrange;
          }),
          textStyle: WidgetStateProperty.all(
            const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ),
    );
  }
}
