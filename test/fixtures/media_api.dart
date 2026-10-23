import 'package:dio/dio.dart';
import 'package:mocktail/mocktail.dart';
import 'package:twoalogisticcabineuser/src/core/network/api_client.dart';

class _MediaFixtureApi extends Mock implements ApiClient {}

/// Widget fixtures exercise placeholders without invoking platform credential
/// storage or a real network request for their sample operational photo URLs.
ApiClient mediaFixtureApi() {
  final api = _MediaFixtureApi();
  when(() => api.getToken()).thenAnswer((_) async => 'widget-fixture-session');
  when(
    () => api.getMediaCacheIdentity(),
  ).thenAnswer((_) async => 'widget-fixture-session');
  when(
    () => api.get<List<int>>(any(), options: any(named: 'options')),
  ).thenThrow(
    DioException(
      requestOptions: RequestOptions(path: '/uploads/widget-fixture'),
      type: DioExceptionType.badResponse,
    ),
  );
  when(
    () => api.getWithProgress<List<int>>(
      any(),
      options: any(named: 'options'),
      onReceiveProgress: any(named: 'onReceiveProgress'),
    ),
  ).thenThrow(
    DioException(
      requestOptions: RequestOptions(path: '/uploads/widget-fixture'),
      type: DioExceptionType.badResponse,
    ),
  );
  return api;
}
