import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../../core/network/api_client.dart';
import '../../../core/services/platform_helper.dart';
import '../../../core/services/push_notification_service.dart';
import '../../../core/services/secure_storage_service.dart';
import '../../../core/services/showcase_service.dart';
import '../../clients/application/client_codes_controller.dart';
import '../../profile/data/profile_provider.dart';

const _kIsLoggedInKey = 'is_logged_in';
const _kUserEmailKey = 'user_email';
const _kUserDomainKey = 'user_domain';
const _kTokenKey = 'auth_token';
const _kClientIdKey = 'client_id';
const _kClientNameKey = 'client_name';
const _kClientDataKey = 'client_data';

class AuthState {
  final bool isLoggedIn;
  final String? userEmail;
  final String? userDomain;
  final bool isLoading;
  final String? error;
  final int? clientId;
  final String? clientName;
  final Map<String, dynamic>? clientData;

  const AuthState({
    this.isLoggedIn = false,
    this.userEmail,
    this.userDomain,
    this.isLoading = true,
    this.error,
    this.clientId,
    this.clientName,
    this.clientData,
  });

  AuthState copyWith({
    bool? isLoggedIn,
    String? userEmail,
    String? userDomain,
    bool? isLoading,
    String? error,
    bool clearError = false,
    int? clientId,
    String? clientName,
    Map<String, dynamic>? clientData,
  }) {
    return AuthState(
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      userEmail: userEmail ?? this.userEmail,
      userDomain: userDomain ?? this.userDomain,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      clientId: clientId ?? this.clientId,
      clientName: clientName ?? this.clientName,
      clientData: clientData ?? this.clientData,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  late ApiClient _apiClient;
  late SecureStorageService _secureStorage;
  
  @override
  AuthState build() {
    _apiClient = ref.read(apiClientProvider);
    _secureStorage = ref.read(secureStorageProvider);
    _loadAuthState();
    return const AuthState();
  }

  Future<void> _loadAuthState() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool(_kIsLoggedInKey) ?? false;
    final userEmail = prefs.getString(_kUserEmailKey);
    final userDomain = prefs.getString(_kUserDomainKey);
    final clientId = prefs.getInt(_kClientIdKey);
    final clientName = prefs.getString(_kClientNameKey);
    
    // Migrate from SharedPreferences to secure storage if needed
    final oldToken = prefs.getString(_kTokenKey);
    if (oldToken != null && oldToken.isNotEmpty) {
      await _secureStorage.saveToken(oldToken);
      await prefs.remove(_kTokenKey);
    }
    
    // Восстанавливаем токен из secure storage
    if (isLoggedIn) {
      final savedToken = await _secureStorage.getToken();
      if (savedToken != null && savedToken.isNotEmpty) {
        await _apiClient.setToken(savedToken);
      }
    }
    
    // Восстанавливаем данные клиента
    Map<String, dynamic>? clientData;
    final clientDataJson = prefs.getString(_kClientDataKey);
    if (clientDataJson != null) {
      try {
        clientData = jsonDecode(clientDataJson) as Map<String, dynamic>;
      } catch (e) {
        debugPrint('Error parsing client data: $e');
      }
    }

    state = AuthState(
      isLoggedIn: isLoggedIn,
      userEmail: userEmail,
      userDomain: userDomain,
      isLoading: false,
      clientId: clientId,
      clientName: clientName,
      clientData: clientData,
    );
  }

  Future<bool> login({
    required String email,
    required String domain,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    
    try {
      final response = await _apiClient.post(
        '/login',
        data: {
          'email': email,
          'password': password,
          'type': 'client',  // Важно! Для клиентов type = 'client'
        },
      );
      
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final token = data['token'] as String?;
        final userData = data['user'] as Map<String, dynamic>?;
        
        if (token == null || userData == null) {
          state = state.copyWith(
            isLoading: false,
            error: 'Некорректный ответ сервера',
          );
          return false;
        }
        
        // Сохраняем токен в ApiClient
        await _apiClient.setToken(token);
        
        // Сохраняем токен в secure storage
        await _secureStorage.saveToken(token);
        
        // Извлекаем данные клиента
        final clientId = userData['id'] as int? ?? userData['clientId'] as int?;
        final clientName = userData['fullName'] as String? ?? 
                          userData['name'] as String? ?? 
                          email;
        final agentData = userData['agent'] as Map<String, dynamic>?;
        final clientDomain = agentData?['domain'] as String? ?? domain;
        
        // Сохраняем в SharedPreferences (без токена - он в secure storage)
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_kIsLoggedInKey, true);
        await prefs.setString(_kUserEmailKey, email);
        await prefs.setString(_kUserDomainKey, clientDomain);
        if (clientId != null) {
          await prefs.setInt(_kClientIdKey, clientId);
        }
        await prefs.setString(_kClientNameKey, clientName);
        await prefs.setString(_kClientDataKey, jsonEncode(userData));
        
        // Сбрасываем showcase чтобы показать обучение при каждом логине
        final showcaseService = ref.read(showcaseServiceProvider);
        await showcaseService.resetAllShowcases();
        
        // Обновляем состояние ПЕРЕД invalidate чтобы избежать циклических зависимостей
        state = AuthState(
          isLoggedIn: true,
          userEmail: email,
          userDomain: clientDomain,
          isLoading: false,
          clientId: clientId,
          clientName: clientName,
          clientData: userData,
        );
        
        // Invalidate провайдеры ПОСЛЕ обновления state
        // НЕ invalidate clientCodesControllerProvider - он сам пересоберётся через watch(authProvider)
        // Используем Future.microtask чтобы отложить до следующего микротаска
        Future.microtask(() {
          ref.invalidate(clientProfileProvider);
          for (final page in ShowcasePage.values) {
            ref.invalidate(showcaseProvider(page));
          }
        });
        
        // Регистрируем устройство для push-уведомлений
        _registerForPush(clientDomain);
        
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Неверный email или пароль',
        );
        return false;
      }
    } on DioException catch (e) {
      String errorMessage = 'Ошибка подключения к серверу';
      
      if (e.response?.statusCode == 401) {
        errorMessage = 'Неверный email или пароль';
      } else if (e.response?.statusCode == 404) {
        errorMessage = 'Пользователь не найден';
      } else if (e.type == DioExceptionType.connectionTimeout ||
                 e.type == DioExceptionType.receiveTimeout) {
        errorMessage = 'Превышено время ожидания. Проверьте подключение';
      } else if (e.type == DioExceptionType.connectionError) {
        errorMessage = 'Нет подключения к серверу';
      }
      
      debugPrint('Login error: $e');
      state = state.copyWith(
        isLoading: false,
        error: errorMessage,
      );
      return false;
    } catch (e) {
      debugPrint('Login error: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Произошла ошибка: $e',
      );
      return false;
    }
  }
  
  /// Авторизация по данным от password-reset (после подтверждения по звонку)
  Future<bool> loginWithData({
    required String token,
    required Map<String, dynamic> userData,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    
    try {
      // Сохраняем токен в ApiClient
      await _apiClient.setToken(token);
      
      // Сохраняем токен в secure storage
      await _secureStorage.saveToken(token);
      
      // Извлекаем данные клиента
      final clientId = userData['id'] as int? ?? userData['clientId'] as int?;
      final email = userData['email'] as String? ?? '';
      final clientName = userData['fullName'] as String? ?? 
                        userData['name'] as String? ?? 
                        email;
      final agentData = userData['agent'] as Map<String, dynamic>?;
      final clientDomain = agentData?['domain'] as String? ?? '';
      
      // Сохраняем в SharedPreferences (без токена - он в secure storage)
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kIsLoggedInKey, true);
      await prefs.setString(_kUserEmailKey, email);
      await prefs.setString(_kUserDomainKey, clientDomain);
      if (clientId != null) {
        await prefs.setInt(_kClientIdKey, clientId);
      }
      await prefs.setString(_kClientNameKey, clientName);
      await prefs.setString(_kClientDataKey, jsonEncode(userData));
      
      // Сбрасываем showcase чтобы показать обучение при каждом логине
      final showcaseService = ref.read(showcaseServiceProvider);
      await showcaseService.resetAllShowcases();
      
      // Invalidate client codes and profile to reload data
      ref.invalidate(clientCodesControllerProvider);
      ref.invalidate(clientProfileProvider);
      
      // Invalidate все showcase провайдеры чтобы они перечитали состояние
      for (final page in ShowcasePage.values) {
        ref.invalidate(showcaseProvider(page));
      }
      
      state = AuthState(
        isLoggedIn: true,
        userEmail: email,
        userDomain: clientDomain,
        isLoading: false,
        clientId: clientId,
        clientName: clientName,
        clientData: userData,
      );
      
      // Регистрируем устройство для push-уведомлений
      if (clientDomain.isNotEmpty) {
        _registerForPush(clientDomain);
      }
      
      return true;
    } catch (e) {
      debugPrint('LoginWithData error: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Ошибка авторизации: $e',
      );
      return false;
    }
  }
  
  /// Регистрация устройства для push-уведомлений
  Future<void> _registerForPush(String domain) async {
    try {
      final fcmToken = await PushNotificationService.getFCMToken();
      if (fcmToken != null) {
        debugPrint('🔔 FCM Token for client: ${fcmToken.substring(0, 20)}...');
        
        // Определяем платформу через хелпер
        final platform = getPlatformNameImpl();
        
        // Отправляем токен на сервер
        try {
          await _apiClient.post(
            '/devices',
            data: {
              'platform': platform,
              'token': fcmToken,
              'deviceId': await _getDeviceId(),
            },
          );
          debugPrint('🔔 Device registered successfully');
        } catch (e) {
          debugPrint('🔔 Error registering device: $e');
        }
      }
      
      // Подписываемся на топики клиентов
      await PushNotificationService.subscribeToTopic('clients');
      await PushNotificationService.subscribeToTopic('domain_$domain');
    } catch (e) {
      debugPrint('🔔 Error registering for push: $e');
    }
  }
  
  /// Получить уникальный ID устройства
  Future<String?> _getDeviceId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? deviceId = prefs.getString('device_id');
      if (deviceId == null) {
        // Генерируем уникальный ID
        deviceId = 'device_${DateTime.now().millisecondsSinceEpoch}_${UniqueKey().hashCode}';
        await prefs.setString('device_id', deviceId);
      }
      return deviceId;
    } catch (e) {
      return null;
    }
  }

  Future<void> logout() async {
    // Отписываемся от push-уведомлений
    await _unregisterFromPush();
    
    // Очищаем токен в ApiClient
    await _apiClient.clearToken();
    
    // Очищаем токен из secure storage
    await _secureStorage.deleteToken();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kIsLoggedInKey);
    await prefs.remove(_kUserEmailKey);
    await prefs.remove(_kUserDomainKey);
    await prefs.remove(_kTokenKey); // legacy cleanup
    await prefs.remove(_kClientIdKey);
    await prefs.remove(_kClientNameKey);
    await prefs.remove(_kClientDataKey);

    // Clear notification badge (not supported on Desktop)
    if (!kIsWeb && !isDesktopImpl()) {
      try {
        // Очищаем все уведомления и badge
        final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
        await flutterLocalNotificationsPlugin.cancelAll();
      } catch (e) {
        if (kDebugMode) debugPrint('Error clearing notifications: $e');
      }
    }

    state = const AuthState(
      isLoggedIn: false,
      isLoading: false,
    );
  }
  
  /// Отписка от push-уведомлений
  Future<void> _unregisterFromPush() async {
    try {
      final domain = state.userDomain;
      
      // Деактивируем устройство на сервере только если есть токен
      if (_apiClient.hasToken) {
        final fcmToken = await PushNotificationService.getFCMToken();
        if (fcmToken != null) {
          try {
            await _apiClient.delete(
              '/devices',
              data: {
                'token': fcmToken,
              },
            );
            debugPrint('🔔 Device deactivated successfully');
          } catch (e) {
            debugPrint('🔔 Error deactivating device: $e');
          }
        }
      }
      
      // Отписываемся от топиков
      await PushNotificationService.unsubscribeFromTopic('clients');
      if (domain != null) {
        await PushNotificationService.unsubscribeFromTopic('domain_$domain');
      }
    } catch (e) {
      debugPrint('🔔 Error unregistering from push: $e');
    }
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

// Helper provider to check if user is logged in (non-loading)
final isLoggedInProvider = Provider<bool>((ref) {
  final auth = ref.watch(authProvider);
  return auth.isLoggedIn;
});

// Helper provider to check if auth is still loading
final isAuthLoadingProvider = Provider<bool>((ref) {
  final auth = ref.watch(authProvider);
  return auth.isLoading;
});
