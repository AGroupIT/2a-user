import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twoalogisticcabineuser/src/features/sp_finance/data/sp_v2_models.dart';
import 'package:twoalogisticcabineuser/src/features/sp_finance/presentation/sp_purchase_client_sections_editor.dart';

void main() {
  testWidgets('разделы клиента повторяют конкурентную структуру на 320px', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var value = const SpV2ClientCardSections();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: SpPurchaseClientSectionsEditor(
                value: value,
                onChanged: (next) => setState(() => value = next),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Разделы в карточке клиента'), findsOneWidget);
    expect(find.text('Тариф'), findsOneWidget);
    expect(find.text('Своя цена для клиента'), findsOneWidget);
    expect(find.text('Финансы'), findsOneWidget);
    expect(find.text('Доставка до клиента'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('sp-client-section-finance')));
    await tester.pump();

    expect(value.showTariff, isTrue);
    expect(value.showCustomPrice, isTrue);
    expect(value.showFinance, isFalse);
    expect(value.showDelivery, isTrue);
    expect(tester.takeException(), isNull);
  });
}
