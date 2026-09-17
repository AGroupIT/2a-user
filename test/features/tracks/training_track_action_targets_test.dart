import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:twoalogisticcabineuser/src/features/clients/application/client_codes_controller.dart';
import 'package:twoalogisticcabineuser/src/features/tracks/data/tracks_provider.dart';
import 'package:twoalogisticcabineuser/src/features/tracks/domain/track_item.dart';
import 'package:twoalogisticcabineuser/src/features/tracks/presentation/tracks_screen.dart';
import 'package:twoalogisticcabineuser/src/features/tracks/presentation/widgets/client_track_compact_card.dart';
import 'package:twoalogisticcabineuser/src/features/training/presentation/training_target.dart';

void main() {
  for (final width in [390.0, 1280.0]) {
    testWidgets(
      'sheet handle anchor dismisses actual details at width $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await initializeDateFormatting('ru');
        final now = DateTime(2026, 9, 1);
        final registry = TrainingTargetRegistry();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              trainingTargetRegistryProvider.overrideWithValue(registry),
              activeClientCodeProvider.overrideWithValue('2A-TEST'),
              trackStatusesProvider.overrideWith((ref) async => const []),
              assemblyStatusesProvider.overrideWith((ref) async => const []),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: TracksScreen.embedded(
                  tracks: [
                    TrackItem(
                      code: 'TRAINING-DISMISS',
                      status: 'На складе',
                      statusCode: 'in_warehouse',
                      date: now,
                      createdAt: now,
                      updatedAt: now,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('client-track-card-TRAINING-DISMISS')),
        );
        await tester.pumpAndSettle();
        expect(find.text('Карточка трек-номера'), findsOneWidget);
        final box =
            registry
                    .contextFor('track.sheet.dismiss-handle')!
                    .findRenderObject()!
                as RenderBox;
        expect(box.size, const Size(42, 25));
        await tester.dragFrom(
          box.localToGlobal(box.size.center(Offset.zero)),
          width < 1000 ? const Offset(0, 160) : const Offset(160, 0),
        );
        await tester.pumpAndSettle();
        expect(find.text('Карточка трек-номера'), findsNothing);
        expect(registry.contextFor('track.sheet.dismiss-handle'), isNull);
        await tester.pump(const Duration(milliseconds: 600));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('return and transfer anchors enclose only their own action', (
    tester,
  ) async {
    final registry = TrainingTargetRegistry();
    final actions = <String>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [trainingTargetRegistryProvider.overrideWithValue(registry)],
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 360,
                child: ClientTrackCompactCard(
                  trackNumber: 'TRAINING-1',
                  status: 'На складе',
                  statusColor: Colors.green,
                  productName: 'Товар',
                  selectable: true,
                  selected: false,
                  trainingOpenId: 'track.open',
                  trainingStatusId: 'track.status',
                  trainingSelectionId: 'tracks.selection',
                  onToggleSelection: () => actions.add('select'),
                  onCopyTrack: () => actions.add('copy'),
                  onOpenDetails: (_) => actions.add('open'),
                  indicators: const [],
                  actions: [
                    ClientTrackQuickAction(
                      icon: Icons.swap_horiz,
                      label: 'Перенести',
                      trainingTargetId: 'track.transfer',
                      onTap: () => actions.add('transfer'),
                    ),
                    ClientTrackQuickAction(
                      icon: Icons.assignment_return,
                      label: 'Возврат',
                      trainingTargetId: 'track.return',
                      onTap: () => actions.add('return'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    Rect targetRect(String id) {
      final box = registry.contextFor(id)!.findRenderObject()! as RenderBox;
      return box.localToGlobal(Offset.zero) & box.size;
    }

    final cardRect = tester.getRect(find.byType(ClientTrackCompactCard));
    final returnRect = targetRect('track.return');
    final transferRect = targetRect('track.transfer');
    expect(returnRect.height, lessThan(cardRect.height));
    expect(returnRect.width, lessThan(cardRect.width));
    expect(returnRect.overlaps(transferRect), isFalse);
    expect(
      returnRect,
      tester.getRect(find.byKey(const ValueKey('client-track-action-Возврат'))),
    );
    expect(
      transferRect,
      tester.getRect(
        find.byKey(const ValueKey('client-track-action-Перенести')),
      ),
    );
    expect(targetRect('tracks.selection').width, lessThan(60));
    expect(targetRect('track.open').width, lessThan(cardRect.width / 2));
    expect(actions, isEmpty);
    await tester.tapAt(returnRect.center);
    await tester.pump();
    await tester.tapAt(transferRect.center);
    await tester.pump();
    await tester.tapAt(targetRect('tracks.selection').center);
    await tester.pump();
    await tester.tapAt(targetRect('track.open').center);
    await tester.pump();
    expect(actions, ['return', 'transfer', 'select', 'open']);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    expect(registry.contextFor('track.return'), isNull);
  });
}
