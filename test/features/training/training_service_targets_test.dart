import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twoalogisticcabineuser/src/features/clients/application/client_codes_controller.dart';
import 'package:twoalogisticcabineuser/src/features/self_buyout/data/self_buyout_models.dart';
import 'package:twoalogisticcabineuser/src/features/self_buyout/presentation/self_buyout_create_sheet.dart';
import 'package:twoalogisticcabineuser/src/features/self_buyout/presentation/self_buyout_ui.dart';
import 'package:twoalogisticcabineuser/src/features/shop/domain/marketplace.dart';
import 'package:twoalogisticcabineuser/src/features/shop/domain/shop_item.dart';
import 'package:twoalogisticcabineuser/src/features/shop/presentation/widgets/marketplace_selector.dart';
import 'package:twoalogisticcabineuser/src/features/shop/presentation/widgets/shop_item_card.dart';
import 'package:twoalogisticcabineuser/src/features/training/presentation/training_target.dart';

import '../../helpers/pump_app.dart';

Finder target(String id) => find.byWidgetPredicate(
  (widget) => widget is TrainingTarget && widget.id == id,
);

void main() {
  testWidgets(
    'self-buyout highlights upload button and terms control, not cards',
    (tester) async {
      await tester.pumpApp(
        const Scaffold(
          body: SelfBuyoutCreateSheet(
            availability: SelfBuyoutAvailability(
              available: true,
              clientCnyRubRate: 12.5,
              minCny: 100,
            ),
          ),
        ),
        overrides: [
          activeClientCodeProvider.overrideWithValue('A-001'),
          activeClientCodeIdProvider.overrideWithValue(1),
        ],
      );
      final upload = target('selfbuyout.requisites');
      final uploadButton = find.descendant(
        of: upload,
        matching: find.byType(SelfBuyoutSecondaryButton),
      );
      expect(uploadButton, findsOneWidget);
      expect(tester.getRect(upload), tester.getRect(uploadButton));
      expect(tester.getSize(upload).height, lessThanOrEqualTo(60));
      final terms = target('selfbuyout.terms');
      expect(tester.getSize(terms).height, lessThanOrEqualTo(50));
      final termsControl = find.descendant(
        of: terms,
        matching: find.byType(InkWell),
      );
      expect(tester.getRect(terms), tester.getRect(termsControl));
      expect(
        find.descendant(
          of: target('selfbuyout.amount'),
          matching: find.byType(TextField),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('marketplace target covers one chip and preserves selection', (
    tester,
  ) async {
    Marketplace? selected;
    await tester.pumpApp(
      Scaffold(
        body: MarketplaceSelector(
          marketplaces: Marketplace.values,
          selected: Marketplace.jd,
          onChanged: (value) => selected = value,
        ),
      ),
    );
    final anchor = target('shop.marketplace');
    expect(anchor, findsOneWidget);
    expect(
      tester.getRect(anchor),
      tester.getRect(find.widgetWithText(ChoiceChip, '1688')),
    );
    expect(tester.getSize(anchor).width, lessThan(160));
    expect(selected, isNull);
    expect(tester.widget<TrainingTarget>(anchor).onActivate, isNull);
    await tester.tap(anchor);
    expect(selected, Marketplace.alibaba1688);
  });

  testWidgets('product target covers its title and retains opening action', (
    tester,
  ) async {
    var opened = false;
    await tester.pumpApp(
      Scaffold(
        body: SizedBox(
          width: 180,
          child: ShopItemCard(
            item: const ShopItem(id: '1', title: 'Товар для обучения'),
            trainingTarget: true,
            onTap: () => opened = true,
          ),
        ),
      ),
    );
    final anchor = target('shop.product.open');
    expect(
      tester.getRect(anchor),
      tester.getRect(find.text('Товар для обучения')),
    );
    expect(tester.getSize(anchor).height, lessThan(60));
    expect(
      tester.getSize(anchor).height,
      lessThan(tester.getSize(find.byType(ShopItemCard)).height),
    );
    expect(opened, isFalse);
    await tester.tap(anchor);
    expect(opened, isTrue);
  });
}
