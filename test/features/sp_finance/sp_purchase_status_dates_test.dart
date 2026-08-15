import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twoalogisticcabineuser/src/features/sp_finance/presentation/sp_purchase_status_dates.dart';

void main() {
  test('этапы дают совместимые backend-статусы и очищают поздние даты', () {
    final forming = SpPurchaseCreationTimelineValue.initial(
      DateTime(2026, 7, 20),
    );
    final inTransit = forming.advance(DateTime(2026, 7, 24));
    final delivered = inTransit.advance(DateTime(2026, 7, 27));

    expect(forming.backendStatus, 'open');
    expect(forming.dispatchedFromChinaAt, isNull);
    expect(inTransit.backendStatus, 'in_transit');
    expect(inTransit.dispatchedFromChinaAt, DateTime(2026, 7, 24));
    expect(delivered.backendStatus, 'completed');
    expect(delivered.completedAt, DateTime(2026, 7, 27));

    final backToTransit = delivered.retreat();
    expect(backToTransit.backendStatus, 'in_transit');
    expect(backToTransit.completedAt, isNull);

    final backToForming = backToTransit.retreat();
    expect(backToForming.backendStatus, 'open');
    expect(backToForming.dispatchedFromChinaAt, isNull);
  });

  test(
    'существующие расширенные статусы не теряются при открытии редактора',
    () {
      final value = SpPurchaseCreationTimelineValue.fromExisting(
        status: 'collecting_payments',
        createdAt: DateTime(2026, 7, 20),
        dispatchedFromChinaAt: DateTime(2026, 7, 24),
        updatedAt: DateTime(2026, 7, 27),
      );

      expect(value.stage, SpPurchaseCreationStage.delivered);
      expect(value.startedAt, DateTime(2026, 7, 20));
      expect(value.dispatchedFromChinaAt, DateTime(2026, 7, 24));
      expect(value.completedAt, DateTime(2026, 7, 27));
    },
  );

  testWidgets('редактор повторяет три этапа и работает на ширине 320px', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var value = SpPurchaseCreationTimelineValue.initial(DateTime(2026, 7, 27));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => SingleChildScrollView(
              child: SpPurchaseStatusDatesEditor(
                value: value,
                onChanged: (next) => setState(() => value = next),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Формируется'), findsOneWidget);
    expect(find.text('В пути'), findsOneWidget);
    expect(find.text('Доставлена'), findsOneWidget);
    expect(find.text('Дата создания'), findsOneWidget);
    expect(find.text('Дата отправки со склада'), findsOneWidget);
    expect(find.text('Дата получения'), findsOneWidget);
    expect(find.text('Отправить'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('sp-purchase-status-next')));
    await tester.pump();
    expect(find.text('Доставить'), findsOneWidget);

    await tester.tap(find.byKey(const Key('sp-purchase-status-next')));
    await tester.pump();
    expect(value.backendStatus, 'completed');

    await tester.tap(find.byKey(const Key('sp-purchase-status-back')));
    await tester.pump();
    expect(value.backendStatus, 'in_transit');
    expect(value.completedAt, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('компактная шкала дат не переполняется на 320px', (tester) async {
    tester.view.physicalSize = const Size(320, 240);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SpPurchaseLifecycleSummary(
            currentStage: SpPurchaseCreationStage.delivered,
            startedAt: DateTime(2026, 7, 20),
            dispatchedFromChinaAt: DateTime(2026, 7, 24),
            completedAt: DateTime(2026, 7, 27),
          ),
        ),
      ),
    );

    expect(find.text('Создана'), findsOneWidget);
    expect(find.text('Отправлена'), findsOneWidget);
    expect(find.text('Получена'), findsOneWidget);
    expect(find.text('20.07.26'), findsOneWidget);
    expect(find.text('24.07.26'), findsOneWidget);
    expect(find.text('27.07.26'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
