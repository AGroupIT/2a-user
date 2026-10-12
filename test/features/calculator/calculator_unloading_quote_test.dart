import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twoalogisticcabineuser/src/core/network/api_client.dart';
import 'package:twoalogisticcabineuser/src/features/auth/data/auth_provider.dart';
import 'package:twoalogisticcabineuser/src/features/calculator/presentation/calculator_screen.dart';

class _Auth extends AuthNotifier {
  @override
  AuthState build() => const AuthState(isLoading: false, clientId: 17);
}

class _Api implements ApiClient {
  final requests = <Map<String, dynamic>>[];

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    final data = switch (path) {
      '/tariffs' => {
        'tariffs': [
          {'id': 1, 'name': 'Весовой', 'baseCost': 4, 'paidPhotoReport': false},
        ],
      },
      '/photo-report-coefficients' => {'coefficients': <dynamic>[]},
      '/packagings' => {
        'packagings': [
          {'id': 10, 'name': 'Коробка', 'baseCost': 0},
        ],
      },
      _ => throw StateError('Unexpected GET $path'),
    };
    return Response<T>(
      data: data as T,
      requestOptions: RequestOptions(path: path),
    );
  }

  @override
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    expect(path, '/client/unloading-quote');
    requests.add(Map<String, dynamic>.from(data as Map));
    return Response<T>(
      data:
          {
                'data': {'clientCostUsd': 9.23},
              }
              as T,
      requestOptions: RequestOptions(path: path),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Finder _field(String label) => find.descendant(
  of: find.ancestor(of: find.text(label), matching: find.byType(Column)).first,
  matching: find.byType(TextFormField),
);

Future<void> _settleQuote(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 250));
}

void main() {
  testWidgets(
    'unloading quote uses weight and places before volume is entered',
    (tester) async {
      final api = _Api();
      await tester.binding.setSurfaceSize(const Size(1200, 1500));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(api),
            authProvider.overrideWith(_Auth.new),
          ],
          child: const MaterialApp(home: Scaffold(body: CalculatorScreen())),
        ),
      );
      await _settleQuote(tester);
      await tester.enterText(_field('Вес, кг'), '8,5');
      await _settleQuote(tester);
      expect(api.requests.last, {
        'weightKg': 8.5,
        'volumeM3': 0.0,
        'placesCount': 1,
        'packagingTypeIds': [10],
      });

      await tester.enterText(_field('Мест'), '3');
      await _settleQuote(tester);
      expect(api.requests.last['placesCount'], 3);
      await tester.enterText(_field('Вес, кг'), '10.5');
      await _settleQuote(tester);
      expect(api.requests.last['weightKg'], 10.5);

      await tester.enterText(_field('Объём, м³'), '0.2');
      await tester.enterText(_field('Треков всего'), '1');
      await _settleQuote(tester);
      expect(api.requests.last['volumeM3'], 0.2);
      expect(find.text('\$9.23'), findsOneWidget);
      expect(find.text('по объёму, минимум \$5'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 10));
    },
  );
}
