import 'package:flutter/foundation.dart';

/// Конфигурация API
class ApiConfig {
  /// Base URL для API
  static String get baseUrl {
    return 'http://188.124.54.40:3333/api';
  }
  
  /// Base URL для статических файлов (uploads)
  static String get mediaBaseUrl {
    return 'http://188.124.54.40:3333';
  }
  
  /// Формирует полный URL для медиа-файла
  static String getMediaUrl(String path) {
    if (path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    // Убираем лишний слеш если есть
    if (path.startsWith('/')) {
      return '$mediaBaseUrl$path';
    }
    return '$mediaBaseUrl/$path';
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
