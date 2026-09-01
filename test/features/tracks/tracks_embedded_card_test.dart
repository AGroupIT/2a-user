import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:twoalogisticcabineuser/src/features/clients/application/client_codes_controller.dart';
import 'package:twoalogisticcabineuser/src/features/tracks/data/tracks_provider.dart';
import 'package:twoalogisticcabineuser/src/features/tracks/domain/track_item.dart';
import 'package:twoalogisticcabineuser/src/features/tracks/presentation/tracks_screen.dart';

Future<void> _pumpEmbeddedAssembly(
  WidgetTester tester,
  TrackAssembly assembly,
) async {
  final now = DateTime(2026, 9, 1);
  final track = TrackItem(
    code: 'YT-ASSEMBLY-42',
    status: 'В сборке',
    statusCode: 'in_assembly',
    statusColor: '#F97316',
    date: now,
    createdAt: now,
    updatedAt: now,
    groupId: assembly.id.toString(),
    assembly: assembly,
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        activeClientCodeProvider.overrideWithValue('2A-TEST'),
        trackStatusesProvider.overrideWith((ref) async => const []),
        assemblyStatusesProvider.overrideWith((ref) async => const []),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: TracksScreen.embedded(tracks: [track], asAssembly: true),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('embedded track reuses the production card and detail sheet', (
    tester,
  ) async {
    await initializeDateFormatting('ru');
    final now = DateTime(2026, 8, 24);
    final track = TrackItem(
      code: 'YT-EMBEDDED-42',
      status: 'На складе',
      statusCode: 'in_warehouse',
      statusColor: '#F97316',
      date: now,
      createdAt: now,
      updatedAt: now,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeClientCodeProvider.overrideWithValue('2A-TEST'),
          trackStatusesProvider.overrideWith((ref) async => const []),
          assemblyStatusesProvider.overrideWith((ref) async => const []),
        ],
        child: MaterialApp(
          home: Scaffold(body: TracksScreen.embedded(tracks: [track])),
        ),
      ),
    );
    await tester.pump();

    final card = find.byKey(const ValueKey('client-track-card-YT-EMBEDDED-42'));
    expect(card, findsOneWidget);
    expect(find.byKey(const ValueKey('client-track-selection')), findsNothing);

    await tester.tap(card);
    await tester.pump();
    expect(find.text('Карточка трек-номера'), findsOneWidget);
  });

  testWidgets(
    'delivered assembly hides delivery action and shows read-only delivery tab',
    (tester) async {
      await initializeDateFormatting('ru');
      const assembly = TrackAssembly(
        id: 42,
        number: 'ASM-DELIVERED-42',
        status: 'delivered',
        statusName: 'Доставлена',
        deliveryMethod: 'self_pickup',
        trackCount: 1,
      );

      await _pumpEmbeddedAssembly(tester, assembly);

      expect(
        find.byKey(const ValueKey('client-track-action-Доставка')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('client-track-action-Заметка')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('client-track-indicator-2')));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Сборка уже доставлена. Способ получения и данные получателя доступны только для просмотра.',
        ),
        findsOneWidget,
      );
      expect(find.text('Сохранить доставку'), findsNothing);

      final selfPickupOption = find.byKey(
        const ValueKey('assembly-delivery-option-self_pickup'),
      );
      final selfPickupInkWell = tester.widget<InkWell>(
        find.descendant(of: selfPickupOption, matching: find.byType(InkWell)),
      );
      expect(selfPickupInkWell.onTap, isNull);
    },
  );

  testWidgets('non-delivered assembly keeps delivery editing available', (
    tester,
  ) async {
    await initializeDateFormatting('ru');
    const assembly = TrackAssembly(
      id: 43,
      number: 'ASM-READY-43',
      status: 'ready_for_pickup',
      statusName: 'Сформирована к выдаче',
      deliveryMethod: 'self_pickup',
      trackCount: 1,
    );

    await _pumpEmbeddedAssembly(tester, assembly);

    expect(
      find.byKey(const ValueKey('client-track-action-Доставка')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('client-track-indicator-2')));
    await tester.pumpAndSettle();

    expect(find.text('Сохранить доставку'), findsOneWidget);
    final selfPickupOption = find.byKey(
      const ValueKey('assembly-delivery-option-self_pickup'),
    );
    final selfPickupInkWell = tester.widget<InkWell>(
      find.descendant(of: selfPickupOption, matching: find.byType(InkWell)),
    );
    expect(selfPickupInkWell.onTap, isNotNull);
  });
}
