import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/persistence/shared_preferences_provider.dart';
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
  static const _codesKey = 'client_codes';
  static const _activeKey = 'active_client_code';

  @override
  Future<ClientCodesState> build() async {
    final prefs = await ref.watch(sharedPreferencesProvider.future);
    
    // Для разработки всегда используем тестовые данные
    final codes = <String>['2A-12', '2A-34', '3B-56', '4C-78', '5D-90'];
    
    final storedActive = prefs.getString(_activeKey);
    final active = (storedActive != null && codes.contains(storedActive))
        ? storedActive
        : codes.first;

    await prefs.setStringList(_codesKey, codes);
    await prefs.setString(_activeKey, active);

    return ClientCodesState(codes: List.unmodifiable(codes), activeCode: active);
  }

  Future<void> selectClient(String code) async {
    final current = state.asData?.value;
    if (current == null) return;
    if (!current.codes.contains(code)) return;

    state = AsyncValue.data(current.copyWith(activeCode: code));
    final prefs = await ref.read(sharedPreferencesProvider.future);
    await prefs.setString(_activeKey, code);
  }

  Future<void> addClient({
    required String code,
    required String pin,
  }) async {
    final trimmedCode = code.trim();
    final trimmedPin = pin.trim();
    if (trimmedCode.isEmpty) {
      throw Exception('Введите код клиента');
    }
    if (trimmedPin.length != 4) {
      throw Exception('PIN должен быть из 4 цифр');
    }

    final current = state.asData?.value ?? const ClientCodesState(codes: [], activeCode: null);
    final nextCodes = <String>{...current.codes, trimmedCode}.toList()..sort();
    final nextState = ClientCodesState(codes: List.unmodifiable(nextCodes), activeCode: trimmedCode);

    state = AsyncValue.data(nextState);

    final prefs = await ref.read(sharedPreferencesProvider.future);
    await prefs.setStringList(_codesKey, nextCodes);
    await prefs.setString(_activeKey, trimmedCode);
  }

  Future<void> logout() async {
    final prefs = await ref.read(sharedPreferencesProvider.future);
    await prefs.remove(_activeKey);
    await prefs.remove(_codesKey);
    // По UX после выхода оставим пустой список и null активный код
    state = const AsyncValue.data(ClientCodesState(codes: [], activeCode: null));
  }
}
