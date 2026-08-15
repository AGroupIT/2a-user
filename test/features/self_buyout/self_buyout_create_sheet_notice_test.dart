import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twoalogisticcabineuser/src/features/clients/application/client_codes_controller.dart';
import 'package:twoalogisticcabineuser/src/features/self_buyout/data/self_buyout_models.dart';
import 'package:twoalogisticcabineuser/src/features/self_buyout/presentation/self_buyout_create_sheet.dart';

import '../../helpers/pump_app.dart';

void main() {
  testWidgets('форма создания заметно сообщает об ограничении для ИП', (
    tester,
  ) async {
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

    expect(
      find.byKey(const ValueKey('self-buyout-individual-only-notice')),
      findsOneWidget,
    );
    expect(find.text('Только для физических лиц'), findsOneWidget);
    expect(
      find.textContaining('Если вы ИП, напишите менеджеру'),
      findsOneWidget,
    );
  });

  testWidgets('при исправлении реквизитов предупреждение не дублируется', (
    tester,
  ) async {
    await tester.pumpApp(
      const Scaffold(
        body: SelfBuyoutCreateSheet.correctRequisites(
          correctionRequest: SelfBuyoutRequest(
            id: 1,
            requestNumber: 'SB-1',
            status: 'cancelled',
            clientCodeId: 1,
            requestedCnyAmount: 100,
            paymentRubAmount: 1250,
            clientCnyRubRate: 12.5,
            amountEnteredIn: 'cny',
          ),
        ),
      ),
      overrides: [activeClientCodeProvider.overrideWithValue('A-001')],
    );

    expect(
      find.byKey(const ValueKey('self-buyout-individual-only-notice')),
      findsNothing,
    );
  });
}
