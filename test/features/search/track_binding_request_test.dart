import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twoalogisticcabineuser/src/core/network/api_client.dart';
import 'package:twoalogisticcabineuser/src/features/search/data/fake_search_repository.dart';
import 'package:twoalogisticcabineuser/src/features/search/domain/search_result.dart';
import 'package:twoalogisticcabineuser/src/features/search/presentation/search_controller.dart';

void main() {
  test(
    'binding request sends typed target fields and keeps legacy question',
    () async {
      final api = _SearchApiClient();
      final container = ProviderContainer(
        overrides: [apiClientProvider.overrideWithValue(api)],
      );
      addTearDown(container.dispose);
      final repository = container.read(searchRepositoryProvider);

      await repository.requestBinding(
        trackId: 77,
        trackNumber: 'YT7640716186557',
        clientCode: '2A-2706',
        clientId: 12,
        clientCodeId: 34,
        currentClientCode: 'NOCODE',
        photoUrl: '/uploads/general/proof.jpg',
      );

      expect(api.path, '/questions');
      expect(api.data?['questionType'], 'track_binding');
      expect(api.data?['clientCodeId'], 34);
      expect(api.data?['targetClientCode'], '2A-2706');
      expect(api.data?['photoUrls'], ['/uploads/general/proof.jpg']);
      expect(api.data?['question'], contains('к моему коду клиента 2A-2706'));
    },
  );

  test('typed backend error is preserved instead of becoming false', () async {
    final api = _SearchApiClient(
      statusCode: 409,
      responseData: const {
        'code': 'BINDING_REQUEST_EXISTS',
        'error': 'already exists',
      },
    );
    final container = ProviderContainer(
      overrides: [apiClientProvider.overrideWithValue(api)],
    );
    addTearDown(container.dispose);
    final repository = container.read(searchRepositoryProvider);

    await expectLater(
      repository.requestBinding(
        trackId: 77,
        trackNumber: 'YT7640716186557',
        clientCode: '2A-2706',
        clientId: 12,
        clientCodeId: null,
        photoUrl: '/uploads/general/proof.jpg',
      ),
      throwsA(
        isA<TrackBindingRequestException>().having(
          (error) => error.code,
          'code',
          TrackBindingRequestErrorCode.requestExists,
        ),
      ),
    );
  });

  test(
    'controller exposes localized actionable error and legacy DTO parses safely',
    () {
      expect(
        trackBindingRequestErrorMessage(
          TrackBindingRequestErrorCode.trackNotAvailable,
          isZh: false,
        ),
        contains('уже привязан'),
      );
      expect(
        trackBindingRequestErrorMessage(
          TrackBindingRequestErrorCode.trackNotAvailable,
          isZh: true,
        ),
        contains('已绑定'),
      );

      final legacy = SearchResult.fromJson({
        'id': 77,
        'trackNumber': 'YT7640716186557',
        'updatedAt': '2026-08-29T00:00:00.000Z',
        'isNocode': true,
        'showBindButton': true,
      });
      expect(legacy.trackCode, 'YT7640716186557');
      expect(legacy.showBindButton, isTrue);
      expect(legacy.hasPhotoReportRequest, isFalse);
      expect(legacy.photoReportPhotos, isEmpty);

      final updated = legacy.copyWith(
        hasQuestion: true,
        hasPendingQuestion: true,
        showBindButton: false,
      );
      expect(updated.hasPendingQuestion, isTrue);
      expect(updated.photoReportPhotos, isEmpty);
    },
  );

  test(
    'NOCODE catalog loads without query and parses photos plus paging',
    () async {
      final api = _SearchApiClient(
        getResponseData: {
          'results': [
            {
              'id': 91,
              'trackNumber': 'YT-NOCODE-91',
              'updatedAt': '2026-09-02T00:00:00.000Z',
              'isNocode': true,
              'hasPhotoReportRequest': true,
              'photoReportStatus': 'completed',
              'photoReportPhotos': [
                {
                  'id': 701,
                  'url': '/uploads/photo-reports/item.jpg',
                  'createdAt': '2026-09-02T01:00:00.000Z',
                },
              ],
            },
          ],
          'total': 3,
          'hasMore': true,
        },
      );
      final container = ProviderContainer(
        overrides: [apiClientProvider.overrideWithValue(api)],
      );
      addTearDown(container.dispose);

      final page = await container
          .read(searchRepositoryProvider)
          .fetchNoCodeTracks(skip: 0, take: 1);

      expect(api.path, '/client/search');
      expect(api.queryParameters, {'onlyNocode': 'true', 'skip': 0, 'take': 1});
      expect(page.total, 3);
      expect(page.hasMore, isTrue);
      expect(page.items.single.photoReportStatus, 'completed');
      expect(page.items.single.photoReportPhotos.single.id, 701);
      expect(
        page.items.single.photoReportPhotos.single.trackingNumber,
        'YT-NOCODE-91',
      );
    },
  );

  test('legacy list response remains readable by NOCODE repository', () async {
    final api = _SearchApiClient(
      getResponseData: [
        {
          'id': 92,
          'trackNumber': 'YT-NOCODE-92',
          'updatedAt': '2026-09-02T00:00:00.000Z',
          'isNocode': true,
        },
      ],
    );
    final container = ProviderContainer(
      overrides: [apiClientProvider.overrideWithValue(api)],
    );
    addTearDown(container.dispose);

    final page = await container
        .read(searchRepositoryProvider)
        .fetchNoCodeTracks(query: 'NOCODE');

    expect(page.items.single.trackCode, 'YT-NOCODE-92');
    expect(page.total, 1);
    expect(page.hasMore, isFalse);
    expect(api.queryParameters?['query'], 'NOCODE');
  });

  test(
    'catalog controller loads first page immediately and appends the next',
    () async {
      final repository = _PagedSearchRepository();
      final container = ProviderContainer(
        overrides: [searchRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final initial = await container.read(searchControllerProvider.future);
      expect(initial.items.map((item) => item.id), [1]);
      expect(repository.calls, [(query: '', skip: 0, take: 20)]);

      await container.read(searchControllerProvider.notifier).loadMore();
      final loaded = container.read(searchControllerProvider).requireValue;
      expect(loaded.items.map((item) => item.id), [1, 2]);
      expect(loaded.hasMore, isFalse);
      expect(repository.calls.last, (query: '', skip: 1, take: 20));
    },
  );
}

class _PagedSearchRepository implements SearchRepository {
  final calls = <({String query, int skip, int take})>[];

  @override
  Future<SearchResultsPage> fetchNoCodeTracks({
    String query = '',
    int skip = 0,
    int take = 20,
  }) async {
    calls.add((query: query, skip: skip, take: take));
    return SearchResultsPage(
      items: [
        SearchResult(
          id: skip + 1,
          trackCode: 'NOCODE-${skip + 1}',
          status: 'На складе',
          updatedAt: DateTime.utc(2026, 9, 2),
          isNocode: true,
        ),
      ],
      total: 2,
      hasMore: skip == 0,
    );
  }

  @override
  Future<List<SearchResult>> searchNoCodeTracks(String query) async {
    return (await fetchNoCodeTracks(query: query, take: 50)).items;
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
  }) async {}

  @override
  Future<String?> uploadBindingPhoto(Uint8List bytes, String fileName) async {
    return null;
  }
}

class _SearchApiClient extends ApiClient {
  _SearchApiClient({
    this.statusCode = 201,
    this.responseData = const {},
    this.getResponseData,
  });

  final int statusCode;
  final Map<String, dynamic> responseData;
  final dynamic getResponseData;
  String? path;
  Map<String, dynamic>? data;
  Map<String, dynamic>? queryParameters;

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    this.path = path;
    this.queryParameters = queryParameters;
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      statusCode: 200,
      data: getResponseData as T,
    );
  }

  @override
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    this.path = path;
    this.data = Map<String, dynamic>.from(data as Map);
    final requestOptions = RequestOptions(path: path);
    final response = Response<T>(
      requestOptions: requestOptions,
      statusCode: statusCode,
      data: responseData as T,
    );
    if (statusCode >= 400) {
      throw DioException(
        requestOptions: requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
      );
    }
    return response;
  }
}
