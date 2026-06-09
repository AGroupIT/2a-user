import 'package:flutter/foundation.dart';

/// Конфигурация для Yandex AppMetrica
class AppMetricaSettings {
  AppMetricaSettings._();

  /// API ключ приложения (для использования в SDK)
  static const String apiKey = 'eded1c7b-69b5-43c5-86a3-61ae99ea7d45';

  /// ID приложения
  static const int appId = 6248653;

  /// Post API key (для серверной отправки событий)
  static const String postApiKey = 'd503c55b-2e1c-4b3c-b462-a36dd4ceb6d8';

  /// Включена ли аналитика.
  ///
  /// В profile-сборках выключаем по умолчанию, чтобы KSCrash/AppMetrica
  /// не искажали performance-замеры. В release аналитика остаётся включённой.
  /// При необходимости можно переопределить:
  /// `--dart-define=APP_METRICA_ENABLED=true|false`.
  static const bool enabled = bool.fromEnvironment(
    'APP_METRICA_ENABLED',
    defaultValue: !kProfileMode,
  );

  /// Включить отладочные логи (только для разработки)
  static const bool logsEnabled = false;

  /// Отслеживать местоположение
  static const bool locationTracking = false;

  /// Собирать краш-репорты
  ///
  /// Sentry остаётся основным crash reporting. У AppMetrica crash collector
  /// на iOS подключает KSCrash, который в profile/release шумит
  /// `KSBinaryImageCache ... Binary image cache full` и может искажать
  /// performance-профиль. Аналитику AppMetrica оставляем включённой.
  static const bool crashReporting = false;

  /// Период отправки событий в секундах
  static const int dispatchPeriodSeconds = 90; // По умолчанию 90 секунд

  /// Максимальное количество событий в кеше
  static const int maxReportsInDatabaseCount = 1000;
}
