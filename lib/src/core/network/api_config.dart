import 'package:flutter/foundation.dart' show kDebugMode;

/// Конфигурация API
class ApiConfig {
  static const _mainHost = 'https://2alogistic.2a-marketing.ru';

  /// 2a-user всегда ходит напрямую в основной backend.
  /// Метод оставлен для совместимости с кодом инициализации приложения.
  static void setChineseMode(bool _) {}

  static String get _host => _mainHost;

  /// Base URL для API
  static String get baseUrl {
    const envUrl = String.fromEnvironment('API_BASE_URL');
    if (envUrl.isNotEmpty) return envUrl;
    return '$_host/api';
  }

  /// Base URL для статических файлов (uploads)
  static String get mediaBaseUrl {
    const envUrl = String.fromEnvironment('MEDIA_BASE_URL');
    if (envUrl.isNotEmpty) return envUrl;
    return _host;
  }

  /// 2a-user не использует HK-прокси.
  static bool get isUsingHkProxy => false;

  /// Формирует полный URL для медиа-файла
  /// Использует /api/uploads/ endpoint для надёжной работы на всех платформах
  static String getMediaUrl(String path) {
    if (path.isEmpty) return '';

    if (kDebugMode) {
      print('📸 getMediaUrl input: "$path"');
    }

    if (path.startsWith('http://') || path.startsWith('https://')) {
      // Заменяем домен основного сервера на актуальный хост (HK или основной)
      var result = path.replaceFirst(_mainHost, _host);

      // Преобразуем /uploads/ → /api/uploads/ для надёжной работы на всех платформах
      if (result.contains('/uploads/') && !result.contains('/api/uploads/')) {
        result = result.replaceFirst('/uploads/', '/api/uploads/');
      }
      if (kDebugMode) {
        print('📸 getMediaUrl output (absolute): "$result"');
      }
      return result;
    }

    // Для относительных путей
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;

    // Используем API endpoint для всех платформ (включая iOS)
    if (cleanPath.startsWith('uploads/')) {
      final result = '$mediaBaseUrl/api/$cleanPath';
      if (kDebugMode) {
        print('📸 getMediaUrl output (uploads path): "$result"');
      }
      return result;
    }

    final result = '$mediaBaseUrl/$cleanPath';
    if (kDebugMode) {
      print('📸 getMediaUrl output (other path): "$result"');
    }
    return result;
  }

  /// Таймауты для запросов.
  ///
  /// 2a-user часто открывают после долгого background/sleep. На мобильных
  /// сетях старое TCP-соединение может выглядеть живым для dart:io, но уже не
  /// отвечать. Короткие Dio-timeout + общий wall-clock timeout в ApiClient не
  /// дают UI висеть в бесконечной загрузке.
  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 20);
  static const Duration sendTimeout = Duration(seconds: 20);

  /// Политика повторов при кратковременных сетевых ошибках.
  static const int maxRetries = 2;
  static const Duration retryDelay = Duration(milliseconds: 500);

  /// Страховочный timeout всего запроса, включая retry.
  static const Duration overallRequestTimeout = Duration(seconds: 30);

  /// Заголовки по умолчанию
  static Map<String, String> get defaultHeaders => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };
}
