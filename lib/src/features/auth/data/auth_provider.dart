import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_app_badger/flutter_app_badger.dart';

import '../../../core/services/push_notification_service.dart';
import '../../clients/application/client_codes_controller.dart';

const _kIsLoggedInKey = 'is_logged_in';
const _kUserEmailKey = 'user_email';
const _kUserDomainKey = 'user_domain';

// Demo credentials
const demoEmail = 'demo@demo.demo';
const demoDomain = 'demo';
const demoPassword = 'demo';

class AuthState {
  final bool isLoggedIn;
  final String? userEmail;
  final String? userDomain;
  final bool isLoading;

  const AuthState({
    this.isLoggedIn = false,
    this.userEmail,
    this.userDomain,
    this.isLoading = true,
  });

  AuthState copyWith({
    bool? isLoggedIn,
    String? userEmail,
    String? userDomain,
    bool? isLoading,
  }) {
    return AuthState(
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      userEmail: userEmail ?? this.userEmail,
      userDomain: userDomain ?? this.userDomain,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    _loadAuthState();
    return const AuthState();
  }

  Future<void> _loadAuthState() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool(_kIsLoggedInKey) ?? false;
    final userEmail = prefs.getString(_kUserEmailKey);
    final userDomain = prefs.getString(_kUserDomainKey);

    state = AuthState(
      isLoggedIn: isLoggedIn,
      userEmail: userEmail,
      userDomain: userDomain,
      isLoading: false,
    );
  }

  Future<bool> login({
    required String email,
    required String domain,
    required String password,
  }) async {
    // Demo validation
    if (email.toLowerCase() == demoEmail &&
        domain.toLowerCase() == demoDomain &&
        password == demoPassword) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kIsLoggedInKey, true);
      await prefs.setString(_kUserEmailKey, email);
      await prefs.setString(_kUserDomainKey, domain);

      // Invalidate client codes to reload demo data
      ref.invalidate(clientCodesControllerProvider);

      state = AuthState(
        isLoggedIn: true,
        userEmail: email,
        userDomain: domain,
        isLoading: false,
      );
      
      // Регистрируем устройство для push-уведомлений
      _registerForPush(domain);
      
      return true;
    }
    return false;
  }
  
  /// Регистрация устройства для push-уведомлений
  Future<void> _registerForPush(String domain) async {
    try {
      final token = await PushNotificationService.getFCMToken();
      if (token != null) {
        debugPrint('🔔 FCM Token for client: ${token.substring(0, 20)}...');
        // TODO: Отправить токен на сервер через API
        // await apiClient.post('/devices', data: {...})
      }
      
      // Подписываемся на топики клиентов
      await PushNotificationService.subscribeToTopic('clients');
      await PushNotificationService.subscribeToTopic('domain_$domain');
    } catch (e) {
      debugPrint('🔔 Error registering for push: $e');
    }
  }

  Future<void> logout() async {
    // Отписываемся от push-уведомлений
    await _unregisterFromPush();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kIsLoggedInKey);
    await prefs.remove(_kUserEmailKey);
    await prefs.remove(_kUserDomainKey);

    // Clear notification badge
    FlutterAppBadger.removeBadge();

    state = const AuthState(
      isLoggedIn: false,
      isLoading: false,
    );
  }
  
  /// Отписка от push-уведомлений
  Future<void> _unregisterFromPush() async {
    try {
      final domain = state.userDomain;
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
