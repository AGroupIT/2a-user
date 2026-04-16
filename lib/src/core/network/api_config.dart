import 'package:flutter/foundation.dart' show kDebugMode;

/// Конфигурация API
class ApiConfig {
  static const _mainHost = 'https://2alogistic.2a-marketing.ru';
  static const _hkHost = 'https://api.2a-logistic.com';

  /// Флаг китайского режима.
  /// Устанавливается при старте приложения и при смене языка на основе
  /// выбранного языка в настройках приложения (zh → HK-прокси).
  static bool _chineseMode = false;

  /// Вызывается из main.dart при старте и из AppLanguageNotifier при смене языка.
  static void setChineseMode(bool isChinese) {
    _chineseMode = isChinese;
  }

  static bool get _isChineseLocale => _chineseMode;

  static String get _host => _isChineseLocale ? _hkHost : _mainHost;

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

  /// Флаг: используем ли сейчас HK-прокси в качестве основного хоста
  static bool get isUsingHkProxy => _isChineseLocale;
  
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

  /// Таймаут для запросов
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);

  /// Заголовки по умолчанию
  static Map<String, String> get defaultHeaders => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
}
