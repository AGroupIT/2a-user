import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import 'auth_provider.dart';

/// Состояние регистрации
class RegistrationState {
  final bool isLoading;
  final String? error;

  const RegistrationState({this.isLoading = false, this.error});

  RegistrationState copyWith({
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return RegistrationState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Notifier для управления регистрацией
class RegistrationNotifier extends Notifier<RegistrationState> {
  late ApiClient _apiClient;

  @override
  RegistrationState build() {
    _apiClient = ref.read(apiClientProvider);
    return const RegistrationState();
  }

  /// Сбросить состояние
  void reset() {
    state = const RegistrationState();
  }

  /// Самостоятельная регистрация — создаёт клиента, выдаёт код 2A-XXXX, логинит.
  Future<bool> register({
    required String fullName,
    required String phone,
    required String email,
    required String password,
    required String confirmPassword,
    String? agentCode,
    String? referralCode,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final response = await _apiClient.post(
        '/register',
        data: {
          'fullName': fullName.trim(),
          'phone': phone.trim(),
          'email': email.trim().toLowerCase(),
          'password': password,
          'confirmPassword': confirmPassword,
          if (agentCode != null && agentCode.trim().isNotEmpty)
            'agentCode': agentCode.trim(),
          if (referralCode != null && referralCode.isNotEmpty)
            'referralCode': referralCode.trim().toUpperCase(),
        },
      );

      if (response.statusCode == 201) {
        final data = response.data as Map<String, dynamic>;
        final token = data['token'] as String;
        final userData = data['user'] as Map<String, dynamic>;

        // Автологин — тот же метод что использует сброс пароля
        await ref
            .read(authProvider.notifier)
            .loginWithData(token: token, userData: userData);

        state = state.copyWith(isLoading: false);
        return true;
      } else {
        final errorMsg =
            response.data?['error'] as String? ??
            'Не удалось зарегистрироваться';
        state = state.copyWith(isLoading: false, error: errorMsg);
        return false;
      }
    } on DioException catch (e) {
      debugPrint('Register error: $e');

      String errorMessage;
      if (e.response?.statusCode == 409) {
        final msg = e.response?.data?['error'] as String?;
        errorMessage =
            msg ?? 'Пользователь с такими данными уже зарегистрирован';
      } else if (e.response?.statusCode == 400) {
        final msg = e.response?.data?['error'] as String?;
        errorMessage = msg ?? 'Проверьте введённые данные';
      } else {
        errorMessage = 'Ошибка сети. Попробуйте позже';
      }

      state = state.copyWith(isLoading: false, error: errorMessage);
      return false;
    } catch (e) {
      debugPrint('Register error: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Произошла ошибка. Попробуйте позже',
      );
      return false;
    }
  }
}

/// Провайдер состояния регистрации
final registrationProvider =
    NotifierProvider<RegistrationNotifier, RegistrationState>(
      RegistrationNotifier.new,
    );
