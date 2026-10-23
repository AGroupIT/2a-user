import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twoalogisticcabineuser/src/core/branding/company_branding_provider.dart';
import 'package:twoalogisticcabineuser/src/features/shop/data/shop_availability_provider.dart';
import 'package:twoalogisticcabineuser/src/features/shop/presentation/marketplace_access_gate.dart';
import 'package:twoalogisticcabineuser/src/features/splash/presentation/splash_screen.dart';

class _CompanyName extends Notifier<String> {
  @override
  String build() => 'Компания Северная логистика';

  void change(String name) => state = name;
}

final _nameProvider = NotifierProvider<_CompanyName, String>(_CompanyName.new);

void main() {
  for (final width in [280.0, 390.0]) {
    testWidgets('Splash reflects agent changes without overflow at $width', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(width, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final container = ProviderContainer(
        overrides: [
          companyNameProvider.overrideWith((ref) => ref.watch(_nameProvider)),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: SplashScreen()),
        ),
      );
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Компания Северная логистика'), findsOneWidget);
      expect(tester.takeException(), isNull);
      container.read(_nameProvider.notifier).change('Другой агент');
      await tester.pump();
      expect(find.text('Другой агент'), findsOneWidget);
      expect(find.text('2A'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Unavailable marketplace uses full agent name at $width', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(width, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            companyNameProvider.overrideWithValue(
              'Компания Северная логистика международные перевозки',
            ),
            shopAvailabilityProvider.overrideWith(
              (ref) async => MarketplaceAvailability.unavailable,
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: MarketplaceAccessGate(child: Text('Каталог доступен')),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(
        find.text('Компания Северная логистика международные перевозки'),
        findsOneWidget,
      );
      expect(find.text('2A'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
