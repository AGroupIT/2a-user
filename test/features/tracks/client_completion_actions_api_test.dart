import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:twoalogisticcabineuser/src/core/network/api_client.dart';
import 'package:twoalogisticcabineuser/src/features/tracks/data/assemblies_provider.dart';
import 'package:twoalogisticcabineuser/src/features/tracks/data/tracks_provider.dart';

class _MockApiClient extends Mock implements ApiClient {}

void main() {
  test(
    'completed return confirmation sends mandatory acknowledgement',
    () async {
      final apiClient = _MockApiClient();
      when(
        () => apiClient.post(
          '/client/tracks/42/return/confirm',
          data: {'acknowledgePermanentRemoval': true},
        ),
      ).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(
            path: '/client/tracks/42/return/confirm',
          ),
          statusCode: 200,
          data: {
            'success': true,
            'changed': true,
            'deletedAt': '2026-09-01T08:00:00.000Z',
          },
        ),
      );
      final container = ProviderContainer(
        overrides: [apiClientProvider.overrideWithValue(apiClient)],
      );
      addTearDown(container.dispose);

      final result = await container
          .read(tracksApiServiceProvider)
          .confirmCompletedTrackReturn(42);

      expect(result, isTrue);
      verify(
        () => apiClient.post(
          '/client/tracks/42/return/confirm',
          data: {'acknowledgePermanentRemoval': true},
        ),
      ).called(1);
    },
  );

  test(
    'assembly receipt confirmation uses dedicated client endpoint',
    () async {
      final apiClient = _MockApiClient();
      when(
        () => apiClient.post('/client/assemblies/17/confirm-receipt'),
      ).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(
            path: '/client/assemblies/17/confirm-receipt',
          ),
          statusCode: 200,
          data: {'success': true, 'changed': true, 'status': 'delivered'},
        ),
      );
      final container = ProviderContainer(
        overrides: [apiClientProvider.overrideWithValue(apiClient)],
      );
      addTearDown(container.dispose);

      final result = await container
          .read(assembliesApiServiceProvider)
          .confirmAssemblyReceipt(17);

      expect(result, isTrue);
      verify(
        () => apiClient.post('/client/assemblies/17/confirm-receipt'),
      ).called(1);
    },
  );
}
