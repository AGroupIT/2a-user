/// Конфигурация API
class ApiConfig {
  // The user app is used in Russia and does not need the China proxy. Mobile
  // builds should use the same public API domain as the stable web cabinet.
  static const _mainHost = 'https://prod-api.cp.2a-logistic.com';
  static const _legacyHost = 'https://2alogistic.2a-marketing.ru';

  /// 2a-user всегда ходит напрямую в основной backend.
  /// Метод оставлен для совместимости с кодом инициализации приложения.
  static void setChineseMode(bool _) {}

  static String get _host => _mainHost;

  /// Rewrites old absolute backend URLs to the active public host.
  static String rewriteToCurrentHost(String url) {
    var result = url.replaceFirst(_legacyHost, _host);
    result = result.replaceFirst(_mainHost, _host);
    return result;
  }

  /// Base URL для API
  static String get baseUrl {
    const envUrl = String.fromEnvironment('API_BASE_URL');
    if (envUrl.isNotEmpty) return envUrl;
    return '$_host/api';
  }

  /// Резервный API-домен для случаев, когда мобильная сеть не может
  /// установить соединение с основным доменом. Используется только после
  /// transient network error и не меняет основной happy path.
  static String? get fallbackBaseUrl {
    const envUrl = String.fromEnvironment('API_FALLBACK_BASE_URL');
    if (envUrl == 'none' || envUrl == 'disabled') return null;
    if (envUrl.isNotEmpty) return envUrl;

    const fallback = 'https://api.2a-logistic.com/api';
    if (fallback == baseUrl) return null;
    return fallback;
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

    if (path.startsWith('http://') || path.startsWith('https://')) {
      // Заменяем старый backend-домен на актуальный публичный хост.
      var result = rewriteToCurrentHost(path);

      // Преобразуем /uploads/ → /api/uploads/ для надёжной работы на всех платформах
      if (result.contains('/uploads/') && !result.contains('/api/uploads/')) {
        result = result.replaceFirst('/uploads/', '/api/uploads/');
      }
      return result;
    }

    // Для относительных путей
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;

    // Используем API endpoint для всех платформ (включая iOS)
    if (cleanPath.startsWith('uploads/')) {
      return '$mediaBaseUrl/api/$cleanPath';
    }

    return '$mediaBaseUrl/$cleanPath';
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
