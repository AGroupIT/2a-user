import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twoalogisticcabineuser/src/features/sp_finance/data/sp_organizer_models.dart';
import 'package:twoalogisticcabineuser/src/features/sp_finance/presentation/sp_organizer_navigation.dart';

void main() {
  const enabledCapabilities = SpOrganizerCapabilities(
    contractVersion: 1,
    organizerV2: true,
    purchaseKinds: false,
    participants: true,
    products: true,
    customersDirectory: true,
    calculationProfiles: false,
    fulfillmentOverview: false,
    selfBuyoutLinks: false,
    selfBuyout: SpOrganizerActionCapability.unavailable,
    garageImport: false,
    trackLinks: false,
    assemblyLinks: false,
    invoiceLinks: false,
    analytics: true,
  );

  testWidgets('показывает включённые разделы без overflow на 320 px', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(320, 700));
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('ru'),
        home: Scaffold(
          body: SpOrganizerNavigation(
            capabilities: enabledCapabilities,
            selected: SpOrganizerSection.purchases,
          ),
        ),
      ),
    );

    expect(find.text('Закупки'), findsOneWidget);
    expect(find.text('Клиенты'), findsOneWidget);
    expect(find.text('Товары'), findsOneWidget);
    expect(find.text('Аналитика'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(SpOrganizerNavigation),
        matching: find.byType(SingleChildScrollView),
      ),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('скрывается при старом capability-контракте', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SpOrganizerNavigation(
            capabilities: SpOrganizerCapabilities.unavailable,
            selected: SpOrganizerSection.purchases,
          ),
        ),
      ),
    );

    expect(find.text('Закупки'), findsNothing);
    expect(find.text('Клиенты'), findsNothing);
    expect(find.text('Товары'), findsNothing);
    expect(find.text('Аналитика'), findsNothing);
  });

  testWidgets('остаётся читаемой на desktop width', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(1024, 700));
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('ru'),
        home: Scaffold(
          body: SpOrganizerNavigation(
            capabilities: enabledCapabilities,
            selected: SpOrganizerSection.products,
          ),
        ),
      ),
    );

    expect(find.text('Закупки'), findsOneWidget);
    expect(find.text('Клиенты'), findsOneWidget);
    expect(find.text('Товары'), findsOneWidget);
    expect(find.text('Аналитика'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('переключает раздел через callback как настоящая вкладка', (
    tester,
  ) async {
    SpOrganizerSection? selected;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        home: Scaffold(
          body: SpOrganizerNavigation(
            capabilities: enabledCapabilities,
            selected: SpOrganizerSection.purchases,
            onSelected: (section) => selected = section,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Клиенты'));
    await tester.pump();

    expect(selected, SpOrganizerSection.customers);
  });
}
