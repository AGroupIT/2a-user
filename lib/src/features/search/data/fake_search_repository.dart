import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../domain/search_result.dart';

abstract class SearchRepository {
  Future<List<SearchResult>> searchTracks(String query);
  Future<void> requestBinding({
    required int trackId,
    required String trackNumber,
    required String clientCode,
    required int clientId,
    required int? clientCodeId,
  });
}

final searchRepositoryProvider = Provider<SearchRepository>((ref) {
  return RealSearchRepository(ref);
});

class RealSearchRepository implements SearchRepository {
  final Ref _ref;
  
  RealSearchRepository(this._ref);
  
  ApiClient get _api => _ref.read(apiClientProvider);

  @override
  Future<List<SearchResult>> searchTracks(String query) async {
    final q = query.trim();
    if (q.length < 5) return const [];

    try {
      final response = await _api.get(
        '/client/search',
        queryParameters: {'query': q},
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final results = data['results'] as List<dynamic>? ?? [];
        return results
            .map((json) => SearchResult.fromJson(json as Map<String, dynamic>))
            .toList();
      }
      return [];
    } on DioException catch (e) {
      debugPrint('Error searching tracks: $e');
      rethrow;
    }
  }

  @override
  Future<void> requestBinding({
    required int trackId,
    required String trackNumber,
    required String clientCode,
    required int clientId,
    required int? clientCodeId,
  }) async {
    try {
      await _api.post(
        '/questions',
        data: {
          'trackId': trackId,
          'trackNumber': trackNumber,
          'clientId': clientId,
          'clientCodeId': clientCodeId,
          'question': 'Прошу привязать трек $trackNumber к моему коду клиента $clientCode',
        },
      );
    } on DioException catch (e) {
      debugPrint('Error requesting binding: $e');
      rethrow;
    }
  }
}
