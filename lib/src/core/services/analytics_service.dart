import 'package:appmetrica_plugin/appmetrica_plugin.dart';
import 'package:flutter/foundation.dart';
import '../config/appmetrica_config.dart';

/// Сервис для работы с Yandex AppMetrica аналитикой
class AnalyticsService {
  AnalyticsService._();

  static bool _initialized = false;

  /// Инициализация AppMetrica SDK
  static Future<void> initialize() async {
    if (_initialized) return;
    if (kIsWeb) return; // AppMetrica не поддерживает Web

    if (!AppMetricaSettings.enabled) {
      if (kDebugMode) {
        print('📊 AppMetrica: Аналитика отключена');
      }
      return;
    }

    try {
      // Конфигурация AppMetrica
      await AppMetrica.activate(
        AppMetricaConfig(
          AppMetricaSettings.apiKey,
          logs: AppMetricaSettings.logsEnabled,
          locationTracking: AppMetricaSettings.locationTracking,
          crashReporting: AppMetricaSettings.crashReporting,
          sessionTimeout: 10, // 10 секунд неактивности = новая сессия
          dataSendingEnabled: true,
        ),
      );

      _initialized = true;

      if (kDebugMode) {
        print('📊 AppMetrica: Инициализация успешна');
        print('📊 AppMetrica: App ID - ${AppMetricaSettings.appId}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('📊 AppMetrica: Ошибка инициализации - $e');
      }
    }
  }

  /// Отправить событие
  static Future<void> logEvent(String eventName, [Map<String, dynamic>? parameters]) async {
    if (!_initialized || !AppMetricaSettings.enabled) return;

    try {
      if (parameters != null && parameters.isNotEmpty) {
        await AppMetrica.reportEventWithMap(eventName, parameters.cast<String, Object>());
      } else {
        await AppMetrica.reportEvent(eventName);
      }

      if (kDebugMode) {
        print('📊 AppMetrica: Событие "$eventName"${parameters != null ? ' с параметрами: $parameters' : ''}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('📊 AppMetrica: Ошибка отправки события "$eventName" - $e');
      }
    }
  }

  /// Установить ID пользователя
  static Future<void> setUserId(String userId) async {
    if (!_initialized || !AppMetricaSettings.enabled) return;

    try {
      await AppMetrica.setUserProfileID(userId);

      if (kDebugMode) {
        print('📊 AppMetrica: User ID установлен - $userId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('📊 AppMetrica: Ошибка установки User ID - $e');
      }
    }
  }

  /// Установить атрибут пользователя
  static Future<void> setUserAttribute(String key, String value) async {
    if (!_initialized || !AppMetricaSettings.enabled) return;

    try {
      final attribute = AppMetricaStringAttribute.withValueReset(key);
      final userProfile = AppMetricaUserProfile([attribute]);
      await AppMetrica.reportUserProfile(userProfile);

      if (kDebugMode) {
        print('📊 AppMetrica: Атрибут пользователя "$key" = "$value"');
      }
    } catch (e) {
      if (kDebugMode) {
        print('📊 AppMetrica: Ошибка установки атрибута "$key" - $e');
      }
    }
  }

  /// Отправить информацию об ошибке
  static Future<void> reportError(String message, {dynamic error, StackTrace? stackTrace}) async {
    if (!_initialized || !AppMetricaSettings.enabled) return;

    try {
      // Отправляем как событие, так как API reportError может отличаться в разных версиях
      await logEvent('app_error', {
        'error_message': message,
        'error_type': error?.runtimeType.toString() ?? 'Unknown',
        'has_stacktrace': stackTrace != null,
      });

      if (kDebugMode) {
        print('📊 AppMetrica: Ошибка зарегистрирована - $message');
      }
    } catch (e) {
      if (kDebugMode) {
        print('📊 AppMetrica: Ошибка отправки error report - $e');
      }
    }
  }

  /// Начать новую сессию
  static Future<void> resumeSession() async {
    if (!_initialized || !AppMetricaSettings.enabled) return;

    try {
      await AppMetrica.resumeSession();

      if (kDebugMode) {
        print('📊 AppMetrica: Сессия возобновлена');
      }
    } catch (e) {
      if (kDebugMode) {
        print('📊 AppMetrica: Ошибка возобновления сессии - $e');
      }
    }
  }

  /// Приостановить сессию
  static Future<void> pauseSession() async {
    if (!_initialized || !AppMetricaSettings.enabled) return;

    try {
      await AppMetrica.pauseSession();

      if (kDebugMode) {
        print('📊 AppMetrica: Сессия приостановлена');
      }
    } catch (e) {
      if (kDebugMode) {
        print('📊 AppMetrica: Ошибка приостановки сессии - $e');
      }
    }
  }

  // === Готовые методы для типовых событий ===

  /// Событие: Пользователь вошел в систему
  static Future<void> logLogin(String method) async {
    await logEvent('login', {'method': method});
  }

  /// Событие: Пользователь вышел из системы
  static Future<void> logLogout() async {
    await logEvent('logout');
  }

  /// Событие: Просмотр экрана
  static Future<void> logScreenView(String screenName) async {
    await logEvent('screen_view', {'screen_name': screenName});
  }

  /// Событие: Клик по элементу
  static Future<void> logButtonClick(String buttonName, {String? screen}) async {
    await logEvent('button_click', {
      'button_name': buttonName,
      if (screen != null) 'screen': screen,
    });
  }

  /// Событие: Поиск треков
  static Future<void> logTrackSearch(String query, int resultsCount) async {
    await logEvent('track_search', {
      'query': query,
      'results_count': resultsCount,
    });
  }

  /// Событие: Создание сборки
  static Future<void> logAssemblyCreated(int trackCount) async {
    await logEvent('assembly_created', {
      'track_count': trackCount,
    });
  }

  /// Событие: Запрос фотоотчета
  static Future<void> logPhotoReportRequest() async {
    await logEvent('photo_report_request');
  }

  /// Событие: Задан вопрос
  static Future<void> logQuestionAsked() async {
    await logEvent('question_asked');
  }

  /// Событие: Открытие чата
  static Future<void> logChatOpened(String chatType) async {
    await logEvent('chat_opened', {'chat_type': chatType});
  }

  /// Событие: Отправка сообщения
  static Future<void> logMessageSent(String chatType) async {
    await logEvent('message_sent', {'chat_type': chatType});
  }

  /// Событие: Просмотр новости
  static Future<void> logNewsViewed(String newsId, String newsTitle) async {
    await logEvent('news_viewed', {
      'news_id': newsId,
      'news_title': newsTitle,
    });
  }

  /// Событие: Выбор способа доставки
  static Future<void> logDeliveryMethodSelected(String method) async {
    await logEvent('delivery_method_selected', {
      'method': method,
    });
  }

  /// Событие: Выбор тарифа
  static Future<void> logTariffSelected(String tariffName) async {
    await logEvent('tariff_selected', {
      'tariff_name': tariffName,
    });
  }
}
