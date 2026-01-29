/// Конфигурация для Yandex AppMetrica
class AppMetricaSettings {
  AppMetricaSettings._();

  /// API ключ приложения (для использования в SDK)
  static const String apiKey = 'eded1c7b-69b5-43c5-86a3-61ae99ea7d45';

  /// ID приложения
  static const int appId = 6248653;

  /// Post API key (для серверной отправки событий)
  static const String postApiKey = 'd503c55b-2e1c-4b3c-b462-a36dd4ceb6d8';

  /// Включена ли аналитика
  static const bool enabled = true;

  /// Включить отладочные логи (только для разработки)
  static const bool logsEnabled = false;

  /// Отслеживать местоположение
  static const bool locationTracking = false;

  /// Собирать краш-репорты
  static const bool crashReporting = true;

  /// Период отправки событий в секундах
  static const int dispatchPeriodSeconds = 90; // По умолчанию 90 секунд

  /// Максимальное количество событий в кеше
  static const int maxReportsInDatabaseCount = 1000;
}
