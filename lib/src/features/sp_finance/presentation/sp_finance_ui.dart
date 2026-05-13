import 'package:flutter/material.dart';

import '../../../core/ui/app_colors.dart';
import '../../../core/ui/app_input_decoration.dart';

class SpFinanceUi {
  const SpFinanceUi._();

  static const textColor = Color(0xFF2F2F2F);
  static const mutedTextColor = Color(0x992F2F2F);

  static BoxDecoration cardDecoration({Color color = Colors.white}) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(10),
      boxShadow: const [
        BoxShadow(
          color: Color(0x1A000000),
          offset: Offset(3, 4),
          blurRadius: 25,
        ),
      ],
    );
  }

  static BoxDecoration softDecoration(BuildContext context) {
    return BoxDecoration(
      color: context.brandPrimary.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(10),
    );
  }

  static TextStyle get sectionTitleStyle {
    return const TextStyle(
      color: textColor,
      fontFamily: 'Gilroy',
      fontSize: 18,
      height: 22 / 18,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
    );
  }

  static TextStyle get bodyStyle {
    return const TextStyle(
      color: textColor,
      fontFamily: 'Gilroy',
      fontSize: 14,
      height: 18 / 14,
      fontWeight: FontWeight.w500,
    );
  }

  static TextStyle get labelStyle {
    return const TextStyle(
      color: mutedTextColor,
      fontFamily: 'Gilroy',
      fontSize: 12,
      height: 14 / 12,
      fontWeight: FontWeight.w500,
    );
  }

  static InputDecoration inputDecoration(
    BuildContext context, {
    String? labelText,
    String? hintText,
    String? suffixText,
    IconData? prefixIcon,
  }) {
    return appInputDecoration(
      context,
      labelText: labelText,
      hintText: hintText,
      suffixText: suffixText,
      prefixIcon: prefixIcon == null ? null : Icon(prefixIcon),
      labelStyle: labelStyle,
      hintStyle: const TextStyle(
        color: Color(0x662F2F2F),
        fontFamily: 'Gilroy',
        fontSize: 14,
        height: 16 / 14,
      ),
      fillColor: context.brandPrimary.withValues(alpha: 0.05),
      borderColor: Colors.grey.shade200,
    );
  }
}
