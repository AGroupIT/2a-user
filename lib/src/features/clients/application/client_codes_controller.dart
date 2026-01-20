import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/persistence/shared_preferences_provider.dart';
import '../../auth/data/auth_provider.dart';
import '../domain/client_codes_state.dart';

final clientCodesControllerProvider =
    AsyncNotifierProvider<ClientCodesController, ClientCodesState>(
  ClientCodesController.new,
);

final activeClientCodeProvider = Provider<String?>((ref) {
  final asyncState = ref.watch(clientCodesControllerProvider);
  return asyncState.asData?.value.activeCode;
});

class ClientCodesController extends AsyncNotifier<ClientCodesState> {
  static const _activeKey = 'active_client_code';
  static const _codesKey = 'client_codes_list';

  @override
  Future<ClientCodesState> build() async {
    final prefs = ref.watch(sharedPreferencesProvider);
    final authState = ref.watch(authProvider);
    
    // Если авторизация ещё грузится - ждём
    if (authState.isLoading) {
      return const ClientCodesState(codes: [], activeCode: null);
    }
    
    // Получаем коды из данных авторизации
    List<String> codes = [];
    
    if (authState.clientData != null) {
      final clientCodes = authState.clientData!['codes'];
      if (clientCodes is List) {
        codes = clientCodes.map((e) {
          if (e is Map) {
            return (e['code'] ?? e.toString()).toString();
          }
          return e.toString();
        }).toList();
      }
    }
    
    // Если кодов нет из авторизации - пробуем восстановить из локального хранилища
    if (codes.isEmpty) {
      final savedCodes = prefs.getStringList(_codesKey);
      if (savedCodes != null && savedCodes.isNotEmpty) {
        codes = savedCodes;
      }
    } else {
      // Сохраняем коды локально для восстановления после перезапуска
      await prefs.setStringList(_codesKey, codes);
    }
    
    // Если кодов всё ещё нет - возвращаем пустой state
    if (codes.isEmpty) {
      return const ClientCodesState(codes: [], activeCode: null);
    }
    
    // Восстанавливаем сохранённый активный код
    final storedActive = prefs.getString(_activeKey);
    final active = (storedActive != null && codes.contains(storedActive))
        ? storedActive
        : codes.first;

    await prefs.setString(_activeKey, active);

    return ClientCodesState(codes: List.unmodifiable(codes), activeCode: active);
  }

  Future<void> selectClient(String code) async {
    final current = state.asData?.value;
    if (current == null) return;
    if (!current.codes.contains(code)) return;

    state = AsyncValue.data(current.copyWith(activeCode: code));
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(_activeKey, code);
  }

  Future<void> addClient({
    required String code,
    required String pin,
  }) async {
    final trimmedCode = code.trim().toUpperCase();
    final trimmedPin = pin.trim();
    
    if (trimmedCode.isEmpty) {
      throw Exception('Введите код клиента');
    }
    if (trimmedPin.length != 4) {
      throw Exception('PIN должен быть из 4 цифр');
    }

    // Проверяем, не привязан ли уже этот код
    final current = state.asData?.value ?? const ClientCodesState(codes: [], activeCode: null);
    if (current.codes.contains(trimmedCode)) {
      throw Exception('Этот код уже привязан к вашему аккаунту');
    }

    // Вызываем API для привязки кода к клиенту
    final apiClient = ref.read(apiClientProvider);
    
    try {
      final response = await apiClient.post(
        '/client-codes/link-by-pin',
        data: {
          'code': trimmedCode,
          'pin': trimmedPin,
        },
      );
      
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Не удалось привязать код');
      }
      
      // Успешно привязали - добавляем код в список
      final nextCodes = <String>{...current.codes, trimmedCode}.toList()..sort();
      final nextState = ClientCodesState(
        codes: List.unmodifiable(nextCodes),
        activeCode: trimmedCode,
      );

      state = AsyncValue.data(nextState);

      final prefs = ref.read(sharedPreferencesProvider);
      await prefs.setString(_activeKey, trimmedCode);
      await prefs.setStringList(_codesKey, nextCodes);
      
      debugPrint('✅ Код $trimmedCode успешно привязан');
    } on DioException catch (e) {
      debugPrint('❌ Ошибка привязки кода: $e');
      
      String errorMessage = 'Не удалось привязать код';
      
      if (e.response?.statusCode == 404) {
        errorMessage = 'Код не найден';
      } else if (e.response?.statusCode == 400) {
        final data = e.response?.data;
        if (data is Map && data['error'] != null) {
          errorMessage = data['error'].toString();
        } else {
          errorMessage = 'Неверный PIN или код уже привязан';
        }
      } else if (e.response?.statusCode == 409) {
        errorMessage = 'Этот код уже привязан к другому клиенту';
      } else if (e.response?.data is Map) {
        final data = e.response!.data as Map;
        if (data['error'] != null) {
          errorMessage = data['error'].toString();
        }
      }
      
      throw Exception(errorMessage);
    }
  }

  Future<void> logout() async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.remove(_activeKey);
    // По UX после выхода оставим пустой список и null активный код
    state = const AsyncValue.data(ClientCodesState(codes: [], activeCode: null));
  }
}
