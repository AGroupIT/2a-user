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

  /// Резервный API-домен для полевых тестов.
  ///
  /// В обычных сборках 2a-user не переключается на legacy/backend fallback:
  /// при временной сетевой ошибке приложение должно оставаться на основном
  /// production API, чтобы не смешивать диагностику и не уходить на старый
  /// домен. Если нужен отдельный маршрут для ручного полевого теста, его можно
  /// явно задать сборкой:
  ///
  /// `--dart-define=FALLBACK_API_BASE_URL=https://api.2a-logistic.com/api`
  static String? get fallbackBaseUrl {
    const envUrl = String.fromEnvironment('FALLBACK_API_BASE_URL');
    if (envUrl.isNotEmpty) return envUrl;
    return null;
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

  /// Формирует URL уменьшенного thumbnail для карточек и списков.
  ///
  /// Оригинальный URL сохраняется для полноэкранного просмотра/скачивания,
  /// а превью идут через /api/uploads/thumb/{size}/..., чтобы не тянуть
  /// тяжёлые фото в маленькие плитки на web/iOS/Android.
  static String getMediaThumbnailUrl(String path, {int size = 360}) {
    final mediaUrl = getMediaUrl(path);
    if (mediaUrl.isEmpty) return '';
    if (!supportsMediaThumbnail(mediaUrl)) return mediaUrl;

    const uploadsMarker = '/api/uploads/';
    final uploadsIndex = mediaUrl.indexOf(uploadsMarker);
    if (uploadsIndex == -1 || mediaUrl.contains('/api/uploads/thumb/')) {
      return mediaUrl;
    }

    final normalizedSize = _normalizeThumbnailSize(size);
    final prefix = mediaUrl.substring(0, uploadsIndex + uploadsMarker.length);
    final relativePath = mediaUrl.substring(
      uploadsIndex + uploadsMarker.length,
    );
    if (relativePath.isEmpty || relativePath.startsWith('thumb/')) {
      return mediaUrl;
    }

    return '${prefix}thumb/$normalizedSize/$relativePath';
  }

  static bool supportsMediaThumbnail(String path) {
    final cleanPath = _stripUrlQueryAndFragment(path).toLowerCase();
    final extensionIndex = cleanPath.lastIndexOf('.');
    if (extensionIndex == -1 || extensionIndex == cleanPath.length - 1) {
      return false;
    }

    final extension = cleanPath.substring(extensionIndex + 1);
    return const {'jpg', 'jpeg', 'png', 'webp'}.contains(extension);
  }

  static int _normalizeThumbnailSize(int size) {
    const supportedSizes = [160, 240, 360, 480, 720, 960];
    if (size <= 0) return 360;

    var closest = supportedSizes.first;
    var closestDistance = (size - closest).abs();
    for (final supportedSize in supportedSizes.skip(1)) {
      final distance = (size - supportedSize).abs();
      if (distance < closestDistance) {
        closest = supportedSize;
        closestDistance = distance;
      }
    }
    return closest;
  }

  static String _stripUrlQueryAndFragment(String url) {
    final queryIndex = url.indexOf('?');
    final fragmentIndex = url.indexOf('#');
    final cutPoints = [
      if (queryIndex != -1) queryIndex,
      if (fragmentIndex != -1) fragmentIndex,
    ];
    if (cutPoints.isEmpty) return url;
    cutPoints.sort();
    return url.substring(0, cutPoints.first);
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
