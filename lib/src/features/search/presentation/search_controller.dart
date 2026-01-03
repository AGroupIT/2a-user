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
}

