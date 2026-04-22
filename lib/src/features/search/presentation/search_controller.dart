import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/fake_search_repository.dart';
import '../domain/search_result.dart';

final searchControllerProvider =
    AsyncNotifierProvider<SearchController, List<SearchResult>>(SearchController.new);

class SearchController extends AsyncNotifier<List<SearchResult>> {
  @override
  Future<List<SearchResult>> build() async => const [];

  /// Ищет только nocode-треки своего агента.
  Future<void> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      state = const AsyncValue.data([]);
      return;
    }

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(searchRepositoryProvider);
      return repo.searchNoCodeTracks(trimmed);
    });
  }

  /// Загружает фото и возвращает URL. null при ошибке.
  Future<String?> uploadBindingPhoto(Uint8List bytes, String fileName) {
    final repo = ref.read(searchRepositoryProvider);
    return repo.uploadBindingPhoto(bytes, fileName);
  }

  Future<bool> requestBinding({
    required int trackId,
    required String trackNumber,
    required String clientCode,
    required int clientId,
    required int? clientCodeId,
    String? currentClientCode,
    required String photoUrl,
  }) async {
    try {
      final repo = ref.read(searchRepositoryProvider);
      await repo.requestBinding(
        trackId: trackId,
        trackNumber: trackNumber,
        clientCode: clientCode,
        clientId: clientId,
        clientCodeId: clientCodeId,
        currentClientCode: currentClientCode,
        photoUrl: photoUrl,
      );

      // Локально помечаем трек как имеющий pending-вопрос.
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
              showBindButton: false,
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
