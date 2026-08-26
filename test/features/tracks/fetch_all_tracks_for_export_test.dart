import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:twoalogisticcabineuser/src/core/network/api_client.dart';
import 'package:twoalogisticcabineuser/src/features/tracks/data/tracks_provider.dart';

class _MockApiClient extends Mock implements ApiClient {}

void main() {
  test('загружает для экспорта все страницы треков', () async {
    final apiClient = _MockApiClient();

    when(
      () => apiClient.get(
        '/tracks',
        queryParameters: any(named: 'queryParameters'),
      ),
    ).thenAnswer((invocation) async {
      final query =
          invocation.namedArguments[#queryParameters] as Map<String, dynamic>;
      final skip = query['skip'] as int;
      final items = skip == 0
          ? [_trackJson(1), _trackJson(2)]
          : [_trackJson(3)];

      return Response<Map<String, dynamic>>(
        requestOptions: RequestOptions(path: '/tracks'),
        statusCode: 200,
        data: {'data': items, 'total': 3, 'hasMore': skip == 0},
      );
    });

    final tracks = await fetchAllTracksForExport(
      apiClient,
      '2A-01',
      batchSize: 2,
    );

    expect(tracks.map((track) => track.code), [
      'TRACK-1',
      'TRACK-2',
      'TRACK-3',
    ]);
    expect(tracks.map((track) => track.invoiceNumber), [
      'INV-1',
      'INV-2',
      'INV-3',
    ]);
    verify(
      () => apiClient.get(
        '/tracks',
        queryParameters: {
          'clientCode': '2A-01',
          'take': 2,
          'skip': 0,
          'sortBy': 'createdAt',
        },
      ),
    ).called(1);
    verify(
      () => apiClient.get(
        '/tracks',
        queryParameters: {
          'clientCode': '2A-01',
          'take': 2,
          'skip': 2,
          'sortBy': 'createdAt',
        },
      ),
    ).called(1);
  });
}

Map<String, dynamic> _trackJson(int id) => {
  'id': id,
  'code': 'TRACK-$id',
  'status': 'pending',
  'statusName': 'В ожидании',
  'createdAt': '2026-08-26T10:00:00.000Z',
  'updatedAt': '2026-08-26T10:00:00.000Z',
  'invoiceNumber': 'INV-$id',
  'productInfo': [
    {
      'id': id,
      'name': 'Товар $id',
      'quantity': 1,
      'imageUrl': '/uploads/product-$id.jpg',
    },
  ],
  'photoRequests': const [],
  'photos': const [],
  'assembly': {
    'id': id,
    'number': 'SB-$id',
    'status': 'created',
    'invoiceNumber': 'INV-$id',
  },
};
