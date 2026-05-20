import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/auth_provider.dart';
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

  /// Нейтральные цвета до загрузки профиля агента.
  static const defaultColors = BrandColors(
    primary: Color(0xFF6B7280),
    primaryDark: Color(0xFF4B5563),
    primaryLight: Color(0xFF9CA3AF),
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
    return hsl
        .withLightness((hsl.lightness - amount).clamp(0.0, 1.0))
        .toColor();
  }

  /// Осветлить цвет
  static Color _lighten(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withLightness((hsl.lightness + amount).clamp(0.0, 1.0))
        .toColor();
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
  final authState = ref.watch(authProvider);

  BrandColors fromAuthData() {
    final agent = authState.clientData?['agent'];
    if (agent is Map<String, dynamic>) {
      return BrandColors.fromHex(
        agent['colorPrimary'] as String?,
        agent['colorSecondary'] as String?,
      );
    }
    return BrandColors.defaultColors;
  }

  return profileAsync.when(
    data: (profile) {
      if (profile?.agent != null) {
        return BrandColors.fromHex(
          profile!.agent!.colorPrimary,
          profile.agent!.colorSecondary,
        );
      }
      return fromAuthData();
    },
    loading: fromAuthData,
    error: (_, _) => fromAuthData(),
  );
});

class AppColors {
  const AppColors._();

  // Legacy aliases. Keep them neutral so old widgets do not flash an
  // unrelated agent color before real brand colors are loaded.
  static const brandOrangeDark = Color(0xFF4B5563);
  static const brandOrange = Color(0xFF6B7280);
  static const brandOrangeLight = Color(0xFF9CA3AF);

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
      HSLColor.fromColor(brandPrimary)
          .withLightness(
            (HSLColor.fromColor(brandPrimary).lightness - 0.1).clamp(0.0, 1.0),
          )
          .toColor(),
      brandSecondary,
    ],
  );
}
