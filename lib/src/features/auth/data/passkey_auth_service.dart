import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:passkeys/authenticator.dart';
import 'package:passkeys/types.dart';

import '../../../core/network/api_client.dart';
import '../../../core/services/platform_helper.dart';

final passkeyAuthServiceProvider = Provider<PasskeyAuthService>((ref) {
  return PasskeyAuthService(ref.read(apiClientProvider));
});

class PasskeyLoginResult {
  const PasskeyLoginResult({required this.token, required this.userData});

  final String token;
  final Map<String, dynamic> userData;
}

class PasskeyStatus {
  const PasskeyStatus({
    required this.enabled,
    required this.count,
    this.lastUsedAt,
    this.createdAt,
  });

  final bool enabled;
  final int count;
  final DateTime? lastUsedAt;
  final DateTime? createdAt;

  factory PasskeyStatus.fromJson(Map<String, dynamic>? json) {
    final passkeys = json?['passkeys'];
    Map<String, dynamic>? firstPasskey;
    if (passkeys is List && passkeys.isNotEmpty) {
      final first = passkeys.first;
      if (first is Map<String, dynamic>) {
        firstPasskey = first;
      } else if (first is Map) {
        firstPasskey = Map<String, dynamic>.from(first);
      }
    }

    final enabled = json?['enabled'] == true;
    final count = json?['count'];
    return PasskeyStatus(
      enabled: enabled,
      count: count is int ? count : (enabled ? 1 : 0),
      lastUsedAt: _parseDate(firstPasskey?['lastUsedAt']),
      createdAt: _parseDate(firstPasskey?['createdAt']),
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }
}

class PasskeyAuthService {
  PasskeyAuthService(this._apiClient)
    : _authenticator = PasskeyAuthenticator(debugMode: kDebugMode);

  final ApiClient _apiClient;
  final PasskeyAuthenticator _authenticator;

  Future<bool> isAvailable() async {
    if (kIsWeb) return false;

    try {
      if (isAndroidImpl()) {
        final availability = await _authenticator.getAvailability().android();
        return availability.hasPasskeySupport;
      }
      if (isIOSImpl()) {
        final availability = await _authenticator.getAvailability().iOS();
        return availability.hasPasskeySupport;
      }
    } catch (error) {
      debugPrint('Passkey availability check failed: $error');
    }

    return false;
  }

  Future<PasskeyLoginResult> authenticate({required String login}) async {
    final optionsResponse = await _apiClient.post<Map<String, dynamic>>(
      '/client/passkeys/authenticate/options',
      data: {'login': login.trim()},
    );

    final options = _normalizeCredentialOptions(
      _extractOptions(optionsResponse.data),
    );
    final request = AuthenticateRequestType.fromJson(
      options,
      mediation: MediationType.Required,
      preferImmediatelyAvailableCredentials: false,
    );

    final authenticatorResponse = await _authenticator.authenticate(request);
    final verifyResponse = await _apiClient.post<Map<String, dynamic>>(
      '/client/passkeys/authenticate/verify',
      data: {'response': authenticatorResponse.toJson()},
    );

    final data = verifyResponse.data;
    final token = data?['token'] as String?;
    final user = data?['user'];
    if (token == null || user is! Map<String, dynamic>) {
      throw const PasskeyAuthFlowException('Некорректный ответ сервера');
    }

    return PasskeyLoginResult(token: token, userData: user);
  }

