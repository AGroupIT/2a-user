import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/ui/app_colors.dart';
import '../../core/ui/app_input_decoration.dart';

class AppTheme {
  const AppTheme._();

  /// Создать тему со статическими цветами (дефолт)
  static ThemeData light() {
    return lightWithColors(BrandColors.defaultColors);
  }

  /// Создать тему с динамическими цветами бренда
  static ThemeData lightWithColors(BrandColors brand) {
    final base = ThemeData(
      useMaterial3: true,
      fontFamily: 'Gilroy',
      colorScheme: ColorScheme.fromSeed(
        seedColor: brand.primary,
        brightness: Brightness.light,
      ).copyWith(primary: brand.primary, secondary: brand.primaryLight),
    );

    return base.copyWith(
      scaffoldBackgroundColor: Colors.transparent,
      textTheme: base.textTheme.apply(fontFamily: 'Gilroy'),
      primaryTextTheme: base.primaryTextTheme.apply(fontFamily: 'Gilroy'),
      cupertinoOverrideTheme: const CupertinoThemeData(
        textTheme: CupertinoTextThemeData(
          textStyle: TextStyle(fontFamily: 'Gilroy'),
          actionTextStyle: TextStyle(fontFamily: 'Gilroy'),
          navTitleTextStyle: TextStyle(fontFamily: 'Gilroy'),
          navLargeTitleTextStyle: TextStyle(fontFamily: 'Gilroy'),
          pickerTextStyle: TextStyle(fontFamily: 'Gilroy'),
          dateTimePickerTextStyle: TextStyle(fontFamily: 'Gilroy'),
        ),
      ),
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
        indicatorColor: brand.primary.withValues(alpha: 0.14),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return TextStyle(
            fontFamily: 'Gilroy',
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? brand.primary : AppColors.textSecondary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 24,
            color: isSelected ? brand.primary : AppColors.textSecondary,
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
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: appInputBorder(Colors.white.withValues(alpha: 0.70)),
        enabledBorder: appInputBorder(Colors.white.withValues(alpha: 0.70)),
        focusedBorder: appInputBorder(brand.primary, width: 1.5),
        errorBorder: appInputBorder(const Color(0xFFE53935)),
        focusedErrorBorder: appInputBorder(const Color(0xFFE53935), width: 1.5),
        disabledBorder: appInputBorder(Colors.white.withValues(alpha: 0.45)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return brand.primary.withValues(alpha: 0.5);
            }
            if (states.contains(WidgetState.pressed)) {
              return brand.primaryDark;
            }
            if (states.contains(WidgetState.hovered)) {
              return brand.primary.withValues(alpha: 0.9);
            }
            return brand.primary;
          }),
          foregroundColor: WidgetStateProperty.all(Colors.white),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          ),
          textStyle: WidgetStateProperty.all(
            const TextStyle(
              fontFamily: 'Gilroy',
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
          elevation: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) return 0;
            return 2;
          }),
          shadowColor: WidgetStateProperty.all(
            brand.primary.withValues(alpha: 0.3),
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
              return brand.primary.withValues(alpha: 0.1);
            }
            if (states.contains(WidgetState.hovered)) {
              return brand.primary.withValues(alpha: 0.05);
            }
            return Colors.white;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return brand.primary.withValues(alpha: 0.5);
            }
            return brand.primary;
          }),
          side: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return BorderSide(
                color: brand.primary.withValues(alpha: 0.3),
                width: 1.5,
              );
            }
            return BorderSide(color: brand.primary, width: 1.5);
          }),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          ),
          textStyle: WidgetStateProperty.all(
            const TextStyle(
              fontFamily: 'Gilroy',
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return brand.primary.withValues(alpha: 0.5);
            }
            return brand.primary;
          }),
          textStyle: WidgetStateProperty.all(
            const TextStyle(
              fontFamily: 'Gilroy',
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ),
    );
  }
}
