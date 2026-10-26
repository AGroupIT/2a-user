import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:twoalogisticcabineuser/src/core/network/api_client.dart';
import 'package:twoalogisticcabineuser/src/features/tracks/data/tracks_provider.dart';

class _Api extends Mock implements ApiClient {}

void main() {
  late _Api api;
  late ProviderContainer container;
  setUp(() {
    api = _Api();
    container = ProviderContainer(
      overrides: [apiClientProvider.overrideWithValue(api)],
    );
  });
  tearDown(() => container.dispose());

  test(
    'loads agent options and submits explicit type, exact displayed price and custom wish',
    () async {
      when(() => api.get('/client/photo-report-options')).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/client/photo-report-options'),
          data: {
            'data': {
              'standard': {'enabled': false, 'priceUsd': '0.00'},
              'custom': {'enabled': true, 'priceUsd': '7.50'},
            },
          },
        ),
      );
      Map<String, dynamic>? payload;
      when(
        () => api.post('/photo-requests', data: any(named: 'data')),
      ).thenAnswer((call) async {
        payload = Map<String, dynamic>.from(call.namedArguments[#data] as Map);
        return Response(
          requestOptions: RequestOptions(path: '/photo-requests'),
          statusCode: 201,
        );
      });
      final service = container.read(tracksApiServiceProvider);
      final options = await service.photoReportOptions();
      expect(options.standard.enabled, isFalse);
      expect(options.custom.priceUsd, '7.50');
      expect(
        await service.createPhotoRequest(
          clientId: 2,
          clientCodeId: 3,
          trackId: 4,
          trackNumber: 'TEST-004',
          reportType: 'custom',
          expectedPriceUsd: options.custom.priceUsd,
          wish: 'Inspect size',
        ),
        isTrue,
      );
      expect(payload, containsPair('reportType', 'custom'));
      expect(payload, containsPair('expectedPriceUsd', '7.50'));
      expect(payload, containsPair('wish', 'Inspect size'));
    },
  );

  test('changed price never silently retries or accepts new amount', () async {
    final request = RequestOptions(path: '/photo-requests');
    when(() => api.post('/photo-requests', data: any(named: 'data'))).thenThrow(
      DioException(
        requestOptions: request,
        response: Response(
          requestOptions: request,
          statusCode: 409,
          data: {'code': 'photo_report_price_changed'},
        ),
      ),
    );
    final service = container.read(tracksApiServiceProvider);
    expect(
      await service.createPhotoRequest(
        clientId: 2,
        clientCodeId: 3,
        trackId: 4,
        trackNumber: 'TEST-004',
        reportType: 'custom',
        expectedPriceUsd: '5.00',
        wish: 'Inspect',
      ),
      isFalse,
    );
    expect(service.lastPhotoRequestErrorCode, 'photo_report_price_changed');
    verify(
      () => api.post('/photo-requests', data: any(named: 'data')),
    ).called(1);
  });

  test(
    'same-type wish update carries saved snapshot and can clear standard wishes',
    () async {
      Map<String, dynamic>? payload;
      when(
        () => api.patch('/photo-requests/7', data: any(named: 'data')),
      ).thenAnswer((call) async {
        payload = Map<String, dynamic>.from(call.namedArguments[#data] as Map);
        return Response(
          requestOptions: RequestOptions(path: '/photo-requests/7'),
          statusCode: 200,
        );
      });
      final service = container.read(tracksApiServiceProvider);
      expect(
        await service.updatePhotoWish(
          7,
          '',
          reportType: 'standard',
          expectedPriceUsd: '0.00',
        ),
        isTrue,
      );
      expect(payload, {
        'wish': '',
        'reportType': 'standard',
        'expectedPriceUsd': '0.00',
      });
    },
  );
}
