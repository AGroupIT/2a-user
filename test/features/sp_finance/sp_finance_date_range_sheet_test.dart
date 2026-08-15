import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twoalogisticcabineuser/src/features/sp_finance/presentation/sp_finance_date_range_sheet.dart';
import 'package:twoalogisticcabineuser/src/features/sp_finance/presentation/sp_finance_ui.dart';

void main() {
  testWidgets('date range uses the shared SP modal surface at 320 px', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(320, 800));

    DateTimeRange? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showSpFinanceDateRangeSheet(
                  context: context,
                  title: 'Период создания закупки',
                  firstDate: DateTime(2026, 7),
                  lastDate: DateTime(2026, 12, 31),
                  initialCalendarDate: DateTime(2026, 7, 1),
                  confirmText: 'Выбрать',
                );
              },
              child: const Text('Открыть'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Открыть'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(SpFinanceModalSurface), findsOneWidget);
    expect(find.text('Период создания закупки'), findsOneWidget);
    expect(find.text('Дата начала'), findsOneWidget);
    expect(find.text('Дата окончания'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('10'));
    await tester.pump(const Duration(milliseconds: 400));
    final endDay = find.text('15').hitTestable();
    expect(endDay, findsOneWidget);
    await tester.tap(endDay);
    await tester.pump();

    expect(find.text('10.07.2026'), findsOneWidget);
    expect(find.text('15.07.2026'), findsOneWidget);

    await tester.tap(find.text('Выбрать'));
    await tester.pump();

    expect(result?.start, DateTime(2026, 7, 10));
    expect(result?.end, DateTime(2026, 7, 15));
  });
}
