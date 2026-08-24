import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:twoalogisticcabineuser/src/features/clients/application/client_codes_controller.dart';
import 'package:twoalogisticcabineuser/src/features/tracks/data/tracks_provider.dart';
import 'package:twoalogisticcabineuser/src/features/tracks/domain/track_item.dart';
import 'package:twoalogisticcabineuser/src/features/tracks/presentation/tracks_screen.dart';

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
}
