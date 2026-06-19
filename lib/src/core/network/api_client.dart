import 'dart:async';
import 'dart:collection';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/sentry_config.dart';
import '../logging/client_log_service.dart';
import '../services/runtime/app_runtime_info.dart';
import 'api_config.dart';
import 'native_http_adapter.dart';

/// Callback для обработки 401 ошибки (unauthorized)
typedef OnUnauthorizedCallback = void Function();

/// Провайдер для ApiClient
final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient();
});

/// Клиент для работы с API
class ApiClient {
  late Dio _dio;
  // На мобильных платформах используем FlutterSecureStorage с правильными настройками
  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );
  static const String _tokenKey = 'auth_token';
  // Дублируем приватный ключ auth_provider без импорта, чтобы не создавать cycle.
  // Нужен только как быстрый guard: если пользователь не залогинен, не будим
  // Android Keystore/EncryptedSharedPreferences ради проверки пустого токена.
  static const String _isLoggedInPrefsKey = 'is_logged_in';

  // In-memory fallback для web и desktop
  static String? _inMemoryToken;
  static Future<String?>? _tokenLoadInFlight;
  static const Duration _prefsTimeout = Duration(seconds: 3);
  static int _requestSequence = 0;
  static const Duration _minConnectionResetInterval = Duration(seconds: 8);
  static const Duration _fallbackTtl = Duration(minutes: 5);
  static const int _maxConcurrentGetRequests = 3;

  int _inFlightRequests = 0;
  int _activeGetRequests = 0;
  final Queue<Completer<void>> _getRequestQueue = Queue<Completer<void>>();
  DateTime? _lastConnectionResetAt;
  String? _baseUrlOverride;
  DateTime? _fallbackActivatedAt;
  int _consecutiveNetworkErrors = 0;
  DateTime? _lastNetworkErrorReportAt;

  // Callback для обработки 401 unauthorized
  OnUnauthorizedCallback? _onUnauthorized;
  bool _unauthorizedCallbackScheduled = false;

  /// Установить callback для обработки 401 ошибки
  void setOnUnauthorizedCallback(OnUnauthorizedCallback callback) {
    _onUnauthorized = callback;
  }

  ApiClient() {
    _dio = _createDio();
    ClientLogService.instance.add(
      type: 'api_base_url_config',
      level: 'info',
      message: 'Настроен API host 2a-user',
      data: {
        'primaryBaseUrl': ApiConfig.baseUrl,
        'activeBaseUrl': activeBaseUrl,
        'fallbackBaseUrl': ApiConfig.fallbackBaseUrl,
        'fallbackEnabled': ApiConfig.fallbackBaseUrl != null,
      },
    );
  }

  String get activeBaseUrl => _baseUrlOverride ?? ApiConfig.baseUrl;

  bool get isUsingFallbackBaseUrl =>
      _baseUrlOverride != null && _baseUrlOverride != ApiConfig.baseUrl;

  Dio _createDio() {
    final dio = Dio(
      BaseOptions(
        baseUrl: activeBaseUrl,
        connectTimeout: ApiConfig.connectTimeout,
        receiveTimeout: ApiConfig.receiveTimeout,
        sendTimeout: ApiConfig.sendTimeout,
        headers: ApiConfig.defaultHeaders,
      ),
    );

    // На Web BackgroundTransformer использует isolate-путь, который нестабилен
    // в dart2js. Админка уже работает через SyncTransformer, переносим тот же
    // подход в клиентское приложение.
    if (kIsWeb) {
      dio.transformer = SyncTransformer();
    }

    final nativeAdapter = createNativeHttpAdapter();
    if (nativeAdapter != null) {
      dio.httpClientAdapter = nativeAdapter;
    }

    // Добавляем интерсепторы
    dio.interceptors.add(_clientTelemetryInterceptor());
    dio.interceptors.add(_authInterceptor());

    // Sentry interceptor для отслеживания HTTP ошибок
    if (SentryConfig.enabled) {
      dio.interceptors.add(_sentryInterceptor());
    }

    if (kDebugMode) {
      dio.interceptors.add(_loggingInterceptor());
    }

    return dio;
  }

  /// Закрывает текущие HTTP-соединения и создаёт новый Dio.
  ///
  /// Используется после долгого background/sleep: мобильные сети и WebView
  /// иногда оставляют keep-alive сокет в состоянии, где запрос уже не отвечает,
  /// но Future ещё ждёт receive timeout.
  void resetConnections({
    String reason = 'manual_or_retry',
    bool force = false,
  }) {
    final now = DateTime.now();
    final lastResetAt = _lastConnectionResetAt;
    final resetTooRecent =
        lastResetAt != null &&
        now.difference(lastResetAt) < _minConnectionResetInterval;
    if (!force && (_inFlightRequests > 0 || resetTooRecent)) {
      ClientLogService.instance.add(
        type: 'http_connection_reset_skipped',
        level: 'info',
        message: 'Пропущен сброс HTTP-соединений',
        data: {
          'reason': reason,
          'inFlightRequests': _inFlightRequests,
          if (lastResetAt != null)
            'msSinceLastReset': now.difference(lastResetAt).inMilliseconds,
          'activeBaseUrl': activeBaseUrl,
        },
      );
      return;
    }

    final oldDio = _dio;
    _dio = _createDio();
    _closeDioQuietly(oldDio, force: force, reason: reason);
    _lastConnectionResetAt = now;
    ClientLogService.instance.httpConnectionReset(
      reason: reason,
      activeBaseUrl: activeBaseUrl,
      fallbackBaseUrl: ApiConfig.fallbackBaseUrl,
    );
    debugPrint(
      '[ApiClient] HTTP connections reset (force=$force, baseUrl=$activeBaseUrl)',
    );
  }

  void _restorePrimaryBaseUrlIfNeeded() {
    final activatedAt = _fallbackActivatedAt;
    if (!isUsingFallbackBaseUrl || activatedAt == null) return;
    if (DateTime.now().difference(activatedAt) < _fallbackTtl) return;

    _baseUrlOverride = null;
    _fallbackActivatedAt = null;
    final oldDio = _dio;
    _dio = _createDio();
    _closeDioQuietly(oldDio, force: true, reason: 'restore_primary_base_url');
    _lastConnectionResetAt = DateTime.now();
    ClientLogService.instance.add(
      type: 'api_base_url_primary_restore',
      level: 'info',
      message: 'Возвращаем API на основной домен после fallback TTL',
      data: {'baseUrl': ApiConfig.baseUrl},
    );
  }

  bool _switchToFallbackBaseUrl(DioException error) {
    final fallbackBaseUrl = ApiConfig.fallbackBaseUrl;
    if (fallbackBaseUrl == null || fallbackBaseUrl == activeBaseUrl) {
      return false;
    }
    if (!_isTransientNetworkError(error)) return false;

    _baseUrlOverride = fallbackBaseUrl;
    _fallbackActivatedAt = DateTime.now();
    final oldDio = _dio;
    _dio = _createDio();
    _closeDioQuietly(
      oldDio,
      force: true,
      reason: 'switch_to_fallback_base_url',
    );
    _lastConnectionResetAt = DateTime.now();
    ClientLogService.instance.add(
      type: 'api_base_url_fallback',
      level: 'warning',
      message: 'Переключаем API на резервный домен после сетевой ошибки',
      data: {
        'from': ApiConfig.baseUrl,
        'to': fallbackBaseUrl,
        'dioType': error.type.name,
        'path': error.requestOptions.path,
      },
    );
    return true;
  }

  void _closeDioQuietly(
    Dio dio, {
    required bool force,
    required String reason,
  }) {
    try {
      dio.close(force: force);
    } catch (error) {
      // Native URLSession/Cronet can throw while previous requests are still
      // winding down. Reset must remain best-effort: new Dio is already active,
      // and surfacing close() here crashes the app on resume.
      ClientLogService.instance.add(
        type: 'http_connection_close_failed',
        level: 'warning',
        message: 'Не удалось синхронно закрыть старый HTTP-клиент',
        data: {'reason': reason, 'force': force, 'error': error.toString()},
      );
      debugPrint('[ApiClient] Ignored Dio close error: $error');
    }
  }

  static bool _isTransientNetworkError(DioException e) {
    return e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.connectionError;
  }

  static bool _isPreSendError(DioException e) {
    return e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.sendTimeout;
  }

  Duration _effectiveOverallTimeout(Options? options) {
    final base = ApiConfig.overallRequestTimeout;
    final send = options?.sendTimeout ?? Duration.zero;
    final receive = options?.receiveTimeout ?? Duration.zero;
    if (send == Duration.zero && receive == Duration.zero) return base;

    final custom = (send + receive) * 2 + const Duration(seconds: 10);
    return custom > base ? custom : base;
  }

  Future<Response<T>> _withRetry<T>(
    Future<Response<T>> Function() fn, {
    required bool retryOnAllNetworkErrors,
    int maxAttempts = ApiConfig.maxRetries,
  }) async {
    DioException? lastError;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        return await fn();
      } on DioException catch (e) {
        final shouldRetry = retryOnAllNetworkErrors
            ? _isTransientNetworkError(e)
            : _isPreSendError(e);
        if (!shouldRetry || attempt == maxAttempts) rethrow;

        lastError = e;
        debugPrint(
          '[ApiClient] Network error (${e.type}), '
          'retry $attempt/$maxAttempts in ${ApiConfig.retryDelay.inMilliseconds}ms',
        );
        ClientLogService.instance.apiRetry(
          method: e.requestOptions.method,
          url: _safeRequestUrl(e.requestOptions),
          requestId: _requestId(e.requestOptions),
          attempt: attempt,
          maxAttempts: maxAttempts,
          error: e,
        );
        if (!_switchToFallbackBaseUrl(e)) {
          resetConnections(
            reason: 'retry_after_network_error_${e.type.name}',
            force:
                e.type == DioExceptionType.connectionTimeout ||
                e.type == DioExceptionType.connectionError,
          );
        }
        await Future<void>.delayed(ApiConfig.retryDelay);
      }
    }

    throw lastError ?? DioException(requestOptions: RequestOptions(path: ''));
  }

  Future<Response<T>> _request<T>(
    Future<Response<T>> Function(Dio dio) requestFn, {
    required String method,
    required String path,
    required bool idempotent,
    Options? options,
    bool allowRetry = true,
  }) async {
    _restorePrimaryBaseUrlIfNeeded();
    _inFlightRequests++;
    Future<Response<T>> run() {
      if (!allowRetry) return requestFn(_dio);
      return _withRetry(
        () => requestFn(_dio),
        retryOnAllNetworkErrors: idempotent,
      );
    }

    try {
      final timeout = _effectiveOverallTimeout(options);
      return await run().timeout(timeout);
    } on TimeoutException {
      ClientLogService.instance.apiTimeout(
        method: method,
        path: path,
        timeout: _effectiveOverallTimeout(options),
      );
      resetConnections(reason: 'overall_timeout', force: true);
      rethrow;
    } finally {
      _inFlightRequests--;
    }
  }

  Future<T> _runWithGetSlot<T>(String path, Future<T> Function() action) async {
    await _acquireGetSlot(path);
    try {
      return await action();
    } finally {
      _releaseGetSlot();
    }
  }

  Future<void> _acquireGetSlot(String path) async {
    if (_activeGetRequests < _maxConcurrentGetRequests) {
      _activeGetRequests++;
      return;
    }

    final completer = Completer<void>();
    _getRequestQueue.add(completer);
    ClientLogService.instance.add(
      type: 'api_get_queued',
      level: 'info',
      message: 'GET поставлен в очередь, чтобы не забивать mobile HTTP stack',
      data: {
        'path': path,
        'activeGetRequests': _activeGetRequests,
        'queuedGetRequests': _getRequestQueue.length,
        'maxConcurrentGetRequests': _maxConcurrentGetRequests,
      },
    );
    await completer.future;
    _activeGetRequests++;
  }

  void _releaseGetSlot() {
    if (_activeGetRequests > 0) {
      _activeGetRequests--;
    }
    if (_getRequestQueue.isEmpty) return;
    final next = _getRequestQueue.removeFirst();
    if (!next.isCompleted) {
      scheduleMicrotask(next.complete);
    }
  }

  /// Интерсептор для добавления токена авторизации
  Interceptor _authInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) async {
        if (options.data is FormData) {
          options.headers.remove(Headers.contentTypeHeader);
          options.headers.remove('Content-Type');
          options.headers.remove('content-type');
          // Dio appends the multipart boundary when it finalizes FormData.
          options.contentType = null;
        }

        final token = await getToken();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        // Помечаем, был ли у запроса токен, чтобы корректно обрабатывать 401.
        // Это важно: если токен не прочитался из Keychain/Keystore и мы отправили
        // запрос без Authorization, 401 НЕ должен приводить к очистке токена/логауту.
        options.extra['sent_auth_token'] = token != null && token.isNotEmpty;
        return handler.next(options);
      },
      onError: (error, handler) async {
        // Если 401 (unauthorized), вызываем callback
        // НО только если это НЕ запрос на /login (т.к. там 401 = неверный пароль)
        // и только если запрос был реально аутентифицирован (отправляли Authorization).
        if (error.response?.statusCode == 401) {
          final isLoginRequest = error.requestOptions.path.contains('/login');

          if (!isLoginRequest) {
            final sentAuth =
                error.requestOptions.extra['sent_auth_token'] == true ||
                _hasAuthorizationHeader(error.requestOptions);
            if (sentAuth) {
              ClientLogService.instance.add(
                type: 'auth_unauthorized',
                level: 'warning',
                message: 'Получен 401 для авторизованного запроса',
                requestId: _requestId(error.requestOptions),
                data: {
                  'path': _safeRequestPath(error.requestOptions),
                  'method': error.requestOptions.method,
                },
              );
              // Защита от "шторма" 401: если много запросов одновременно — callback один раз.
              _scheduleUnauthorizedCallback();
            } else {
              ClientLogService.instance.add(
                type: 'auth_unauthorized_without_token',
                level: 'warning',
                message: 'Получен 401 для запроса без Authorization',
                requestId: _requestId(error.requestOptions),
                data: {
                  'path': _safeRequestPath(error.requestOptions),
                  'method': error.requestOptions.method,
                },
              );
              if (kDebugMode) {
                debugPrint(
                  '401 received without Authorization header — skipping automatic logout '
                  '(path=${error.requestOptions.path})',
                );
              }
            }
          }
          // Если это login request, просто пробрасываем ошибку дальше
        }
        return handler.next(error);
      },
    );
  }

  void _scheduleUnauthorizedCallback() {
    if (_unauthorizedCallbackScheduled) return;
    _unauthorizedCallbackScheduled = true;

    void run() {
      try {
        _onUnauthorized?.call();
      } finally {
        _unauthorizedCallbackScheduled = false;
      }
    }

    // addPostFrameCallback не срабатывает, если кадры не рисуются (background).
    // Поэтому вызываем через microtask в idle фазе.
    final scheduler = SchedulerBinding.instance;
    if (scheduler.schedulerPhase == SchedulerPhase.idle) {
      Future.microtask(run);
    } else {
      scheduler.addPostFrameCallback((_) => run());
    }
  }

  bool _hasAuthorizationHeader(RequestOptions options) {
    for (final entry in options.headers.entries) {
      if (entry.key.toLowerCase() == 'authorization') return true;
    }
    return false;
  }

  Interceptor _clientTelemetryInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) async {
        final requestId = _nextRequestId();
        final startedAt = DateTime.now().millisecondsSinceEpoch;

        options.extra['client_log_request_id'] = requestId;
        options.extra['client_log_started_at'] = startedAt;
        options.headers['X-Request-ID'] = requestId;
        final operation = _businessOperation(options);
        if (operation != null) {
          options.extra['client_log_operation'] = operation;
        }

        try {
          options.headers.addAll(await AppRuntimeInfo.instance.headers());
        } catch (error) {
          await ClientLogService.instance.captureNonFatal(
            'Не удалось подготовить runtime headers',
            error: error,
            data: {'requestId': requestId, 'path': _safeRequestPath(options)},
          );
        }

        ClientLogService.instance.apiRequest(
          method: options.method,
          url: _safeRequestUrl(options),
          requestId: requestId,
          operation: operation,
        );

        return handler.next(options);
      },
      onResponse: (response, handler) {
        final options = response.requestOptions;
        final requestId = _responseRequestId(response, options);
        _consecutiveNetworkErrors = 0;
        ClientLogService.instance.apiResponse(
          method: options.method,
          url: _safeRequestUrl(options),
          requestId: requestId,
          statusCode: response.statusCode,
          durationMs: _durationMs(options),
          operation: _operation(options),
          nativeHttpClient: _nativeHttpClient(options),
        );
        return handler.next(response);
      },
      onError: (error, handler) async {
        final options = error.requestOptions;
        final requestId = _responseRequestId(error.response, options);
        ClientLogService.instance.apiError(
          method: options.method,
          url: _safeRequestUrl(options),
          requestId: requestId,
          statusCode: error.response?.statusCode,
          durationMs: _durationMs(options),
          type: error.type,
          error: _safeErrorMessage(error),
          operation: _operation(options),
          nativeHttpClient: _nativeHttpClient(options),
        );
        await _maybeReportNetworkErrorBurst(error);
        return handler.next(error);
      },
    );
  }

  Future<void> _maybeReportNetworkErrorBurst(DioException error) async {
    if (!_isTransientNetworkError(error)) {
      _consecutiveNetworkErrors = 0;
      return;
    }

    _consecutiveNetworkErrors++;
    if (_consecutiveNetworkErrors < 3) return;

    final now = DateTime.now();
    final lastReportedAt = _lastNetworkErrorReportAt;
    if (lastReportedAt != null &&
        now.difference(lastReportedAt) < const Duration(minutes: 10)) {
      return;
    }

    _lastNetworkErrorReportAt = now;
    await ClientLogService.instance.captureNonFatal(
      'Повторяющиеся сетевые ошибки API',
      error: error,
      stackTrace: error.stackTrace,
      data: {
        'dioType': error.type.name,
        'path': _safeRequestPath(error.requestOptions),
        'method': error.requestOptions.method,
        'activeBaseUrl': activeBaseUrl,
        'usingFallback': isUsingFallbackBaseUrl,
        if (_nativeHttpClient(error.requestOptions) != null)
          'nativeHttpClient': _nativeHttpClient(error.requestOptions),
        'networkErrorCount': _consecutiveNetworkErrors,
      },
    );
  }

  String _nextRequestId() {
    _requestSequence = (_requestSequence + 1) % 1000000;
    return 'req_${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}_${_requestSequence.toRadixString(36)}';
  }

  String _responseRequestId(
    Response<dynamic>? response,
    RequestOptions options,
  ) {
    final value = response?.headers.value('x-request-id')?.trim();
    if (value != null && value.isNotEmpty) return value;
    return _requestId(options);
  }

  String _requestId(RequestOptions options) {
    final value = options.extra['client_log_request_id'];
    return value is String && value.isNotEmpty ? value : 'unknown';
  }

  String? _operation(RequestOptions options) {
    final value = options.extra['client_log_operation'];
    return value is String && value.isNotEmpty ? value : null;
  }

  String? _nativeHttpClient(RequestOptions options) {
    final value = options.extra['native_http_client'];
    return value is String && value.isNotEmpty ? value : null;
  }

  int _durationMs(RequestOptions options) {
    final startedAt = options.extra['client_log_started_at'];
    if (startedAt is! int) return 0;
    final duration = DateTime.now().millisecondsSinceEpoch - startedAt;
    return duration < 0 ? 0 : duration;
  }

  String _safeErrorMessage(DioException error) {
    final statusCode = error.response?.statusCode;
    final message = error.message;
    if (statusCode == null) {
      return message ?? error.type.name;
    }
    return message == null || message.isEmpty
        ? 'HTTP $statusCode'
        : 'HTTP $statusCode: $message';
  }

  /// Sentry интерсептор для отслеживания HTTP ошибок
  Interceptor _sentryInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) async {
        await _addHttpBreadcrumb(
          level: SentryLevel.info,
          message: 'HTTP ${options.method} ${_safeRequestPath(options)}',
          requestOptions: options,
        );
        return handler.next(options);
      },
      onResponse: (response, handler) async {
        final statusCode = response.statusCode;
        if (statusCode != null && statusCode >= 400) {
          await _addHttpBreadcrumb(
            level: statusCode >= 500 ? SentryLevel.error : SentryLevel.warning,
            message:
                'HTTP ${response.requestOptions.method} ${_safeRequestPath(response.requestOptions)} -> $statusCode',
            requestOptions: response.requestOptions,
            statusCode: statusCode,
          );
        }
        return handler.next(response);
      },
      onError: (error, handler) async {
        final statusCode = error.response?.statusCode;

        await _addHttpBreadcrumb(
          level: statusCode != null && statusCode >= 500
              ? SentryLevel.error
              : SentryLevel.warning,
          message:
              'HTTP ${error.requestOptions.method} ${_safeRequestPath(error.requestOptions)} failed',
          requestOptions: error.requestOptions,
          statusCode: statusCode,
          extra: {'dio_type': error.type.name},
        );

        // В Sentry отправляем только серверные ошибки. Сетевые таймауты,
        // VPN/DPI/China routes и офлайн-сценарии остаются breadcrumbs.
        if (statusCode != null &&
            statusCode >= 500 &&
            !_isLowPriorityHttpError(error.requestOptions)) {
          // Audit M3 (2026-04-26): не отправляем response body в Sentry,
          // чтобы случайно не утекли чувствительные поля бэкенд-ошибок.
          await Sentry.captureException(
            error,
            stackTrace: error.stackTrace,
            hint: Hint.withMap({
              'keep_http_error': true,
              'type': 'http_5xx',
              'method': error.requestOptions.method,
              'path': _safeRequestPath(error.requestOptions),
              'status_code': statusCode,
            }),
          );
        }

        return handler.next(error);
      },
    );
  }

  Future<void> _addHttpBreadcrumb({
    required SentryLevel level,
    required String message,
    required RequestOptions requestOptions,
    int? statusCode,
    Map<String, dynamic>? extra,
  }) {
    final data = <String, dynamic>{
      'method': requestOptions.method,
      'path': _safeRequestPath(requestOptions),
      if (_operation(requestOptions) != null)
        'operation': _operation(requestOptions),
      if (_nativeHttpClient(requestOptions) != null)
        'native_http_client': _nativeHttpClient(requestOptions),
      if (statusCode != null) 'status_code': statusCode,
      if (extra != null) ...extra,
    };

    return Sentry.addBreadcrumb(
      Breadcrumb(message: message, category: 'http', level: level, data: data),
    );
  }

  String _safeRequestPath(RequestOptions options) {
    return options.uri.path.isNotEmpty ? options.uri.path : options.path;
  }

  bool _isLowPriorityHttpError(RequestOptions options) {
    final path = _safeRequestPath(options);
    return path == '/api/client/chat-presence';
  }

  String _safeRequestUrl(RequestOptions options) {
    final uri = options.uri;
    final path = uri.path.isNotEmpty ? uri.path : options.path;
    if (uri.queryParameters.isEmpty) return path;

    final params = <String, String>{};
    uri.queryParameters.forEach((key, value) {
      params[key] = _isSensitiveQueryKey(key) ? '<redacted>' : value;
    });

    final query = Uri(queryParameters: params).query;
    return query.isEmpty ? path : '$path?$query';
  }

  bool _isSensitiveQueryKey(String key) {
    final lower = key.toLowerCase();
    return lower.contains('token') ||
        lower.contains('password') ||
        lower.contains('secret') ||
        lower == 'email' ||
        lower == 'phone' ||
        lower == 'message' ||
        lower == 'comment' ||
        lower == 'description';
  }

  String? _businessOperation(RequestOptions options) {
    final method = options.method.toUpperCase();
    final path = _safeRequestPath(options);

    if (method == 'POST' && path == '/client/tracks') {
      return 'Добавление треков';
    }
    if (method == 'POST' && path == '/photo-requests') {
      return 'Создание запроса фотоотчета';
    }
    if (method == 'PATCH' && _matches(path, r'^/photo-requests/[^/]+$')) {
      return 'Обновление запроса фотоотчета';
    }
    if (method == 'POST' && path == '/track-questions') {
      return 'Создание вопроса по треку';
    }
    if (method == 'PATCH' && _matches(path, r'^/track-questions/[^/]+$')) {
      return 'Обновление вопроса по треку';
    }
    if (method == 'POST' && _matches(path, r'^/client/tracks/[^/]+/return$')) {
      return 'Оформление возврата трека';
    }
    if (method == 'PUT' && _matches(path, r'^/tracks/[^/]+$')) {
      return 'Обновление информации о товаре';
    }
    if (method == 'PATCH' && _matches(path, r'^/tracks/[^/]+$')) {
      return 'Обновление заметки трека';
    }
    if (method == 'DELETE' && _matches(path, r'^/tracks/[^/]+$')) {
      return 'Удаление трека';
    }
    if (method == 'POST' &&
        _matches(path, r'^/tracks/[^/]+/product-info-image$')) {
      return 'Загрузка фото товара';
    }
    if (method == 'POST' && path == '/assemblies') {
      return 'Создание сборки';
    }
    if (method == 'POST' && _matches(path, r'^/assemblies/[^/]+/tracks$')) {
      return 'Добавление треков в сборку';
    }
    if (method == 'DELETE' && _matches(path, r'^/assemblies/[^/]+/tracks$')) {
      return 'Удаление треков из сборки';
    }
    if (method == 'PATCH' && _matches(path, r'^/assemblies/[^/]+$')) {
      return 'Обновление сборки';
    }
    if (method == 'POST' &&
        _matches(path, r'^/client/invoices/[^/]+/request-payment$')) {
      return 'Запрос оплаты счета';
    }
    if (method == 'POST' &&
        _matches(path, r'^/client/invoices/[^/]+/apply-bonus$')) {
      return 'Применение бонусных кг к счету';
    }
    if (method == 'POST' && path == '/payments/pally/create') {
      return 'Создание онлайн-оплаты';
    }
    if (method == 'POST' && path == '/payments/usdt/create') {
      return 'Создание USDT-оплаты';
    }
    if (method == 'POST' && path == '/client/purchase-blanks') {
      return 'Создание бланка выкупа';
    }
    if (method == 'POST' &&
        _matches(path, r'^/client/purchase-blanks/[^/]+/submit$')) {
      return 'Отправка бланка выкупа';
    }
    if (method == 'POST' &&
        _matches(path, r'^/client/purchase-blanks/[^/]+/cancel$')) {
      return 'Отмена бланка выкупа';
    }
    if (method == 'POST' &&
        _matches(path, r'^/client/purchase-blanks/[^/]+/items$')) {
      return 'Добавление товара в бланк выкупа';
    }
    if ((method == 'PUT' || method == 'DELETE') &&
        _matches(path, r'^/client/purchase-blanks/[^/]+/items/[^/]+$')) {
      return method == 'PUT'
          ? 'Редактирование товара в бланке выкупа'
          : 'Удаление товара из бланка выкупа';
    }
    if (method == 'POST' &&
        _matches(path, r'^/client/purchase-blanks/[^/]+/items/[^/]+/photos$')) {
      return 'Загрузка фото товара в бланке выкупа';
    }
    if (method == 'PATCH' && path == '/client/profile') {
      return 'Обновление профиля';
    }
    if (method == 'POST' && path == '/client/profile') {
      return 'Изменение профиля';
    }
    if (method == 'POST' && path == '/client/problem-reports') {
      return 'Отправка отчета о проблеме';
    }
    if (method == 'POST' && path == '/client/referral/link') {
      return 'Привязка реферального кода';
    }
    if (method == 'POST' && _matches(path, r'^/client/chat(/.*)?$')) {
      return 'Отправка сообщения в поддержку';
    }
    if (method == 'POST' && _matches(path, r'^/client/payment-chat(/.*)?$')) {
      return 'Отправка сообщения в чат оплаты';
    }
    if (method == 'POST' && path == '/support/attachments') {
      return 'Загрузка файла в чат поддержки';
    }
    if (method == 'POST' && path == '/client/payment-chat/attachments') {
      return 'Загрузка файла в чат оплаты';
    }
    if (method == 'PATCH' && path == '/notifications') {
      return 'Обновление уведомлений';
    }
    if (method == 'POST' && path == '/photos/upload') {
      return 'Загрузка фото';
    }
    if (method == 'PATCH' && _matches(path, r'^/client/sp/assemblies/[^/]+$')) {
      return 'Обновление совместной покупки';
    }
    if (method == 'PATCH' && _matches(path, r'^/client/sp/tracks/[^/]+$')) {
      return 'Обновление трека совместной покупки';
    }
    if (method == 'POST' &&
        _matches(path, r'^/client/sp/assemblies/[^/]+/participant-payment$')) {
      return 'Обновление оплаты участника совместной покупки';
    }
    if (method == 'POST' &&
        _matches(path, r'^/client/sp/assemblies/[^/]+/apply-rate$')) {
      return 'Применение курса совместной покупки';
    }
    if (method == 'POST' &&
        _matches(path, r'^/client/sp/assemblies/[^/]+/calculate-shipping$')) {
      return 'Расчет доставки совместной покупки';
    }
    if (method == 'POST' && path == '/shop/purchase-lists') {
      return 'Создание списка совместной покупки';
    }
    if (method == 'POST' &&
        _matches(path, r'^/shop/purchase-lists/[^/]+/items$')) {
      return 'Добавление товара в совместную покупку';
    }
    if ((method == 'PATCH' || method == 'DELETE') &&
        _matches(path, r'^/shop/purchase-lists/[^/]+/items/[^/]+$')) {
      return method == 'PATCH'
          ? 'Редактирование товара в совместной покупке'
          : 'Удаление товара из совместной покупки';
    }
    if (method == 'POST' &&
        _matches(path, r'^/shop/purchase-lists/[^/]+/submit$')) {
      return 'Отправка совместной покупки';
    }
    if (method == 'POST' && path == '/client-codes/link-by-pin') {
      return 'Привязка кода клиента';
    }
    if (method == 'POST' && path == '/devices') {
      return 'Регистрация устройства для push';
    }
    if (method == 'DELETE' && path == '/devices') {
      return 'Удаление устройства для push';
    }
    if (method == 'POST' && path == '/registration-requests') {
      return 'Отправка заявки на регистрацию';
    }
    if (method == 'POST' && path == '/password-reset/request') {
      return 'Запрос восстановления пароля';
    }
    if (method == 'POST' && path == '/password-reset/verify') {
      return 'Проверка восстановления пароля';
    }
    if (method == 'POST' && path == '/password-reset/complete') {
      return 'Завершение восстановления пароля';
    }
    if (method == 'POST' && path == '/register') {
      return 'Регистрация клиента';
    }
    if (method == 'POST' && path == '/login') {
      return 'Авторизация клиента';
    }
    if (method == 'POST' && path.startsWith('/client/passkeys/')) {
      return 'Авторизация клиента через passkey';
    }

    return null;
  }

  bool _matches(String path, String pattern) {
    return RegExp(pattern).hasMatch(path);
  }

  /// Логирование запросов (только в debug)
  Interceptor _loggingInterceptor() {
    return LogInterceptor(
      request: true,
      requestHeader: false,
      requestBody: false,
      responseHeader: false,
      responseBody: false,
      error: true,
      logPrint: (object) => debugPrint(_sanitizeLogLine(object.toString())),
    );
  }

  String _sanitizeLogLine(String message) {
    return message
        .replaceAll(
          RegExp(r'(Authorization:\s*Bearer\s+)[^\s,}]+', caseSensitive: false),
          r'$1<redacted>',
        )
        .replaceAll(
          RegExp(r'("token"\s*:\s*")[^"]+(")', caseSensitive: false),
          r'$1<redacted>$2',
        )
        .replaceAll(
          RegExp(r'(token:\s*)[^,\n}]+', caseSensitive: false),
          r'$1<redacted>',
        );
  }

  // Token management
  Future<String?> getToken() async {
    // Сначала проверяем кеш в памяти
    final cached = _inMemoryToken;
    if (cached != null) return cached;

    // Single-flight: при одновременных запросах не дергаем storage многократно.
    final inFlight = _tokenLoadInFlight;
    if (inFlight != null) return inFlight;

    final future = _loadTokenFromStorage();
    _tokenLoadInFlight = future;
    try {
      final token = await future;
      if (token != null && token.isNotEmpty) {
        _inMemoryToken = token;
      }
      return token;
    } finally {
      // Сбрасываем in-flight даже при ошибках/таймаутах.
      if (identical(_tokenLoadInFlight, future)) {
        _tokenLoadInFlight = null;
      }
    }
  }

  Future<String?> _loadTokenFromStorage() async {
    // На web и desktop используем SharedPreferences (localStorage).
    if (kIsWeb || _isDesktop) {
      return _readTokenFromPrefs();
    }

    // iOS Keychain достаточно стабилен, поэтому для iOS сначала пробуем
    // защищённое хранилище и только потом legacy mirror. Android оставляем на
    // быстром mirror: на части старых Huawei/Xiaomi Keystore может запускать
    // долгую миграцию FlutterSecureStorage и блокировать старт.
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final secureToken = await _readTokenFromSecureStorage();
      if (secureToken != null && secureToken.isNotEmpty) {
        return secureToken;
      }
    }

    final mirroredToken = await _readTokenFromPrefs();
    if (mirroredToken != null && mirroredToken.isNotEmpty) {
      if (kDebugMode) {
        debugPrint('🔐 Token loaded from SharedPreferences mirror');
      }
      return mirroredToken;
    }

    // Если приложение само помнит, что пользователь не авторизован, не трогаем
    // SecureStorage вообще. Иначе даже экран входа может получить 5-секундный
    // timeout из-за фонового clientProfileProvider.hasTokenAsync().
    final shouldProbeSecureStorage = await _shouldProbeSecureStorageForToken();
    if (!shouldProbeSecureStorage) {
      return null;
    }

    return _readTokenFromSecureStorage();
  }

  Future<bool> _shouldProbeSecureStorageForToken() async {
    try {
      final prefs = await SharedPreferences.getInstance().timeout(
        _prefsTimeout,
      );
      return prefs.getBool(_isLoggedInPrefsKey) == true;
    } catch (e) {
      // Если SharedPreferences временно недоступны, лучше попробовать SecureStorage:
      // там может лежать единственная копия токена после обновления старой версии.
      ClientLogService.instance.add(
        type: 'storage_error',
        level: 'warning',
        message: 'Не удалось прочитать флаг авторизации из SharedPreferences',
        data: {'error': e.toString()},
      );
      debugPrint('Error/timeout reading auth flag from SharedPreferences: $e');
      return true;
    }
  }

  Future<String?> _readTokenFromSecureStorage() async {
    try {
      // Таймаут 5 сек оставляем только для legacy-сценария: пользователь был
      // авторизован в старой версии, где mirror в SharedPreferences ещё не было.
      final token = await _storage
          .read(key: _tokenKey)
          .timeout(const Duration(seconds: 5));
      if (token != null && token.isNotEmpty) {
        // Делаем best-effort копию в SharedPreferences, чтобы следующие старты
        // Android больше не зависели от Keystore. На iOS mirror не создаём:
        // Keychain должен оставаться единственным постоянным хранилищем токена.
        if (defaultTargetPlatform != TargetPlatform.iOS) {
          unawaited(_writeTokenToPrefs(token));
        }
        return token;
      }
    } catch (e) {
      // PlatformException может быть транзиентной (iOS Keychain до первой
      // разблокировки, Android Keystore после обновления алгоритма и т.д.).
      ClientLogService.instance.add(
        type: 'storage_error',
        level: 'warning',
        message: 'Не удалось прочитать токен из SecureStorage',
        data: {'error': e.toString()},
      );
      debugPrint('Error/timeout reading token from SecureStorage: $e');
    }

    return null;
  }

  Future<String?> _readTokenFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance().timeout(
        _prefsTimeout,
      );
      return prefs.getString(_tokenKey);
    } catch (e) {
      ClientLogService.instance.add(
        type: 'storage_error',
        level: 'warning',
        message: 'Не удалось прочитать токен из SharedPreferences',
        data: {'error': e.toString()},
      );
      debugPrint('Error/timeout reading token from SharedPreferences: $e');
      return null;
    }
  }

  Future<void> _writeTokenToPrefs(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance().timeout(
        _prefsTimeout,
      );
      await prefs.setString(_tokenKey, token);
    } catch (e) {
      ClientLogService.instance.add(
        type: 'storage_error',
        level: 'warning',
        message: 'Не удалось сохранить токен в SharedPreferences',
        data: {'error': e.toString()},
      );
      debugPrint('Error/timeout saving token to SharedPreferences: $e');
    }
  }

  Future<void> _removeTokenFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance().timeout(
        _prefsTimeout,
      );
      await prefs.remove(_tokenKey);
    } catch (e) {
      ClientLogService.instance.add(
        type: 'storage_error',
        level: 'warning',
        message: 'Не удалось очистить токен в SharedPreferences',
        data: {'error': e.toString()},
      );
      debugPrint('Error/timeout clearing token from SharedPreferences: $e');
    }
  }

  Future<void> setToken(String token) async {
    // Кешируем в памяти
    _inMemoryToken = token;
    // Сбрасываем single-flight, чтобы следующий getToken не ждал старую попытку.
    _tokenLoadInFlight = null;

    // На web и desktop сохраняем в SharedPreferences (localStorage)
    if (kIsWeb || _isDesktop) {
      await _writeTokenToPrefs(token);
      ClientLogService.instance.action(
        'Токен сохранён',
        data: {'storage': 'prefs'},
      );
      debugPrint('Token saved to localStorage');
      return;
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final secureSaved = await _writeTokenToSecureStorage(token);
      if (secureSaved) {
        // Если пользователь обновился со старой версии с mirror — убираем копию
        // из SharedPreferences, чтобы на iOS токен оставался только в Keychain.
        await _removeTokenFromPrefs();
        return;
      }

      // Fallback на случай редкой транзиентной ошибки Keychain: лучше сохранить
      // сессию, чем сломать вход. Следующий успешный secure read/write удалит mirror.
      await _writeTokenToPrefs(token);
      ClientLogService.instance.action(
        'Токен сохранён',
        data: {'storage': 'prefs_mirror_fallback'},
      );
      return;
    }

    // На Android сначала пишем быстрый mirror в SharedPreferences.
    // Причина: на части устройств чтение/запись SecureStorage бывает транзиентно
    // недоступно (Keychain/Keystore). Без mirror это выглядит как "слёт авторизации"
    // или как долгий вход после обновления приложения.
    await _writeTokenToPrefs(token);
    ClientLogService.instance.action(
      'Токен сохранён',
      data: {'storage': 'prefs_mirror'},
    );

    // SecureStorage синхронизируем best-effort в фоне, чтобы вход не ждал
    // Android Keystore/EncryptedSharedPreferences.
    unawaited(_writeTokenToSecureStorage(token).then((_) {}));
  }

  Future<bool> _writeTokenToSecureStorage(String token) async {
    try {
      // Таймаут 5 сек: при первой записи после переустановки EncryptedSharedPreferences
      // может зависнуть на Android при генерации ключей шифрования.
      await _storage
          .write(key: _tokenKey, value: token)
          .timeout(const Duration(seconds: 5));
      ClientLogService.instance.action(
        'Токен сохранён',
        data: {'storage': 'secure_storage'},
      );
      debugPrint('Token saved to SecureStorage');
      return true;
    } catch (e) {
      ClientLogService.instance.add(
        type: 'storage_error',
        level: 'warning',
        message: 'Не удалось сохранить токен в SecureStorage',
        data: {'error': e.toString()},
      );
      debugPrint('Error/timeout saving token to SecureStorage: $e');
      return false;
    }
  }

  Future<void> clearToken() async {
    _inMemoryToken = null;
    _tokenLoadInFlight = null;

    // На web и desktop удаляем из SharedPreferences
    if (kIsWeb || _isDesktop) {
      await _removeTokenFromPrefs();
      ClientLogService.instance.action(
        'Токен очищен',
        data: {'storage': 'prefs'},
      );
      debugPrint('Token cleared from localStorage');
      return;
    }

    // Сначала чистим mirror в SharedPreferences: именно он теперь быстрый
    // источник токена на мобильных устройствах.
    await _removeTokenFromPrefs();

    // Затем удаляем из FlutterSecureStorage. Если Keystore зависнет, быстрый mirror
    // уже очищен, поэтому следующий запуск не восстановит старую авторизацию.
    try {
      await _storage.delete(key: _tokenKey).timeout(const Duration(seconds: 5));
      ClientLogService.instance.action(
        'Токен очищен',
        data: {'storage': 'secure_storage'},
      );
      debugPrint('Token cleared from SecureStorage');
    } catch (e) {
      ClientLogService.instance.add(
        type: 'storage_error',
        level: 'warning',
        message: 'Не удалось очистить токен в SecureStorage',
        data: {'error': e.toString()},
      );
      debugPrint('Error/timeout clearing token from SecureStorage: $e');
    }
  }

  /// Проверка на Desktop платформу
  bool get _isDesktop {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  /// Проверка наличия токена (синхронная, проверяет только кеш в памяти)
  bool get hasToken => _inMemoryToken != null && _inMemoryToken!.isNotEmpty;

  /// Проверка наличия токена (асинхронная, проверяет и localStorage)
  Future<bool> hasTokenAsync() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  // HTTP methods

  /// GET запрос
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return _runWithGetSlot(
      path,
      () => _request(
        (dio) => dio.get<T>(
          path,
          queryParameters: queryParameters,
          options: options,
        ),
        method: 'GET',
        path: path,
        idempotent: true,
        options: options,
      ),
    );
  }

  /// POST запрос
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    if (data is FormData) {
      return _request(
        (dio) => dio.post<T>(
          path,
          data: data,
          queryParameters: queryParameters,
          options: options,
        ),
        method: 'POST',
        path: path,
        idempotent: false,
        options: options,
        allowRetry: false,
      );
    }

    return _request(
      (dio) => dio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      ),
      method: 'POST',
      path: path,
      idempotent: false,
      options: options,
    );
  }

  /// PUT запрос
  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return _request(
      (dio) => dio.put<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      ),
      method: 'PUT',
      path: path,
      idempotent: false,
      options: options,
    );
  }

  /// PATCH запрос
  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return _request(
      (dio) => dio.patch<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      ),
      method: 'PATCH',
      path: path,
      idempotent: false,
      options: options,
    );
  }

  /// DELETE запрос
  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return _request(
      (dio) => dio.delete<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      ),
      method: 'DELETE',
      path: path,
      idempotent: false,
      options: options,
    );
  }

  /// Загрузка файла (multipart)
  Future<Response<T>> uploadFile<T>(
    String path, {
    required String filePath,
    required String fieldName,
    Map<String, dynamic>? data,
    void Function(int, int)? onSendProgress,
  }) async {
    final formData = FormData.fromMap({
      ...?data,
      fieldName: await MultipartFile.fromFile(filePath),
    });

    final uploadOptions = Options(
      sendTimeout: const Duration(minutes: 2),
      receiveTimeout: const Duration(minutes: 2),
    );

    return _request(
      (dio) => dio.post<T>(
        path,
        data: formData,
        options: uploadOptions,
        onSendProgress: onSendProgress,
      ),
      method: 'POST',
      path: path,
      idempotent: false,
      options: uploadOptions,
    );
  }
}
