import 'package:flutter/foundation.dart' show kDebugMode;

/// Конфигурация API
class ApiConfig {
  // Можно переопределить через --dart-define=API_BASE_URL=...
  static const String _defaultBaseUrl = 'https://2alogistic.2a-marketing.ru/api';
  static const String _defaultMediaUrl = 'https://2alogistic.2a-marketing.ru';
  
  /// Base URL для API (из env или дефолт)
  static String get baseUrl {
    const envUrl = String.fromEnvironment('API_BASE_URL');
    if (envUrl.isNotEmpty) return envUrl;
    
    // В debug можно использовать прямой IP для отладки
    if (kDebugMode) {
      // Раскомментируйте для локальной отладки:
      // return 'http://188.124.54.40:3333/api';
    }
    return _defaultBaseUrl;
  }
  
  /// Base URL для статических файлов (uploads) - через Nginx
  static String get mediaBaseUrl {
    const envUrl = String.fromEnvironment('MEDIA_BASE_URL');
    if (envUrl.isNotEmpty) return envUrl;
    return _defaultMediaUrl;
  }
  
  /// Формирует полный URL для медиа-файла
  /// Использует /api/uploads/ endpoint для надёжной работы на всех платформах
  static String getMediaUrl(String path) {
    if (path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) {
      // Преобразуем прямые ссылки на uploads через API (для всех платформ)
      if (path.contains('/uploads/') && !path.contains('/api/uploads/')) {
        // Заменяем /uploads/ на /api/uploads/
        return path.replaceFirst('/uploads/', '/api/uploads/');
      }
      return path;
    }

    // Для относительных путей
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;

    // Используем API endpoint для всех платформ (включая iOS)
    if (cleanPath.startsWith('uploads/')) {
      return '$mediaBaseUrl/api/$cleanPath';
    }

    return '$mediaBaseUrl/$cleanPath';
  }

  /// Таймаут для запросов
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);

  /// Заголовки по умолчанию
  static Map<String, String> get defaultHeaders => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
}
