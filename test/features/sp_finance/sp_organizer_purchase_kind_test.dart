import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twoalogisticcabineuser/src/features/sp_finance/presentation/sp_organizer_purchase_kind.dart';

void main() {
  testWidgets('selector сохраняет три типа и работает на ширине 320 px', (
    tester,
  ) async {
    String? selected;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: SpOrganizerPurchaseKindSelector(
              value: 'group',
              onChanged: (value) => selected = value,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Для себя'), findsOneWidget);
    expect(find.text('Один клиент'), findsOneWidget);
    expect(find.text('Совместная'), findsOneWidget);
    expect(find.byType(ChoiceChip), findsNothing);
    final selectedButton = find.byKey(const ValueKey('sp-purchase-kind-group'));
    expect(selectedButton, findsOneWidget);
    final selectedMaterial = tester.widget<Material>(selectedButton);
    expect(
      selectedMaterial.color,
      Theme.of(tester.element(selectedButton)).colorScheme.primary,
    );
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Для себя'));
    expect(selected, 'personal');
  });

  testWidgets('selector использует китайские новые строки', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: const [Locale('ru'), Locale('zh')],
        home: Scaffold(
          body: SpOrganizerPurchaseKindSelector(
            value: 'individual',
            onChanged: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('采购类型'), findsOneWidget);
    expect(find.text('自用'), findsOneWidget);
    expect(find.text('单个客户'), findsOneWidget);
    expect(find.text('多人拼团'), findsOneWidget);
  });
}
