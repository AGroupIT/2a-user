import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/sentry_config.dart';
import 'api_config.dart';

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

  // In-memory fallback для web и desktop
  static String? _inMemoryToken;
  static Future<String?>? _tokenLoadInFlight;
  static const Duration _prefsTimeout = Duration(seconds: 3);

  // Callback для обработки 401 unauthorized
  OnUnauthorizedCallback? _onUnauthorized;
  bool _unauthorizedCallbackScheduled = false;

  /// Установить callback для обработки 401 ошибки
  void setOnUnauthorizedCallback(OnUnauthorizedCallback callback) {
    _onUnauthorized = callback;
  }

  ApiClient() {
    _dio = _createDio();
  }

  Dio _createDio() {
    final dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
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

    // Добавляем интерсепторы
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
  void resetConnections() {
    final oldDio = _dio;
    _dio = _createDio();
    oldDio.close(force: true);
    debugPrint('[ApiClient] HTTP connections reset');
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
        resetConnections();
        await Future<void>.delayed(ApiConfig.retryDelay);
      }
    }

    throw lastError ?? DioException(requestOptions: RequestOptions(path: ''));
  }

  Future<Response<T>> _request<T>(
    Future<Response<T>> Function(Dio dio) requestFn, {
    required bool idempotent,
    Options? options,
    bool allowRetry = true,
  }) async {
    Future<Response<T>> run() {
      if (!allowRetry) return requestFn(_dio);
      return _withRetry(
        () => requestFn(_dio),
        retryOnAllNetworkErrors: idempotent,
      );
    }

    try {
      return await run().timeout(_effectiveOverallTimeout(options));
    } on TimeoutException {
      resetConnections();
      rethrow;
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
              // Защита от "шторма" 401: если много запросов одновременно — callback один раз.
              _scheduleUnauthorizedCallback();
            } else {
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

  /// Sentry интерсептор для отслеживания HTTP ошибок
  Interceptor _sentryInterceptor() {
    return InterceptorsWrapper(
      onError: (error, handler) async {
        // Отправляем только серверные ошибки (5xx) и сетевые ошибки
        final statusCode = error.response?.statusCode;
        final shouldReport =
            statusCode == null || // Сетевая ошибка
            statusCode >= 500; // Серверная ошибка

        if (shouldReport) {
          // Audit M3 (2026-04-26): не отправляем response body в Sentry,
          // чтобы случайно не утекли чувствительные поля бэкенд-ошибок.
          await Sentry.captureException(
            error,
            stackTrace: error.stackTrace,
            hint: Hint.withMap({
              'type': 'http_error',
              'url': error.requestOptions.uri.toString(),
              'method': error.requestOptions.method,
              'status_code': statusCode,
            }),
          );

          // Добавляем breadcrumb для контекста
          Sentry.addBreadcrumb(
            Breadcrumb(
              message:
                  'API Error: ${error.requestOptions.method} ${error.requestOptions.path}',
              category: 'http',
              level: SentryLevel.error,
              data: {
                'status_code': statusCode,
                'url': error.requestOptions.uri.toString(),
              },
            ),
          );
        }

        return handler.next(error);
      },
    );
  }

  /// Логирование запросов (только в debug)
  Interceptor _loggingInterceptor() {
    return LogInterceptor(
      request: true,
      requestHeader: true,
      requestBody: true,
      responseHeader: false,
      responseBody: true,
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
    // На web и desktop используем SharedPreferences (localStorage)
    if (kIsWeb || _isDesktop) {
      return _readTokenFromPrefs();
    }

    // На мобильных платформах пытаемся читать из SecureStorage,
    // а при ошибке/таймауте — fallback в SharedPreferences.
    try {
      // Таймаут 5 сек: на некоторых Android устройствах EncryptedSharedPreferences
      // может зависнуть при первом обращении (генерация ключей шифрования).
      final token = await _storage
          .read(key: _tokenKey)
          .timeout(const Duration(seconds: 5));
      if (token != null && token.isNotEmpty) {
        // Делаем best-effort копию в SharedPreferences, чтобы переживать
        // транзиентные ошибки Keychain/Keystore без повторного логина.
        unawaited(_writeTokenToPrefs(token));
        return token;
      }
    } catch (e) {
      // PlatformException может быть транзиентной (iOS Keychain до первой разблокировки,
      // после обновления приложения и т.д.).
      debugPrint('Error/timeout reading token from SecureStorage: $e');
    }

    final fallback = await _readTokenFromPrefs();
    if (fallback != null && fallback.isNotEmpty) {
      debugPrint('🔐 Token loaded from SharedPreferences fallback');
    }
    return fallback;
  }

  Future<String?> _readTokenFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance().timeout(
        _prefsTimeout,
      );
      return prefs.getString(_tokenKey);
    } catch (e) {
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
      debugPrint('Token saved to localStorage');
      return;
    }

    // На мобильных платформах используем FlutterSecureStorage
    try {
      // Таймаут 5 сек: при первой записи после переустановки EncryptedSharedPreferences
      // может зависнуть на Android при генерации ключей шифрования.
      // Токен уже в памяти (_inMemoryToken), поэтому таймаут не ломает авторизацию.
      await _storage
          .write(key: _tokenKey, value: token)
          .timeout(const Duration(seconds: 5));
      debugPrint('Token saved to SecureStorage');
    } catch (e) {
      debugPrint('Error/timeout saving token to SecureStorage: $e');
    }

    // Fallback: дублируем токен в SharedPreferences.
    // Причина: на части устройств чтение/запись SecureStorage бывает транзиентно
    // недоступно (Keychain/Keystore). Без fallback это выглядит как "слёт авторизации".
    await _writeTokenToPrefs(token);
  }

  Future<void> clearToken() async {
    _inMemoryToken = null;
    _tokenLoadInFlight = null;

    // На web и desktop удаляем из SharedPreferences
    if (kIsWeb || _isDesktop) {
      await _removeTokenFromPrefs();
      debugPrint('Token cleared from localStorage');
      return;
    }

    // На мобильных платформах удаляем из FlutterSecureStorage
    try {
      await _storage.delete(key: _tokenKey).timeout(const Duration(seconds: 5));
      debugPrint('Token cleared from SecureStorage');
    } catch (e) {
      debugPrint('Error/timeout clearing token from SecureStorage: $e');
    }

    // Также чистим fallback в SharedPreferences (если использовался)
    await _removeTokenFromPrefs();
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
    return _request(
      (dio) =>
          dio.get<T>(path, queryParameters: queryParameters, options: options),
      idempotent: true,
      options: options,
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
      idempotent: false,
      options: uploadOptions,
    );
  }
}
