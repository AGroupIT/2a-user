import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http_parser/http_parser.dart';

import '../../../core/network/api_client.dart';
import '../domain/search_result.dart';

enum TrackBindingRequestErrorCode {
  trackNotFound,
  trackNotAvailable,
  requestExists,
  clientCodeRequired,
  clientCodeNotOwned,
  clientCodeMismatch,
  proofRequired,
  unauthorized,
  unknown;

  static TrackBindingRequestErrorCode fromApi(String? code, {int? statusCode}) {
    return switch (code) {
      'TRACK_NOT_FOUND' => trackNotFound,
      'TRACK_NOT_AVAILABLE' => trackNotAvailable,
      'BINDING_REQUEST_EXISTS' => requestExists,
      'CLIENT_CODE_REQUIRED' => clientCodeRequired,
      'CLIENT_CODE_NOT_OWNED' => clientCodeNotOwned,
      'CLIENT_CODE_MISMATCH' => clientCodeMismatch,
      'BINDING_PROOF_REQUIRED' => proofRequired,
      _ when statusCode == 401 => unauthorized,
      _ => unknown,
    };
  }
}

class TrackBindingRequestException implements Exception {
  const TrackBindingRequestException({required this.code, this.statusCode});

  final TrackBindingRequestErrorCode code;
  final int? statusCode;
}

class TrackBindingRequestResult {
  const TrackBindingRequestResult._({required this.isSuccess, this.errorCode});

  const TrackBindingRequestResult.success() : this._(isSuccess: true);

  const TrackBindingRequestResult.failure(
    TrackBindingRequestErrorCode errorCode,
  ) : this._(isSuccess: false, errorCode: errorCode);

  final bool isSuccess;
  final TrackBindingRequestErrorCode? errorCode;
}

class SearchResultsPage {
  const SearchResultsPage({
    required this.items,
    required this.total,
    required this.hasMore,
  });

  final List<SearchResult> items;
  final int total;
  final bool hasMore;
}

/// Репозиторий для поиска трек-номеров без привязки к коду клиента (nocode).
/// Предназначен для экрана `TrackSearchNoCodeScreen`.
abstract class SearchRepository {
  /// Поиск ТОЛЬКО по nocode-трекам своего агента (фильтр по trackNumber contains).
  Future<List<SearchResult>> searchNoCodeTracks(String query);

  /// Серверная страница каталога NOCODE. Пустой [query] означает весь каталог.
  Future<SearchResultsPage> fetchNoCodeTracks({
    String query = '',
    int skip = 0,
    int take = 20,
  });

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
    final page = await fetchNoCodeTracks(query: query, take: 50);
    return page.items;
  }

  @override
  Future<SearchResultsPage> fetchNoCodeTracks({
    String query = '',
    int skip = 0,
    int take = 20,
  }) async {
    final q = query.trim();
    if (q.isNotEmpty && q.length < 3) {
      return const SearchResultsPage(items: [], total: 0, hasMore: false);
    }

    try {
      final response = await _api.get(
        '/client/search',
        queryParameters: {
          if (q.isNotEmpty) 'query': q,
          'onlyNocode': 'true',
          'skip': skip,
          'take': take,
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        final body = response.data;
        if (body is List) {
          final items = body
              .whereType<Map<String, dynamic>>()
              .map(SearchResult.fromJson)
              .toList();
          return SearchResultsPage(
            items: items,
            total: items.length,
            hasMore: false,
          );
        }
        if (body is Map<String, dynamic>) {
          final list = body['data'] ?? body['results'] ?? body['items'];
          if (list is List) {
            final items = list
                .whereType<Map<String, dynamic>>()
                .map(SearchResult.fromJson)
                .toList();
            final total = _asInt(body['total']) ?? items.length;
            final hasMore = body['hasMore'] is bool
                ? body['hasMore'] as bool
                : skip + items.length < total;
            return SearchResultsPage(
              items: items,
              total: total,
              hasMore: hasMore,
            );
          }
        }
      }
      return const SearchResultsPage(items: [], total: 0, hasMore: false);
    } on DioException catch (e) {
      debugPrint('[SearchRepository] fetchNoCodeTracks error: $e');
      rethrow;
    }
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
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
          'targetClientCode': clientCode,
          'questionType': 'track_binding',
          'question':
              'Прошу привязать трек $trackNumber$currentPart к моему коду клиента $clientCode',
          'photoUrls': [photoUrl],
        },
      );
    } on DioException catch (e) {
      debugPrint('[SearchRepository] requestBinding error: $e');
      final responseData = e.response?.data;
      final apiCode = responseData is Map
          ? responseData['code']?.toString()
          : null;
      throw TrackBindingRequestException(
        code: TrackBindingRequestErrorCode.fromApi(
          apiCode,
          statusCode: e.response?.statusCode,
        ),
        statusCode: e.response?.statusCode,
      );
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
