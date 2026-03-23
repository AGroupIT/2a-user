import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../../../core/config/sentry_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/platform_helper.dart';
import '../../../core/services/push_notification_service.dart';
import '../../../core/services/showcase_service.dart';
import '../../../core/utils/error_utils.dart';
import '../../assemblies/data/assemblies_provider.dart';
import '../../clients/application/client_codes_controller.dart';
import '../../invoices/data/invoices_provider.dart';
import '../../notifications/application/notifications_controller.dart';
import '../../photos/data/photos_provider.dart';
import '../../profile/data/profile_provider.dart';
import '../../sp_finance/data/sp_provider.dart';
import '../../tracks/data/assemblies_provider.dart' as tracks_assemblies;
import '../../tracks/data/tracks_provider.dart';

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
  // Флаг: начальная загрузка завершена или login/logout уже взяли управление.
  // Предотвращает race condition когда _loadAuthState() завершается ПОСЛЕ того,
  // как пользователь уже нажал "Войти" и login() изменил state.
  bool _initialLoadDone = false;

  @override
  AuthState build() {
    _apiClient = ref.read(apiClientProvider);
    _initialLoadDone = false;

    // Подписываемся на обновление FCM токена — перерегистрируем на бэкенде.
    // Без этого при обновлении токена Firebase старый становится невалидным и пуши пропадают.
    PushNotificationService.onTokenRefreshed = (newToken) {
      if (state.isLoggedIn) {
        _reRegisterDeviceToken(newToken);
      }
    };

    _loadAuthState();
    return const AuthState();
  }

  Future<void> _loadAuthState() async {
    debugPrint('🔄 Loading auth state...');

    try {
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = prefs.getBool(_kIsLoggedInKey) ?? false;
      final userEmail = prefs.getString(_kUserEmailKey);
      final userDomain = prefs.getString(_kUserDomainKey);
      final clientId = prefs.getInt(_kClientIdKey);
      final clientName = prefs.getString(_kClientNameKey);

      debugPrint('🔍 isLoggedIn from SharedPreferences: $isLoggedIn');
      debugPrint('🔍 userEmail: $userEmail');

      // Проверяем есть ли токен в ApiClient (он сам знает откуда читать: localStorage на web, SecureStorage на мобильных)
      if (isLoggedIn) {
        final hasToken = await _apiClient.hasTokenAsync();
        debugPrint('🔍 hasToken from ApiClient: $hasToken');

        if (!hasToken) {
          // Токен не найден — возможны два случая:
          // 1. Транзиентная ошибка iOS Keychain (до первой разблокировки после перезагрузки,
          //    после обновления приложения/iOS) — токен физически есть, просто не читается.
          // 2. Токен реально удалён.
          //
          // В обоих случаях НЕ вызываем logout() — это необратимо очищает SharedPreferences
          // и убивает авторизацию навсегда. Вместо этого просто показываем экран входа.
          // При следующем запуске попробуем снова — если Keychain восстановился, войдём
          // автоматически; если нет — пользователь введёт пароль и получит новый токен.
          debugPrint('🔐 Token not found — showing login screen (not forcing logout)');
          if (!_initialLoadDone) {
            _initialLoadDone = true;
            state = const AuthState(isLoggedIn: false, isLoading: false);
          }
          return;
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

      // Проверяем, что login() не успел взять управление пока мы читали хранилище.
      // Если _initialLoadDone уже true — login() или logout() уже обновили state, не перезаписываем.
      if (_initialLoadDone) {
        debugPrint('⚠️ _loadAuthState: skipping state update — login/logout already took over');
        return;
      }
      _initialLoadDone = true;

      state = AuthState(
        isLoggedIn: isLoggedIn,
        userEmail: userEmail,
        userDomain: userDomain,
        isLoading: false,
        clientId: clientId,
        clientName: clientName,
        clientData: clientData,
      );

      debugPrint('✅ Auth state loaded: isLoggedIn=$isLoggedIn, email=$userEmail');

      // Обновляем clientData из /auth/me в фоне, чтобы коды клиента содержали актуальные id.
      // Это важно для корректной передачи clientCodeId при создании сборок.
      if (isLoggedIn) {
        _refreshClientDataInBackground();
      }
    } catch (e, stackTrace) {
      // Если что-то пошло не так при загрузке состояния — не зависаем на сплэше,
      // просто показываем экран входа.
      debugPrint('❌ Error loading auth state: $e\n$stackTrace');
      if (!_initialLoadDone) {
        _initialLoadDone = true;
        state = const AuthState(isLoggedIn: false, isLoading: false);
      }
    }
  }

  /// Обновляет clientData из /auth/me в фоне.
  /// Критично для того, чтобы codes содержали актуальный id (нужен для clientCodeId в сборках).
  Future<void> _refreshClientDataInBackground() async {
    try {
      final response = await _apiClient.get('/auth/me');
      if (response.statusCode == 200 && response.data != null) {
        final userData = response.data as Map<String, dynamic>;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_kClientDataKey, jsonEncode(userData));
        state = state.copyWith(clientData: userData);
        debugPrint('✅ clientData refreshed from /auth/me');
      }
    } catch (e) {
      debugPrint('⚠️ Could not refresh clientData from /auth/me: $e');
    }
  }

  Future<bool> login({
    required String email,
    required String domain,
    required String password,
  }) async {
    _initialLoadDone = true; // Предотвращаем перезапись state от _loadAuthState()
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
        
        // Сохраняем токен в ApiClient (он сам выберет где хранить: localStorage на web, SecureStorage на мобильных)
        await _apiClient.setToken(token);
        
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
        
        // Invalidate все провайдеры данных чтобы новый пользователь не видел данные предыдущего
        Future.microtask(() {
          _invalidateAllProviders();
          for (final page in ShowcasePage.values) {
            ref.invalidate(showcaseProvider(page));
          }
          for (final block in ShowcaseBlock.values) {
            ref.invalidate(showcaseBlockProvider(block));
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
      String errorMessage;

      // Специфичные ошибки авторизации
      if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        errorMessage = 'Неверный email или пароль';
      } else if (e.response?.statusCode == 404) {
        errorMessage = 'Пользователь не найден. Проверьте данные для входа';
      } else {
        // Используем ErrorUtils для остальных ошибок
        final errorInfo = ErrorUtils.getErrorInfo(e);
        errorMessage = errorInfo.message;
      }

      debugPrint('Login error: $e');
      debugPrint('Error message shown to user: $errorMessage');

      state = state.copyWith(
        isLoading: false,
        error: errorMessage,
      );
      return false;
    } catch (e, stackTrace) {
      debugPrint('Login error: $e');

      // Отправляем в Sentry только неожиданные ошибки
      if (SentryConfig.enabled) {
        await Sentry.captureException(
          e,
          stackTrace: stackTrace,
          hint: Hint.withMap({
            'type': 'login_error',
            'email': email,
            'domain': domain,
          }),
        );
      }

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
    _initialLoadDone = true; // Предотвращаем перезапись state от _loadAuthState()
    state = state.copyWith(isLoading: true, clearError: true);
    
    try {
      // Сохраняем токен в ApiClient (он сам выберет где хранить: localStorage на web, SecureStorage на мобильных)
      await _apiClient.setToken(token);
      
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

      // Обновляем state ПЕРЕД invalidate — чтобы при перестройке провайдеры
      // видели уже нового пользователя (новый clientId/clientCode)
      state = AuthState(
        isLoggedIn: true,
        userEmail: email,
        userDomain: clientDomain,
        isLoading: false,
        clientId: clientId,
        clientName: clientName,
        clientData: userData,
      );

      // Invalidate все провайдеры данных чтобы новый пользователь не видел данные предыдущего
      Future.microtask(() {
        _invalidateAllProviders();
        for (final page in ShowcasePage.values) {
          ref.invalidate(showcaseProvider(page));
        }
        for (final block in ShowcaseBlock.values) {
          ref.invalidate(showcaseBlockProvider(block));
        }
      });
      
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
  
  /// Перерегистрация device token при обновлении FCM токена Firebase
  Future<void> _reRegisterDeviceToken(String newToken) async {
    try {
      final platform = getPlatformNameImpl();
      await _apiClient.post(
        '/devices',
        data: {
          'platform': platform,
          'token': newToken,
          'deviceId': await _getDeviceId(),
        },
      );
      debugPrint('🔔 Device token re-registered after FCM refresh');
    } catch (e) {
      debugPrint('🔔 Error re-registering device token: $e');
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
    try {
      debugPrint('🚪 Starting logout process...');

      // Отписываемся от push-уведомлений
      try {
        await _unregisterFromPush();
        debugPrint('✅ Unregistered from push');
      } catch (e) {
        debugPrint('⚠️ Error unregistering from push: $e');
        // Продолжаем logout даже если отписка от push не удалась
      }

      // Очищаем токен в ApiClient (он сам очистит и localStorage на web, и SecureStorage на мобильных)
      try {
        await _apiClient.clearToken();
        debugPrint('✅ Token cleared from ApiClient');
      } catch (e) {
        debugPrint('⚠️ Error clearing token: $e');
      }

      // Очищаем SharedPreferences
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_kIsLoggedInKey);
        await prefs.remove(_kUserEmailKey);
        await prefs.remove(_kUserDomainKey);
        await prefs.remove(_kTokenKey); // legacy cleanup
        await prefs.remove(_kClientIdKey);
        await prefs.remove(_kClientNameKey);
        await prefs.remove(_kClientDataKey);
        debugPrint('✅ SharedPreferences cleared');

        // Verify it was actually removed
        final stillLoggedIn = prefs.getBool(_kIsLoggedInKey);
        debugPrint('🔍 After logout, isLoggedIn key = $stillLoggedIn (should be null)');
      } catch (e) {
        debugPrint('⚠️ Error clearing SharedPreferences: $e');
      }

      // Clear notification badge (not supported on Desktop)
      if (!kIsWeb && !isDesktopImpl()) {
        try {
          // Очищаем все уведомления и badge
          final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
          await flutterLocalNotificationsPlugin.cancelAll();
          debugPrint('✅ Notifications cleared');
        } catch (e) {
          debugPrint('⚠️ Error clearing notifications: $e');
        }
      }

      // Очищаем SharedPreferences ключи clientCodesController вручную,
      // чтобы PIN-коды одного пользователя не утекли к следующему
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('active_client_code');
        await prefs.remove('client_codes_list');
      } catch (e) {
        debugPrint('⚠️ Error clearing client codes from prefs: $e');
      }

      // Сначала обновляем state — при перестройке провайдеры увидят isLoggedIn: false
      state = const AuthState(
        isLoggedIn: false,
        isLoading: false,
      );

      // Затем инвалидируем все провайдеры
      _invalidateAllProviders();

      debugPrint('✅ Logout completed successfully');
    } catch (e, stackTrace) {
      debugPrint('❌ Critical error during logout: $e');
      debugPrint('Stack trace: $stackTrace');

      // Всё равно устанавливаем состояние "разлогинен" даже если была ошибка
      state = const AuthState(
        isLoggedIn: false,
        isLoading: false,
      );

      // Invalidate providers even on error
      _invalidateAllProviders();
    }
  }

  /// Инвалидация всех провайдеров данных при logout
  void _invalidateAllProviders() {
    debugPrint('🗑️ Invalidating all data providers...');

    // Каждый invalidate в отдельном try-catch: если один провайдер недоступен,
    // остальные всё равно будут инвалидированы (иначе при смене аккаунта могут
    // остаться старые данные).
    void inv(dynamic provider) {
      try { ref.invalidate(provider); } catch (_) {}
    }

    // Profile & Stats
    inv(clientProfileProvider);
    inv(clientStatsProvider);

    // Client codes
    inv(clientCodesControllerProvider);

    // Tracks (all family instances)
    inv(paginatedTracksProvider);
    inv(tracksListProvider);
    inv(tracksDigestProvider);
    inv(tracksSimpleListProvider);
    inv(tracksCountProvider);
    inv(tracksWithoutAssemblyCountProvider);
    inv(trackStatusesProvider);

    // Assemblies (tracks module)
    inv(tracks_assemblies.assembliesListProvider);
    inv(tracks_assemblies.assembliesDigestProvider);
    inv(tracks_assemblies.assembliesCountProvider);
    inv(tracks_assemblies.tariffsProvider);

    // Assemblies (assemblies module)
    inv(assembliesCountProvider);

    // Invoices
    inv(invoicesListProvider);
    inv(invoicesDigestProvider);
    inv(invoicesCountProvider);
    inv(invoiceStatusesProvider);

    // Photos
    inv(photosTotalCountProvider);
    inv(photosRecentProvider);
    inv(photosDaysProvider);
    inv(photosByDateProvider);
    inv(photosSearchProvider);

    // Notifications
    inv(notificationsControllerProvider);
    inv(unreadCountProvider);

    // SP Finance
    inv(spAssembliesControllerProvider);

    debugPrint('✅ All providers invalidated');
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
