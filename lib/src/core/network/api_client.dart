import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
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
  late final Dio _dio;
  // На мобильных платформах используем FlutterSecureStorage с правильными настройками
  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );
  static const String _tokenKey = 'auth_token';
  
  // In-memory fallback для web и desktop
  static String? _inMemoryToken;
  
  // Callback для обработки 401 unauthorized
  OnUnauthorizedCallback? _onUnauthorized;
  
  /// Установить callback для обработки 401 ошибки
  void setOnUnauthorizedCallback(OnUnauthorizedCallback callback) {
    _onUnauthorized = callback;
  }

  ApiClient() {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: ApiConfig.connectTimeout,
        receiveTimeout: ApiConfig.receiveTimeout,
        headers: ApiConfig.defaultHeaders,
      ),
    );

    // Добавляем интерсепторы
    _dio.interceptors.add(_authInterceptor());

    // Sentry interceptor для отслеживания HTTP ошибок
    if (SentryConfig.enabled) {
      _dio.interceptors.add(_sentryInterceptor());
    }

    if (kDebugMode) {
      _dio.interceptors.add(_loggingInterceptor());
    }
  }

  /// Интерсептор для добавления токена авторизации
  Interceptor _authInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await getToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (error, handler) async {
        // Если 401 (unauthorized), очищаем токен и вызываем callback
        // НО только если это НЕ запрос на /login (т.к. там 401 = неверный пароль)
        if (error.response?.statusCode == 401) {
          final isLoginRequest = error.requestOptions.path.contains('/login');

          if (!isLoginRequest) {
            // Это не login, значит токен истёк - делаем logout
            await clearToken();
            // Вызываем callback для logout и редиректа
            _onUnauthorized?.call();
          }
          // Если это login request, просто пробрасываем ошибку дальше
        }
        return handler.next(error);
      },
    );
  }

  /// Sentry интерсептор для отслеживания HTTP ошибок
  Interceptor _sentryInterceptor() {
    return InterceptorsWrapper(
      onError: (error, handler) async {
        // Отправляем только серверные ошибки (5xx) и сетевые ошибки
        final statusCode = error.response?.statusCode;
        final shouldReport = statusCode == null || // Сетевая ошибка
            statusCode >= 500; // Серверная ошибка

        if (shouldReport) {
          await Sentry.captureException(
            error,
            stackTrace: error.stackTrace,
            hint: Hint.withMap({
              'type': 'http_error',
              'url': error.requestOptions.uri.toString(),
              'method': error.requestOptions.method,
              'status_code': statusCode,
              'response_data': error.response?.data,
            }),
          );

          // Добавляем breadcrumb для контекста
          Sentry.addBreadcrumb(
            Breadcrumb(
              message: 'API Error: ${error.requestOptions.method} ${error.requestOptions.path}',
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
      logPrint: (object) => debugPrint(object.toString()),
    );
  }

  // Token management
  Future<String?> getToken() async {
    // Сначала проверяем кеш в памяти
    if (_inMemoryToken != null) {
      return _inMemoryToken;
    }

    // На web и desktop используем SharedPreferences (localStorage)
    if (kIsWeb || _isDesktop) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString(_tokenKey);
        _inMemoryToken = token; // Кешируем
        return token;
      } catch (e) {
        debugPrint('Error reading token from SharedPreferences: $e');
        return null;
      }
    }

    // На мобильных платформах используем FlutterSecureStorage
    try {
      final token = await _storage.read(key: _tokenKey);
      _inMemoryToken = token; // Кешируем
      return token;
    } catch (e) {
      debugPrint('Error reading token from SecureStorage: $e');
      return null;
    }
  }

  Future<void> setToken(String token) async {
    // Кешируем в памяти
    _inMemoryToken = token;

    // На web и desktop сохраняем в SharedPreferences (localStorage)
    if (kIsWeb || _isDesktop) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_tokenKey, token);
        debugPrint('Token saved to localStorage');
      } catch (e) {
        debugPrint('Error saving token to SharedPreferences: $e');
      }
      return;
    }

    // На мобильных платформах используем FlutterSecureStorage
    try {
      await _storage.write(key: _tokenKey, value: token);
      debugPrint('Token saved to SecureStorage');
    } catch (e) {
      debugPrint('Error saving token to SecureStorage: $e');
    }
  }

  Future<void> clearToken() async {
    _inMemoryToken = null;

    // На web и desktop удаляем из SharedPreferences
    if (kIsWeb || _isDesktop) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_tokenKey);
        debugPrint('Token cleared from localStorage');
      } catch (e) {
        debugPrint('Error clearing token from SharedPreferences: $e');
      }
      return;
    }

    // На мобильных платформах удаляем из FlutterSecureStorage
    try {
      await _storage.delete(key: _tokenKey);
      debugPrint('Token cleared from SecureStorage');
    } catch (e) {
      debugPrint('Error clearing token from SecureStorage: $e');
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
    return _dio.get<T>(
      path,
      queryParameters: queryParameters,
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
    return _dio.post<T>(
      path,
      data: data,
      queryParameters: queryParameters,
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
    return _dio.put<T>(
      path,
      data: data,
      queryParameters: queryParameters,
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
    return _dio.patch<T>(
      path,
      data: data,
      queryParameters: queryParameters,
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
    return _dio.delete<T>(
      path,
      data: data,
      queryParameters: queryParameters,
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

    return _dio.post<T>(
      path,
      data: formData,
      onSendProgress: onSendProgress,
    );
  }
}