  Future<PasskeyStatus> getCurrentUserPasskeyStatus() async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/client/passkeys/status',
    );
    return PasskeyStatus.fromJson(response.data);
  }

  Future<void> registerCurrentUserPasskey() async {
    final optionsResponse = await _apiClient.post<Map<String, dynamic>>(
      '/client/passkeys/register/options',
    );

    final options = _normalizeCredentialOptions(
      _extractOptions(optionsResponse.data),
    );
    final request = RegisterRequestType.fromJson(options);
    final authenticatorResponse = await _authenticator.register(request);

    await _apiClient.post<Map<String, dynamic>>(
      '/client/passkeys/register/verify',
      data: {'response': authenticatorResponse.toJson()},
    );
  }

  Future<void> unlinkCurrentUserPasskeys() async {
    await _apiClient.delete<Map<String, dynamic>>('/client/passkeys');
  }

  Map<String, dynamic> _extractOptions(Map<String, dynamic>? data) {
    final options = data?['options'];
    if (options is! Map<String, dynamic>) {
      throw const PasskeyAuthFlowException('Сервер не вернул challenge');
    }
    return options;
  }

  Map<String, dynamic> _normalizeCredentialOptions(
    Map<String, dynamic> options,
  ) {
    final normalized = Map<String, dynamic>.from(options);
    _normalizeCredentialList(normalized, 'allowCredentials');
    _normalizeCredentialList(normalized, 'excludeCredentials');
    return normalized;
  }

  void _normalizeCredentialList(Map<String, dynamic> options, String key) {
    final credentials = options[key];
    if (credentials is! List) return;

    options[key] = credentials.map((credential) {
      if (credential is Map<String, dynamic>) {
        return _normalizeCredential(credential);
      }
      if (credential is Map) {
        return _normalizeCredential(Map<String, dynamic>.from(credential));
      }
      return credential;
    }).toList();
  }

  Map<String, dynamic> _normalizeCredential(Map<String, dynamic> credential) {
    final normalized = Map<String, dynamic>.from(credential);
    final transports = normalized['transports'];
    normalized['transports'] = transports is List
        ? transports.whereType<String>().toList()
        : <String>[];
    return normalized;
  }

  String humanMessage(Object error) {
    if (error is PasskeyAuthFlowException) return error.message;

    if (error is DioException) {
      final responseData = error.response?.data;
      if (responseData is Map<String, dynamic>) {
        final serverError = responseData['error'];
        if (serverError is String && serverError.isNotEmpty) {
          if (error.response?.statusCode == 404) {
            return 'К этому email или телефону ещё не привязан Face ID / отпечаток. Войдите с помощью пароля и подключите быстрый вход.';
          }
          return serverError;
        }
      }
      if (error.response?.statusCode == 404) {
        return 'К этому email или телефону ещё не привязан Face ID / отпечаток. Войдите с помощью пароля и подключите быстрый вход.';
      }
      return 'Не удалось выполнить быстрый вход. Попробуйте войти с паролем';
    }

    if (error is PasskeyAuthCancelledException) {
      return 'Вход отменён';
    }
    if (error is NoCredentialsAvailableException) {
      return 'На этом устройстве нет привязанного Face ID / отпечатка для этого аккаунта. Войдите с помощью пароля.';
    }
    if (error is DomainNotAssociatedException) {
      return 'Домен приложения ещё не настроен для passkeys';
    }
    if (error is MissingGoogleSignInException ||
        error is SyncAccountNotAvailableException) {
      return 'Войдите в Google-аккаунт на устройстве и попробуйте снова';
    }
    if (error is DeviceNotSupportedException ||
        error is PasskeyUnsupportedException) {
      return 'Это устройство не поддерживает быстрый вход';
    }
    if (error is TimeoutException) {
      return 'Время ожидания Face ID / отпечатка истекло';
    }

    return 'Не удалось выполнить быстрый вход. Попробуйте войти с паролем';
  }

  String humanRegistrationMessage(Object error) {
    if (error is PasskeyAuthFlowException) return error.message;

    if (error is DioException) {
      final responseData = error.response?.data;
      if (responseData is Map<String, dynamic>) {
        final serverError = responseData['error'];
        if (serverError is String && serverError.isNotEmpty) {
          if (error.response?.statusCode == 401) {
            return 'Сессия истекла. Войдите заново и повторите привязку.';
          }
          if (error.response?.statusCode == 409) {
            return 'Этот Face ID / отпечаток уже привязан к другому аккаунту.';
          }
          return serverError;
        }
      }
      if (error.response?.statusCode == 401) {
        return 'Сессия истекла. Войдите заново и повторите привязку.';
      }
      return 'Не удалось подключить быстрый вход. Попробуйте позже';
    }

    if (error is PasskeyAuthCancelledException) {
      return 'Подключение быстрого входа отменено';
    }
    if (error is DomainNotAssociatedException) {
      return 'Домен приложения ещё не настроен для passkeys';
    }
    if (error is MissingGoogleSignInException ||
        error is SyncAccountNotAvailableException) {
      return 'Войдите в Google-аккаунт на устройстве и попробуйте снова';
    }
    if (error is DeviceNotSupportedException ||
        error is PasskeyUnsupportedException) {
      return 'Это устройство не поддерживает быстрый вход';
    }
    if (error is TimeoutException) {
      return 'Время ожидания Face ID / отпечатка истекло';
    }

    return 'Не удалось подключить быстрый вход. Попробуйте позже';
  }

  String humanUnlinkMessage(Object error) {
    if (error is PasskeyAuthFlowException) return error.message;

    if (error is DioException) {
      final responseData = error.response?.data;
      if (responseData is Map<String, dynamic>) {
        final serverError = responseData['error'];
        if (serverError is String && serverError.isNotEmpty) {
          if (error.response?.statusCode == 401) {
            return 'Сессия истекла. Войдите заново и повторите отвязку.';
          }
          return serverError;
        }
      }
      if (error.response?.statusCode == 401) {
        return 'Сессия истекла. Войдите заново и повторите отвязку.';
      }
    }

    return 'Не удалось отвязать быстрый вход. Попробуйте позже';
  }
}

class PasskeyAuthFlowException implements Exception {
  const PasskeyAuthFlowException(this.message);

  final String message;

  @override
  String toString() => message;
}
