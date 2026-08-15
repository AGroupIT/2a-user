import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twoalogisticcabineuser/src/features/sp_finance/presentation/sp_finance_ui.dart';

void main() {
  testWidgets('подтверждение СП использует единый modal surface', (
    tester,
  ) async {
    bool? result;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showSpFinanceConfirmationSheet(
                  context: context,
                  title: 'Архивировать клиента?',
                  message: 'История закупок и оплат сохранится.',
                  confirmLabel: 'В архив',
                  destructive: true,
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
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.byKey(const ValueKey('sp-finance-modal-surface')),
      findsOneWidget,
    );
    expect(find.text('Архивировать клиента?'), findsOneWidget);
    expect(find.text('История закупок и оплат сохранится.'), findsOneWidget);
    expect(find.text('Отмена'), findsOneWidget);
    expect(find.text('В архив'), findsOneWidget);

    await tester.tap(find.text('В архив'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(result, isTrue);
  });
}
