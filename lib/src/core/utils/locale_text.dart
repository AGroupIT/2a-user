import 'package:flutter/widgets.dart';

/// Simple locale helper for RU / ZH.
/// Falls back to Russian for other locales.
String tr(BuildContext context, {required String ru, required String zh}) {
  final lang = Localizations.localeOf(context).languageCode.toLowerCase();
  if (lang.startsWith('zh')) return zh;
  return ru;
}

/// Check if current locale is Chinese
bool isZh(BuildContext context) {
  final lang = Localizations.localeOf(context).languageCode.toLowerCase();
  return lang.startsWith('zh');
}
