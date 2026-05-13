import 'package:flutter/material.dart';

class PurchaseBlankUi {
  const PurchaseBlankUi._();

  static const textColor = Color(0xFF2F2F2F);
  static const mutedTextColor = Color(0x992F2F2F);

  static BoxDecoration cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
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
}
