import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/search_result.dart';

abstract class SearchRepository {
  Future<List<SearchResult>> searchTracks(String query);
}

final searchRepositoryProvider = Provider<SearchRepository>((ref) {
  return FakeSearchRepository();
});

class FakeSearchRepository implements SearchRepository {
  static const _statuses = <String>[
    'В ожидании',
    'На складе',
    'На сборке',
    'Отправлен',
    'Получен',
  ];

  @override
  Future<List<SearchResult>> searchTracks(String query) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    final q = query.trim();
    if (q.length < 5) return const [];

    final rng = Random(q.hashCode);
    final count = rng.nextInt(8);
    final now = DateTime.now();

    return List.generate(count, (i) {
      final code = q.toUpperCase().contains('TRK') ? q.toUpperCase() : 'TRK-$q-${100 + i}';
      return SearchResult(
        trackCode: code,
        status: _statuses[rng.nextInt(_statuses.length)],
        updatedAt: now.subtract(Duration(days: rng.nextInt(30), hours: rng.nextInt(12))),
        clientCode: rng.nextBool() ? '2A-${10 + rng.nextInt(90)}' : null,
      );
    });
  }
}

