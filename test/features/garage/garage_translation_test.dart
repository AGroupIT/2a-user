import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:twoalogisticcabineuser/src/core/network/api_client.dart';
import 'package:twoalogisticcabineuser/src/features/garage/presentation/garage_translated_text.dart';

void main() {
  testWidgets('Garage translation is automatic and cached in memory', (
    tester,
  ) async {
    final apiClient = _MockApiClient();
    when(
      () => apiClient.post<Map<String, dynamic>>(
        '/translate',
        data: any<dynamic>(named: 'data'),
      ),
    ).thenAnswer(
      (_) async => Response<Map<String, dynamic>>(
        requestOptions: RequestOptions(path: '/translate'),
        data: const {'translation': 'Тормозные колодки'},
        statusCode: 200,
      ),
    );
    final service = GarageTranslationService(apiClient);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          garageTranslationServiceProvider.overrideWithValue(service),
        ],
        child: const MaterialApp(
          home: Column(
            children: [
              GarageTranslatedText('刹车片'),
              GarageTranslatedText('刹车片'),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Тормозные колодки'), findsNWidgets(2));
    verify(
      () => apiClient.post<Map<String, dynamic>>(
        '/translate',
        data: any<dynamic>(named: 'data'),
      ),
    ).called(1);
  });

  testWidgets('Garage translation fails open to source text', (tester) async {
    final apiClient = _MockApiClient();
    when(
      () => apiClient.post<Map<String, dynamic>>(
        '/translate',
        data: any<dynamic>(named: 'data'),
      ),
    ).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: '/translate'),
        type: DioExceptionType.connectionError,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          garageTranslationServiceProvider.overrideWithValue(
            GarageTranslationService(apiClient),
          ),
        ],
        child: const MaterialApp(home: GarageTranslatedText('刹车片')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('刹车片'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test(
    'Garage translation serializes a batch and cools down after 503',
    () async {
      final apiClient = _MockApiClient();
      final firstResponse = Completer<Response<Map<String, dynamic>>>();
      var calls = 0;
      when(
        () => apiClient.post<Map<String, dynamic>>(
          '/translate',
          data: any<dynamic>(named: 'data'),
        ),
      ).thenAnswer((_) {
        calls += 1;
        return firstResponse.future;
      });
      final service = GarageTranslationService(apiClient);

      final first = service.translateToRussian('刹车片');
      final second = service.translateToRussian('发动机');
      await Future<void>.delayed(Duration.zero);
      expect(calls, 1);

      firstResponse.completeError(
        DioException(
          requestOptions: RequestOptions(path: '/translate'),
          response: Response<Map<String, dynamic>>(
            requestOptions: RequestOptions(path: '/translate'),
            statusCode: 503,
            data: const {'retryAfterMs': 60000},
          ),
          type: DioExceptionType.badResponse,
        ),
      );

      expect(await first, isNull);
      expect(await second, isNull);
      expect(calls, 1);
      expect(await service.translateToRussian('变速箱'), isNull);
      expect(calls, 1);
    },
  );
}

class _MockApiClient extends Mock implements ApiClient {}
