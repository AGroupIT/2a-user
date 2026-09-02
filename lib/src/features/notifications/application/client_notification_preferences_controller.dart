import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/client_notification_preferences_repository.dart';
import '../domain/client_notification_preference.dart';

final clientNotificationPreferencesControllerProvider =
    AsyncNotifierProvider.autoDispose<
      ClientNotificationPreferencesController,
      ClientNotificationPreferencesState
    >(ClientNotificationPreferencesController.new);

class ClientNotificationPreferencesController
    extends AsyncNotifier<ClientNotificationPreferencesState> {
  ClientNotificationPreferencesRepository get _repository =>
      ref.read(clientNotificationPreferencesRepositoryProvider);

  @override
  Future<ClientNotificationPreferencesState> build() async {
    return ClientNotificationPreferencesState(items: await _repository.fetch());
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () async =>
          ClientNotificationPreferencesState(items: await _repository.fetch()),
    );
  }

  Future<void> setEnabled(String key, bool enabled) async {
    final current = state.asData?.value;
    if (current == null || current.savingKeys.contains(key)) return;
    final existing = current.items.where((item) => item.key == key).firstOrNull;
    if (existing == null || !existing.isConfigurable) return;

    state = AsyncData(
      current.copyWith(
        items: _replaceItem(current.items, existing.copyWith(enabled: enabled)),
        savingKeys: {...current.savingKeys, key},
      ),
    );

    try {
      final saved = await _repository.update(key: key, enabled: enabled);
      final latest = state.asData?.value ?? current;
      state = AsyncData(
        latest.copyWith(
          items: _replaceItem(latest.items, saved),
          savingKeys: {...latest.savingKeys}..remove(key),
        ),
      );
    } catch (error, stackTrace) {
      final latest = state.asData?.value ?? current;
      state = AsyncData(
        latest.copyWith(
          items: _replaceItem(latest.items, existing),
          savingKeys: {...latest.savingKeys}..remove(key),
        ),
      );
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  List<ClientNotificationPreferenceItem> _replaceItem(
    List<ClientNotificationPreferenceItem> items,
    ClientNotificationPreferenceItem replacement,
  ) {
    return [
      for (final item in items)
        if (item.key == replacement.key) replacement else item,
    ];
  }
}
