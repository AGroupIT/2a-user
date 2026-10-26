import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:twoalogisticcabineuser/src/core/network/api_client.dart';
import 'package:twoalogisticcabineuser/src/features/tracks/data/assemblies_provider.dart';

class _Api extends Mock implements ApiClient {}

void main() {
  test(
    'lost response retry preserves key, parses both insured assemblies',
    () async {
      final api = _Api();
      final bodies = <Map<String, dynamic>>[];
      when(() => api.post('/assemblies', data: any(named: 'data'))).thenAnswer((
        call,
      ) async {
        bodies.add(
          Map<String, dynamic>.from(call.namedArguments[#data] as Map),
        );
        if (bodies.length == 1) {
          throw DioException(
            requestOptions: RequestOptions(path: '/assemblies'),
            type: DioExceptionType.receiveTimeout,
          );
        }
        return Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: '/assemblies'),
          statusCode: 201,
          data: {
            'assemblies': [
              {
                'id': 10,
                'number': 'A-10',
                'hasInsurance': true,
                'insuranceAmount': 1000,
              },
              {
                'id': 11,
                'number': 'B-11',
                'hasInsurance': true,
                'insuranceAmount': 1000,
              },
            ],
          },
        );
      });
      final container = ProviderContainer(
        overrides: [apiClientProvider.overrideWithValue(api)],
      );
      addTearDown(container.dispose);
      final service = container.read(assembliesApiServiceProvider);
      Future<AssemblyCreateResult> create({bool reverse = false}) =>
          service.createAssembly(
            clientId: 3,
            trackIds: reverse ? [2, 1] : [1, 2],
            hasInsurance: true,
            insuranceAmount: 1000,
          );
      expect((await create()).isSuccess, isFalse);
      final result = await create(reverse: true);
      expect(result.isSuccess, isTrue);
      expect(result.assembly!.id, 10);
      expect(result.assemblies.map((a) => a.id), [10, 11]);
      expect(result.assemblies.map((a) => a.insuranceAmount), [1000, 1000]);
      expect(bodies[0]['assemblyRequestId'], bodies[1]['assemblyRequestId']);
      expect(bodies[0]['assemblyBatchProtocol'], 1);
      expect(bodies[0]['insuranceAmount'], 1000);
      await create();
      expect(
        bodies[2]['assemblyRequestId'],
        isNot(bodies[1]['assemblyRequestId']),
      );
    },
  );

  test('legacy single response remains a one-item batch', () async {
    final api = _Api();
    when(() => api.post('/assemblies', data: any(named: 'data'))).thenAnswer(
      (_) async => Response<Map<String, dynamic>>(
        requestOptions: RequestOptions(path: '/assemblies'),
        statusCode: 201,
        data: {'id': 9, 'number': 'A-9'},
      ),
    );
    final container = ProviderContainer(
      overrides: [apiClientProvider.overrideWithValue(api)],
    );
    addTearDown(container.dispose);
    final result = await container
        .read(assembliesApiServiceProvider)
        .createAssembly(clientId: 3, trackIds: [1]);
    expect(result.assemblies.single.id, 9);
    expect(result.assembly, same(result.assemblies.single));
    expect(() => result.assemblies.clear(), throwsUnsupportedError);
  });
}
