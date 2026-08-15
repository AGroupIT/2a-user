import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twoalogisticcabineuser/src/features/add_tracks/data/add_tracks_repository.dart';
import 'package:twoalogisticcabineuser/src/features/add_tracks/data/track_tracking_check_repository.dart';
import 'package:twoalogisticcabineuser/src/features/add_tracks/domain/add_tracks_result.dart';
import 'package:twoalogisticcabineuser/src/features/clients/application/client_codes_controller.dart';
import 'package:twoalogisticcabineuser/src/features/tracks/presentation/add_tracks_dialog.dart';

void main() {
  testWidgets(
    'отслеживаемые треки добавляются сразу, остальные можно исправить',
    (tester) async {
      final checkRepository = _FakeCheckRepository([
        const TrackTrackingCheckResult(
          configured: true,
          checkAvailable: true,
          items: [
            TrackTrackingCheckItem(
              code: 'TRACKABLE',
              status: TrackTrackingStatus.trackable,
            ),
            TrackTrackingCheckItem(
              code: 'NOTYET',
              status: TrackTrackingStatus.unconfirmed,
              reason: TrackTrackingReason.noTrackingData,
            ),
          ],
        ),
        const TrackTrackingCheckResult(
          configured: true,
          checkAvailable: true,
          items: [
            TrackTrackingCheckItem(
              code: 'FIXED',
              status: TrackTrackingStatus.trackable,
            ),
          ],
        ),
      ]);
      final addRepository = _FakeAddRepository();
      await _pumpLauncher(
        tester,
        checkRepository: checkRepository,
        addRepository: addRepository,
      );

      await tester.tap(find.text('Добавить треки'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'TRACKABLE\nNOTYET');
      await tester.tap(find.text('Проверить и добавить'));
      await tester.pumpAndSettle();

      expect(addRepository.calls, [
        ['TRACKABLE'],
      ]);
      expect(find.text('Проверьте эти трек-номера'), findsOneWidget);
      expect(find.text('История доставки пока не найдена'), findsOneWidget);
      expect(find.text('Уже добавлено автоматически: 1'), findsOneWidget);

      final reviewField = find.descendant(
        of: find.byKey(const ValueKey('unconfirmed-track-0')),
        matching: find.byType(TextField),
      );
      await tester.enterText(reviewField, 'FIXED');
      await tester.tap(find.text('Проверить исправления'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(checkRepository.calls, [
        ['TRACKABLE', 'NOTYET'],
        ['FIXED'],
      ]);
      expect(addRepository.calls, [
        ['TRACKABLE'],
        ['FIXED'],
      ]);
      await tester.pump(const Duration(seconds: 2));
    },
  );

  testWidgets('не найденный у перевозчика номер можно подтвердить', (
    tester,
  ) async {
    final checkRepository = _FakeCheckRepository([
      const TrackTrackingCheckResult(
        configured: true,
        checkAvailable: true,
        items: [
          TrackTrackingCheckItem(
            code: 'NEWTRACK',
            status: TrackTrackingStatus.unconfirmed,
            reason: TrackTrackingReason.carrierNotRecognized,
          ),
        ],
      ),
    ]);
    final addRepository = _FakeAddRepository();
    await _pumpLauncher(
      tester,
      checkRepository: checkRepository,
      addRepository: addRepository,
    );

    await tester.tap(find.text('Добавить треки'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'NEWTRACK');
    await tester.tap(find.text('Проверить и добавить'));
    await tester.pumpAndSettle();

    expect(find.text('Служба доставки не определена'), findsOneWidget);
    final confirmButton = find.text('Всё указано верно — добавить');
    await tester.ensureVisible(confirmButton);
    await tester.pumpAndSettle();
    await tester.tap(confirmButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(addRepository.calls, [
      ['NEWTRACK'],
    ]);
    await tester.pump(const Duration(seconds: 2));
  });
}

Future<void> _pumpLauncher(
  WidgetTester tester, {
  required TrackTrackingCheckRepository checkRepository,
  required AddTracksRepository addRepository,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        activeClientCodeProvider.overrideWithValue('A-001'),
        trackTrackingCheckRepositoryProvider.overrideWithValue(checkRepository),
        addTracksRepositoryProvider.overrideWithValue(addRepository),
      ],
      child: MaterialApp(
        locale: const Locale('ru'),
        supportedLocales: const [Locale('ru'), Locale('zh')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: Consumer(
            builder: (context, ref, _) => TextButton(
              onPressed: () => showAddTracksDialog(context, ref),
              child: const Text('Добавить треки'),
            ),
          ),
        ),
      ),
    ),
  );
}

class _FakeCheckRepository implements TrackTrackingCheckRepository {
  final List<TrackTrackingCheckResult> responses;
  final List<List<String>> calls = [];

  _FakeCheckRepository(this.responses);

  @override
  Future<TrackTrackingCheckResult> check({
    required String clientCode,
    required List<String> trackCodes,
  }) async {
    calls.add(List.of(trackCodes));
    return responses.removeAt(0);
  }
}

class _FakeAddRepository implements AddTracksRepository {
  final List<List<String>> calls = [];

  @override
  Future<AddTracksResult> addTracks({
    required String clientCode,
    required List<String> trackCodes,
  }) async {
    calls.add(List.of(trackCodes));
    return AddTracksResult(added: trackCodes.length, skipped: const []);
  }
}
