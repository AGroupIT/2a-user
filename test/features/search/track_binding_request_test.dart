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
    'controller exposes localized actionable error and legacy DTO parses',
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
    },
  );
}

class _SearchApiClient extends ApiClient {
  _SearchApiClient({this.statusCode = 201, this.responseData = const {}});

  final int statusCode;
  final Map<String, dynamic> responseData;
  String? path;
  Map<String, dynamic>? data;

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
