import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
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
        if (error.response?.statusCode == 401) {
          await clearToken();
          // Вызываем callback для logout и редиректа
          _onUnauthorized?.call();
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
    // На web и desktop используем in-memory storage как основной
    if (kIsWeb || _isDesktop) {
      return _inMemoryToken;
    }
    try {
      return await _storage.read(key: _tokenKey);
    } catch (e) {
      debugPrint('Error reading token: $e');
      return _inMemoryToken; // fallback
    }
  }

  Future<void> setToken(String token) async {
    // Всегда сохраняем в memory
    _inMemoryToken = token;
    
    if (!kIsWeb && !_isDesktop) {
      try {
        await _storage.write(key: _tokenKey, value: token);
      } catch (e) {
        debugPrint('Error saving token: $e');
      }
    }
  }

  Future<void> clearToken() async {
    _inMemoryToken = null;
    
    if (!kIsWeb && !_isDesktop) {
      try {
        await _storage.delete(key: _tokenKey);
      } catch (e) {
        debugPrint('Error clearing token: $e');
      }
    }
  }
  
  /// Проверка на Desktop платформу
  bool get _isDesktop {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.windows ||
           defaultTargetPlatform == TargetPlatform.linux ||
           defaultTargetPlatform == TargetPlatform.macOS;
  }
  
  /// Проверка наличия токена (синхронная, проверяет in-memory)
  bool get hasToken => _inMemoryToken != null && _inMemoryToken!.isNotEmpty;

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
