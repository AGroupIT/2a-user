import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twoalogisticcabineuser/src/features/clients/application/client_codes_controller.dart';
import 'package:twoalogisticcabineuser/src/features/garage/application/garage_providers.dart';
import 'package:twoalogisticcabineuser/src/features/more/presentation/more_sheet.dart';
import 'package:twoalogisticcabineuser/src/features/partner_program/data/client_partner_program_provider.dart';
import 'package:twoalogisticcabineuser/src/features/profile/data/profile_provider.dart';
import 'package:twoalogisticcabineuser/src/features/self_buyout/data/self_buyout_service.dart';

void main() {
  group('shouldShowManualUpdateMenu', () {
    test('shows update check for direct Android builds', () {
      expect(
        shouldShowManualUpdateMenu(
          isAndroid: true,
          isRustoreDistribution: false,
        ),
        isTrue,
      );
    });

    test('hides update check for RuStore Android builds', () {
      expect(
        shouldShowManualUpdateMenu(
          isAndroid: true,
          isRustoreDistribution: true,
        ),
        isFalse,
      );
    });

    test('hides update check outside Android', () {
      expect(
        shouldShowManualUpdateMenu(
          isAndroid: false,
          isRustoreDistribution: false,
        ),
        isFalse,
      );
    });
  });

  testWidgets('shows the calculator entry in More', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeClientCodeProvider.overrideWithValue(null),
          clientProfileProvider.overrideWithValue(const AsyncData(null)),
          selfBuyoutAvailabilityProvider.overrideWithValue(
            const AsyncLoading(),
          ),
          garageAvailabilityProvider.overrideWithValue(const AsyncLoading()),
          clientPartnerProgramProvider.overrideWithValue(const AsyncData(null)),
        ],
        child: const MaterialApp(home: Scaffold(body: MoreSheet())),
      ),
    );

    expect(find.text('Калькулятор'), findsOneWidget);
    expect(find.text('Предварительный расчёт сборки'), findsOneWidget);
    expect(find.byIcon(Icons.calculate_rounded), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 10));
  });
}
