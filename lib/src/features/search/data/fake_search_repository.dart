import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http_parser/http_parser.dart';

import '../../../core/network/api_client.dart';
import '../domain/search_result.dart';

/// Репозиторий для поиска трек-номеров без привязки к коду клиента (nocode).
/// Предназначен для экрана `TrackSearchNoCodeScreen`.
abstract class SearchRepository {
  /// Поиск ТОЛЬКО по nocode-трекам своего агента (фильтр по trackNumber contains).
  Future<List<SearchResult>> searchNoCodeTracks(String query);

  /// Запрос привязки трека с приложенным скрином логистики.
  /// [photoUrl] получен через [uploadBindingPhoto].
  Future<void> requestBinding({
    required int trackId,
    required String trackNumber,
    required String clientCode,
    required int clientId,
    required int? clientCodeId,
    String? currentClientCode,
    required String photoUrl,
  });

  /// Загружает скрин логистики и возвращает URL на сервере.
  Future<String?> uploadBindingPhoto(Uint8List bytes, String fileName);
}

final searchRepositoryProvider = Provider<SearchRepository>((ref) {
  return RealSearchRepository(ref);
});

class RealSearchRepository implements SearchRepository {
  final Ref _ref;

  RealSearchRepository(this._ref);

  ApiClient get _api => _ref.read(apiClientProvider);

  @override
  Future<List<SearchResult>> searchNoCodeTracks(String query) async {
    final q = query.trim();
    if (q.length < 3) return const [];

    try {
      final response = await _api.get(
        '/client/search',
        queryParameters: {
          'query': q,
          'onlyNocode': 'true',
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        final body = response.data;
        if (body is List) {
          return body
              .whereType<Map<String, dynamic>>()
              .map(SearchResult.fromJson)
              .toList();
        }
        if (body is Map<String, dynamic>) {
          final list = body['data'] ?? body['results'] ?? body['items'];
          if (list is List) {
            return list
                .whereType<Map<String, dynamic>>()
                .map(SearchResult.fromJson)
                .toList();
          }
        }
      }
      return const [];
    } on DioException catch (e) {
      debugPrint('[SearchRepository] searchNoCodeTracks error: $e');
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
    String? currentClientCode,
    required String photoUrl,
  }) async {
    try {
      final currentPart =
          (currentClientCode != null && currentClientCode.isNotEmpty)
              ? ' - ($currentClientCode)'
              : ' - (nocode)';
      await _api.post(
        '/questions',
        data: {
          'trackId': trackId,
          'trackNumber': trackNumber,
          'clientId': clientId,
          'clientCodeId': clientCodeId,
          'question':
              'Прошу привязать трек $trackNumber$currentPart к моему коду клиента $clientCode',
          'photoUrls': [photoUrl],
        },
      );
    } on DioException catch (e) {
      debugPrint('[SearchRepository] requestBinding error: $e');
      rethrow;
    }
  }

  @override
  Future<String?> uploadBindingPhoto(Uint8List bytes, String fileName) async {
    try {
      final mimeType = _mimeTypeFromName(fileName);
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          bytes,
          filename: fileName,
          contentType: MediaType.parse(mimeType),
        ),
        'type': 'track-binding-proof',
      });
      final response = await _api.post('/photos/upload', data: formData);
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;
        if (data is Map<String, dynamic>) {
          return data['url'] as String?;
        }
      }
      return null;
    } on DioException catch (e) {
      debugPrint('[SearchRepository] uploadBindingPhoto error: $e');
      return null;
    }
  }

  String _mimeTypeFromName(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.heic')) return 'image/heic';
    return 'image/jpeg';
  }
}
