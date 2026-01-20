import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../persistence/shared_preferences_provider.dart';

enum AppLanguage {
  system,
  ru,
  zh,
}

extension AppLanguageX on AppLanguage {
  Locale? get locale {
    return switch (this) {
      AppLanguage.system => null,
      AppLanguage.ru => const Locale('ru'),
      AppLanguage.zh => const Locale('zh'),
    };
  }

  String get labelRu {
    return switch (this) {
      AppLanguage.system => 'Авто (язык системы)',
      AppLanguage.ru => 'Русский',
      AppLanguage.zh => 'Китайский',
    };
  }
}

final appLanguageProvider = NotifierProvider<AppLanguageNotifier, AppLanguage>(
  AppLanguageNotifier.new,
);

class AppLanguageNotifier extends Notifier<AppLanguage> {
  static const _key = 'app_language';

  @override
  AppLanguage build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final raw = prefs.getString(_key);
    return AppLanguage.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => AppLanguage.system,
    );
  }

  Future<void> setLanguage(AppLanguage language) async {
    final prefs = ref.read(sharedPreferencesProvider);
    if (language == AppLanguage.system) {
      await prefs.remove(_key);
    } else {
      await prefs.setString(_key, language.name);
    }
    state = language;
  }
}

