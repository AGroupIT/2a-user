import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/fake_search_repository.dart';
import '../domain/search_result.dart';

final searchControllerProvider =
    AsyncNotifierProvider<SearchController, List<SearchResult>>(SearchController.new);

class SearchController extends AsyncNotifier<List<SearchResult>> {
  @override
  Future<List<SearchResult>> build() async => const [];

  Future<void> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      state = const AsyncValue.data([]);
      return;
    }

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(searchRepositoryProvider);
      return repo.searchTracks(trimmed);
    });
  }

  Future<bool> requestBinding({
    required int trackId,
    required String trackNumber,
    required String clientCode,
    required int clientId,
    required int? clientCodeId,
  }) async {
    try {
      final repo = ref.read(searchRepositoryProvider);
      await repo.requestBinding(
        trackId: trackId,
        trackNumber: trackNumber,
        clientCode: clientCode,
        clientId: clientId,
        clientCodeId: clientCodeId,
      );
      
      // Обновляем список - помечаем трек как имеющий вопрос
      final current = state.value;
      if (current != null) {
        final updated = current.map((item) {
          if (item.id == trackId) {
            return SearchResult(
              id: item.id,
              trackCode: item.trackCode,
              status: item.status,
              statusZh: item.statusZh,
              statusColor: item.statusColor,
              updatedAt: item.updatedAt,
              clientCode: item.clientCode,
              clientCodeId: item.clientCodeId,
              isNocode: item.isNocode,
              hasQuestion: true,
              hasPendingQuestion: true,
              showBindButton: false, // Скрываем кнопку после отправки запроса
            );
          }
          return item;
        }).toList();
        state = AsyncValue.data(updated);
      }
      
      return true;
    } catch (e) {
      return false;
    }
  }
}
