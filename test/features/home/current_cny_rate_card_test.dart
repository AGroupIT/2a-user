import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twoalogisticcabineuser/src/core/network/api_client.dart';
import 'package:twoalogisticcabineuser/src/features/home/data/current_cny_rate_provider.dart';
import 'package:twoalogisticcabineuser/src/features/home/presentation/home_cny_rate_card.dart';

void main() {
  test('repository requests the client-safe current rate endpoint', () async {
    final apiClient = _RateApiClient();
    final rate = await CurrentCnyRateRepository(apiClient).fetch();

    expect(apiClient.lastPath, '/client/currency-rate');
    expect(rate?.date, DateTime(2026, 8, 15));
    expect(rate?.rubPerCny, 12.5);
  });

  test('CurrentCnyRate parses the public client payload', () {
    final rate = CurrentCnyRate.fromJson({
      'date': '2026-08-15',
      'clientCnyRubRate': '12.50',
    });

    expect(rate.date, DateTime(2026, 8, 15));
    expect(rate.rubPerCny, 12.5);
  });

  test('CurrentCnyRate rejects invalid values', () {
    expect(
      () => CurrentCnyRate.fromJson({
        'date': '2026-08-15',
        'clientCnyRubRate': 0,
      }),
      throwsFormatException,
    );
  });

  testWidgets('shows the current rate and publication date', (tester) async {
    await _pumpCard(
      tester,
      AsyncValue.data(
        CurrentCnyRate(date: DateTime(2026, 8, 15), rubPerCny: 12.5),
      ),
    );

    expect(find.text('Актуальный курс юаня'), findsOneWidget);
    expect(find.text('1 ¥ = 12,50 ₽'), findsOneWidget);
    expect(find.text('Курс на 15.08.2026'), findsOneWidget);
  });

  testWidgets('shows loading and retry states', (tester) async {
    await _pumpCard(tester, const AsyncValue.loading());
    expect(find.text('Обновляем курс'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    var retried = false;
    await _pumpCard(
      tester,
      AsyncValue.error(Exception('offline'), StackTrace.empty),
      onRetry: () => retried = true,
    );
    expect(find.text('Курс временно недоступен'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.refresh_rounded));
    expect(retried, isTrue);
  });

  testWidgets('fits compact width and localizes the rate for Chinese', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpCard(
      tester,
      AsyncValue.data(
        CurrentCnyRate(date: DateTime(2026, 8, 15), rubPerCny: 12.5),
      ),
      locale: const Locale('zh'),
      width: 288,
    );

    expect(find.text('当前人民币汇率'), findsOneWidget);
    expect(find.text('1 ¥ = 12.50 ₽'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _RateApiClient extends ApiClient {
  String? lastPath;

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    lastPath = path;
    return Response<T>(
      data:
          <String, dynamic>{
                'data': {'date': '2026-08-15', 'clientCnyRubRate': 12.5},
              }
              as T,
      requestOptions: RequestOptions(path: path),
      statusCode: 200,
    );
  }
}

Future<void> _pumpCard(
  WidgetTester tester,
  AsyncValue<CurrentCnyRate?> rate, {
  VoidCallback? onRetry,
  Locale locale = const Locale('ru'),
  double width = 390,
}) {
  return tester.pumpWidget(
    MaterialApp(
      locale: locale,
      supportedLocales: const [Locale('ru'), Locale('zh')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            child: HomeCnyRateCard(rate: rate, onRetry: onRetry ?? () {}),
          ),
        ),
      ),
    ),
  );
}
