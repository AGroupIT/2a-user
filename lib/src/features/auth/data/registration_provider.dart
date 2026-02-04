import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';

/// Состояние регистрации
class RegistrationState {
  final bool isLoading;
  final bool isSuccess;
  final String? error;

  const RegistrationState({
    this.isLoading = false,
    this.isSuccess = false,
    this.error,
  });

  RegistrationState copyWith({
    bool? isLoading,
    bool? isSuccess,
    String? error,
    bool clearError = false,
  }) {
    return RegistrationState(
      isLoading: isLoading ?? this.isLoading,
      isSuccess: isSuccess ?? this.isSuccess,
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

  /// Отправить заявку на регистрацию
  Future<bool> submitRequest({
    required String fullName,
    required String phone,
    required String domain,
    String? email,
    String? companyName,
    String? comment,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final response = await _apiClient.post(
        '/registration-requests',
        data: {
          'fullName': fullName.trim(),
          'phone': phone.trim(),
          'domain': domain.trim().toLowerCase(),
          if (email != null && email.isNotEmpty) 'email': email.trim().toLowerCase(),
          if (companyName != null && companyName.isNotEmpty) 'companyName': companyName.trim(),
          if (comment != null && comment.isNotEmpty) 'comment': comment.trim(),
        },
      );

      if (response.statusCode == 201) {
        state = state.copyWith(isLoading: false, isSuccess: true);
        return true;
      } else {
        final errorMsg = response.data?['error'] as String? ?? 'Не удалось отправить заявку';
        state = state.copyWith(isLoading: false, error: errorMsg);
        return false;
      }
    } on DioException catch (e) {
      debugPrint('Registration error: $e');

      String errorMessage;
      if (e.response?.statusCode == 404) {
        errorMessage = 'Компания с указанным доменом не найдена';
      } else if (e.response?.statusCode == 409) {
        final msg = e.response?.data?['error'] as String?;
        errorMessage = msg ?? 'Заявка уже существует';
      } else if (e.response?.statusCode == 400) {
        final msg = e.response?.data?['error'] as String?;
        errorMessage = msg ?? 'Проверьте введённые данные';
      } else {
        errorMessage = 'Ошибка сети. Попробуйте позже';
      }

      state = state.copyWith(isLoading: false, error: errorMessage);
      return false;
    } catch (e) {
      debugPrint('Registration error: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Произошла ошибка: $e',
      );
      return false;
    }
  }
}

/// Провайдер состояния регистрации
final registrationProvider = NotifierProvider<RegistrationNotifier, RegistrationState>(
  RegistrationNotifier.new,
);
