import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/profile/data/profile_provider.dart';

/// Состояние брендовых цветов
class BrandColors {
  final Color primary;
  final Color primaryDark;
  final Color primaryLight;

  const BrandColors({
    required this.primary,
    required this.primaryDark,
    required this.primaryLight,
  });

  /// Дефолтные цвета (оранжевые)
  static const defaultColors = BrandColors(
    primary: Color(0xFFFF5E04),
    primaryDark: Color(0xFFFE3301),
    primaryLight: Color(0xFFFF8800),
  );

  /// Создать из HEX строки
  factory BrandColors.fromHex(String? primaryHex, String? secondaryHex) {
    if (primaryHex == null || primaryHex.isEmpty) {
      return defaultColors;
    }

    final primary = _parseColor(primaryHex) ?? defaultColors.primary;
    final secondary = secondaryHex != null && secondaryHex.isNotEmpty
        ? _parseColor(secondaryHex)
        : null;

    return BrandColors(
      primary: primary,
      primaryDark: _darken(primary, 0.1),
      primaryLight: secondary ?? _lighten(primary, 0.15),
    );
  }

  /// Парсинг HEX цвета
  static Color? _parseColor(String hex) {
    try {
      String cleanHex = hex.replaceAll('#', '');
      if (cleanHex.length == 6) {
        cleanHex = 'FF$cleanHex';
      }
      return Color(int.parse(cleanHex, radix: 16));
    } catch (_) {
      return null;
    }
  }

  /// Затемнить цвет
  static Color _darken(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    return hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0)).toColor();
  }

  /// Осветлить цвет
  static Color _lighten(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    return hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0)).toColor();
  }

  /// Градиент бренда
  LinearGradient get gradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryDark, primaryLight],
  );
}

/// Провайдер брендовых цветов (загружаются из профиля агента)
final brandColorsProvider = Provider<BrandColors>((ref) {
  final profileAsync = ref.watch(clientProfileProvider);

  return profileAsync.when(
    data: (profile) {
      if (profile?.agent != null) {
        return BrandColors.fromHex(
          profile!.agent!.colorPrimary,
          profile.agent!.colorSecondary,
        );
      }
      return BrandColors.defaultColors;
    },
    loading: () => BrandColors.defaultColors,
    error: (_, _) => BrandColors.defaultColors,
  );
});

class AppColors {
  const AppColors._();

  // Дефолтные статические цвета (для использования до загрузки профиля)
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

/// Расширение для получения брендовых цветов через context
extension BrandColorsExtension on BuildContext {
  /// Получить primary цвет из темы (загруженный из БД)
  Color get brandPrimary => Theme.of(this).colorScheme.primary;
  
  /// Получить secondary цвет из темы (загруженный из БД)
  Color get brandSecondary => Theme.of(this).colorScheme.secondary;
  
  /// Создать градиент с цветами бренда
  LinearGradient get brandGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      HSLColor.fromColor(brandPrimary).withLightness(
        (HSLColor.fromColor(brandPrimary).lightness - 0.1).clamp(0.0, 1.0)
      ).toColor(),
      brandSecondary,
    ],
  );
}

