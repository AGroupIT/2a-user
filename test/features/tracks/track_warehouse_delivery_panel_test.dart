import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twoalogisticcabineuser/src/features/tracks/data/track_warehouse_delivery_repository.dart';
import 'package:twoalogisticcabineuser/src/features/tracks/domain/track_item.dart';
import 'package:twoalogisticcabineuser/src/features/tracks/presentation/track_warehouse_delivery_panel.dart';

void main() {
  test('кнопка доступна только для pending', () {
    expect(canShowTrackWarehouseDelivery(_track('pending')), isTrue);
    expect(canShowTrackWarehouseDelivery(_track('in_warehouse')), isFalse);
    expect(canShowTrackWarehouseDelivery(_track('in_transit')), isFalse);
    expect(
      canShowTrackWarehouseDelivery(_track('pending', includeId: false)),
      isFalse,
    );
  });

  testWidgets('длинная кнопка содержит только основной текст', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: TrackWarehouseDeliveryButton(onPressed: _noop)),
      ),
    );

    expect(find.text('Статус доставки до склада'), findsOneWidget);
    expect(find.textContaining('Путь по Китаю'), findsNothing);
  });

  testWidgets('показывает статус до склада и переводит историю на русский', (
    tester,
  ) async {
    final repository = _FakeGateway(
      delivery: const TrackWarehouseDelivery(
        configured: true,
        trackNumber: '79025360024440',
        trackStatus: 'in_warehouse',
        automatic: false,
        subscriptionStatus: 'completed',
        carrierName: '圆通速递',
        externalState: '3',
        isDelivered: true,
        trace: [
          TrackWarehouseDeliveryEvent(
            time: '2026-08-13 10:00:00',
            context: '快件已送达',
            location: '广州市',
          ),
        ],
      ),
      translations: const {
        '圆通速递': 'YTO Express',
        '快件已送达': 'Посылка доставлена',
        '广州市': 'Гуанчжоу',
      },
    );

    await _pumpPanel(
      tester,
      repository: repository,
      track: _track('in_warehouse'),
    );

    expect(find.text('История доставки'), findsOneWidget);
    expect(find.text('Доставлено перевозчиком'), findsOneWidget);
    expect(find.text('Посылка доставлена'), findsOneWidget);
    expect(find.text('Гуанчжоу'), findsOneWidget);
    expect(find.text('快件已送达'), findsNothing);
    expect(find.textContaining('фактическим сканированием'), findsOneWidget);
  });

  testWidgets('pending трек автоматически включает отслеживание', (
    tester,
  ) async {
    final repository = _FakeGateway(
      delivery: const TrackWarehouseDelivery(
        configured: true,
        trackNumber: '79025360024440',
        trackStatus: 'pending',
        automatic: true,
        subscriptionStatus: 'idle',
        isDelivered: false,
      ),
    );

    await _pumpPanel(tester, repository: repository, track: _track('pending'));

    expect(repository.requestCalls, [true]);
    expect(find.text('Получить информацию'), findsOneWidget);
  });
}

void _noop() {}

Future<void> _pumpPanel(
  WidgetTester tester, {
  required _FakeGateway repository,
  required TrackItem track,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        trackWarehouseDeliveryRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        locale: const Locale('ru'),
        supportedLocales: const [Locale('ru'), Locale('zh')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: SingleChildScrollView(
            child: TrackWarehouseDeliveryPanel(track: track),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump();
}

TrackItem _track(String statusCode, {bool includeId = true}) {
  final now = DateTime(2026, 8, 13);
  return TrackItem(
    id: includeId ? 15 : null,
    code: '79025360024440',
    status: switch (statusCode) {
      'pending' => 'В ожидании',
      'in_warehouse' => 'На складе',
      _ => 'В пути',
    },
    statusCode: statusCode,
    date: now,
    createdAt: now,
    updatedAt: now,
  );
}

class _FakeGateway implements TrackWarehouseDeliveryGateway {
  final TrackWarehouseDelivery delivery;
  final Map<String, String> translations;
  final List<bool> requestCalls = [];

  _FakeGateway({required this.delivery, this.translations = const {}});

  @override
  Future<TrackWarehouseDelivery> get(int trackId) async => delivery;

  @override
  Future<TrackWarehouseDelivery> request(
    int trackId, {
    required bool automatic,
  }) async {
    requestCalls.add(automatic);
    return delivery;
  }

  @override
  Future<String> translate(String text) async => translations[text] ?? text;
}
