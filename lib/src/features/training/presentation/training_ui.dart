import 'package:flutter/material.dart';

import '../../../core/ui/app_colors.dart';

/// Existing Home card and branded sheet styles, scoped to learning surfaces.
class TrainingUi {
  const TrainingUi._();

  static Color contrastingAccent(Color color) => color.computeLuminance() > 0.45
      ? Color.alphaBlend(Colors.black.withValues(alpha: 0.55), color)
      : color;

  static BoxDecoration get cardDecoration => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(24),
    border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.05),
        offset: const Offset(0, 8),
        blurRadius: 22,
      ),
    ],
  );

  static const title = TextStyle(
    color: AppColors.textPrimary,
    fontFamily: 'Gilroy',
    fontSize: 18,
    fontWeight: FontWeight.w900,
    height: 1.15,
  );

  static const body = TextStyle(
    color: AppColors.textPrimary,
    fontFamily: 'Gilroy',
    fontSize: 13,
    fontWeight: FontWeight.w600,
    height: 1.4,
  );

  static const caption = TextStyle(
    color: AppColors.textSecondary,
    fontFamily: 'Gilroy',
    fontSize: 12,
    fontWeight: FontWeight.w600,
    height: 1.25,
  );

  static ButtonStyle primaryButton(BuildContext context) =>
      FilledButton.styleFrom(
        backgroundColor: context.brandPrimary,
        foregroundColor:
            ThemeData.estimateBrightnessForColor(context.brandPrimary) ==
                Brightness.light
            ? AppColors.textPrimary
            : Colors.white,
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        textStyle: body.copyWith(fontSize: 14, fontWeight: FontWeight.w900),
      );

  static ButtonStyle secondaryButton(BuildContext context) =>
      OutlinedButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        side: const BorderSide(color: Color(0xFFE1E5ED)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        textStyle: body.copyWith(fontSize: 14, fontWeight: FontWeight.w800),
      );

  static ButtonStyle textButton(BuildContext context) => TextButton.styleFrom(
    foregroundColor: contrastingAccent(context.brandPrimary),
    minimumSize: const Size(0, 44),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
    textStyle: body.copyWith(fontWeight: FontWeight.w800),
  );

  static ThemeData theme(BuildContext context) => Theme.of(context).copyWith(
    filledButtonTheme: FilledButtonThemeData(style: primaryButton(context)),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: secondaryButton(context),
    ),
    textButtonTheme: TextButtonThemeData(style: textButton(context)),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: AppColors.textSecondary,
        backgroundColor: const Color(0xFFF8FAFC),
        minimumSize: const Size(44, 44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
      ),
    ),
  );
}
