import 'package:flutter/foundation.dart';

/// Конфигурация для Sentry error tracking
class SentryConfig {
  /// DSN (Data Source Name) для Sentry проекта
  /// Получается из переменной окружения при сборке или hardcoded для development
  static const String dsn = String.fromEnvironment(
    'SENTRY_DSN',
    defaultValue: '', // Пустой DSN для development - Sentry не будет работать
  );

  /// Включен ли Sentry (только если DSN задан)
  static bool get enabled => dsn.isNotEmpty && kReleaseMode;

  /// Окружение (production, staging, development)
  static String get environment {
    if (kReleaseMode) {
      return 'production';
    } else if (kProfileMode) {
      return 'staging';
    } else {
      return 'development';
    }
  }

  /// Sample rate для отправки событий (0.0 - 1.0)
  /// 1.0 = отправлять все события
  static double get sampleRate => 1.0;

  /// Sample rate для трассировки производительности (0.0 - 1.0)
  /// 0.1 = отправлять 10% транзакций
  static double get tracesSampleRate => kReleaseMode ? 0.1 : 0.0;

  /// Debug режим для Sentry (только в development)
  static bool get debug => kDebugMode;

  /// Версия приложения
  static String get release => '1.0.0'; // TODO: Взять из package_info

  /// Имя приложения для Sentry
  static String get appName => '2a-user';

  /// Максимальное количество breadcrumbs
  static int get maxBreadcrumbs => 100;

  /// Timeout для отправки событий
  static Duration get sendTimeout => const Duration(seconds: 30);
}
