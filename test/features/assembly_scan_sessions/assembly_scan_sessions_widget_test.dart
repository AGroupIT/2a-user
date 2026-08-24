import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twoalogisticcabineuser/src/features/assembly_scan_sessions/data/assembly_scan_sessions_provider.dart';
import 'package:twoalogisticcabineuser/src/features/assembly_scan_sessions/domain/assembly_scan_session.dart';
import 'package:twoalogisticcabineuser/src/features/assembly_scan_sessions/presentation/assembly_scan_session_screen.dart';
import 'package:twoalogisticcabineuser/src/features/assembly_scan_sessions/presentation/assembly_scan_sessions_section.dart';
import 'package:twoalogisticcabineuser/src/features/assembly_scan_sessions/presentation/assembly_scan_track_video_link.dart';
import 'package:twoalogisticcabineuser/src/features/assembly_scan_sessions/presentation/assembly_scan_video_player.dart';
import 'package:twoalogisticcabineuser/src/features/tracks/domain/track_item.dart';

void main() {
  testWidgets('renders supported session status labels', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Wrap(
            children: [
              AssemblyScanStatusChip(status: AssemblyScanSessionStatus.ready),
              AssemblyScanStatusChip(status: AssemblyScanSessionStatus.partial),
              AssemblyScanStatusChip(
                status: AssemblyScanSessionStatus.processing,
              ),
              AssemblyScanStatusChip(status: AssemblyScanSessionStatus.failed),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Готово'), findsOneWidget);
    expect(find.text('Частично'), findsOneWidget);
    expect(find.text('Обработка'), findsOneWidget);
    expect(find.text('Ошибка'), findsOneWidget);
  });

  testWidgets('assembly section shows approach count and rows', (tester) async {
    final repository = _WidgetRepository([
      _session('session-2', AssemblyScanSessionStatus.partial),
      _session('session-1', AssemblyScanSessionStatus.ready),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          assemblyScanSessionsRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AssemblyScanSessionsSection(
                assemblyId: 42,
                assemblyNumber: 'ASM-42',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Видео сканирования'), findsOneWidget);
    expect(find.text('2 подхода'), findsOneWidget);
    expect(find.text('Подход 2'), findsOneWidget);
    expect(find.text('Подход 1'), findsOneWidget);
    expect(find.text('Частично'), findsOneWidget);
    expect(find.textContaining('Все подходы'), findsNothing);
    expect(
      find.byKey(const Key('assembly-scan-evidence-card')),
      findsOneWidget,
    );

    await tester.tap(find.text('Подход 2'));
    await tester.pumpAndSettle();

    expect(find.byType(AssemblyScanSessionContent), findsOneWidget);
    expect(find.byTooltip('Закрыть'), findsOneWidget);
  });

  testWidgets('assembly evidence card stays readable at 320 px', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 1000);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final repository = _WidgetRepository([
      _session('session-2', AssemblyScanSessionStatus.partial),
      _session('session-1', AssemblyScanSessionStatus.ready),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          assemblyScanSessionsRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(8),
                child: AssemblyScanSessionsSection(
                  assemblyId: 42,
                  assemblyNumber: 'ASM-42',
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Подход 2'), findsOneWidget);
    expect(find.text('Подход 1'), findsOneWidget);
  });

  testWidgets('track video link opens the matching scan session', (
    tester,
  ) async {
    final session = AssemblyScanSession(
      id: 'session-track-link',
      assemblyId: 42,
      employeeId: null,
      employeeName: 'Сотрудник склада',
      statusCode: 'ready',
      status: AssemblyScanSessionStatus.ready,
      startedAt: DateTime.utc(2026, 8, 17, 10),
      recordingStartedAt: null,
      endedAt: DateTime.utc(2026, 8, 17, 10, 1),
      durationMs: 1000,
      stopReason: null,
      interruptionReason: null,
      hasKnownGap: false,
      videoCount: 1,
      scanCount: 1,
      videos: const [
        AssemblyScanVideo(
          id: 'track-link-video',
          partIndex: 0,
          mimeType: 'video/mp4',
          sizeBytes: 1024,
          durationMs: 1000,
          recordingOffsetMs: 0,
          status: 'ready',
        ),
      ],
      markers: [
        AssemblyScanMarker(
          id: 'marker-track-link',
          trackId: 7,
          trackNumber: 'TRACK-7',
          productName: null,
          scannedAt: DateTime.utc(2026, 8, 17, 10),
          clientCapturedAt: null,
          sessionOffsetMs: 500,
          videoId: null,
          videoOffsetMs: null,
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          assemblyScanSessionsRepositoryProvider.overrideWithValue(
            _WidgetRepository([session]),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: AssemblyScanTrackVideoLink(
              assemblyId: 42,
              assemblyNumber: 'ASM-42',
              track: TrackItem(
                id: 7,
                code: 'TRACK-7',
                status: 'На сборке',
                date: DateTime.utc(2026, 8, 17),
                createdAt: DateTime.utc(2026, 8, 17),
                updatedAt: DateTime.utc(2026, 8, 17),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('К видео сканирования'));
    await tester.pumpAndSettle();

    expect(find.text('Видео сканирования'), findsOneWidget);
    expect(find.byType(AssemblyScanSessionContent), findsOneWidget);
    expect(find.byTooltip('Закрыть'), findsOneWidget);
  });

  testWidgets('track video link stays hidden for an unavailable marker', (
    tester,
  ) async {
    final session = AssemblyScanSession(
      id: 'session-unavailable-link',
      assemblyId: 42,
      employeeId: null,
      employeeName: null,
      statusCode: 'partial',
      status: AssemblyScanSessionStatus.partial,
      startedAt: DateTime.utc(2026, 8, 17, 10),
      recordingStartedAt: null,
      endedAt: DateTime.utc(2026, 8, 17, 10, 1),
      durationMs: 60000,
      stopReason: null,
      interruptionReason: 'network_lost',
      hasKnownGap: true,
      videoCount: 1,
      scanCount: 1,
      videos: const [
        AssemblyScanVideo(
          id: 'short-video',
          partIndex: 0,
          mimeType: 'video/mp4',
          sizeBytes: 1024,
          durationMs: 1000,
          recordingOffsetMs: 0,
          status: 'ready',
        ),
      ],
      markers: [
        AssemblyScanMarker(
          id: 'missing-marker',
          trackId: 7,
          trackNumber: 'TRACK-7',
          productName: null,
          scannedAt: DateTime.utc(2026, 8, 17, 10),
          clientCapturedAt: null,
          sessionOffsetMs: 5000,
          videoId: null,
          videoOffsetMs: null,
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          assemblyScanSessionsRepositoryProvider.overrideWithValue(
            _WidgetRepository([session]),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: AssemblyScanTrackVideoLink(
              assemblyId: 42,
              assemblyNumber: 'ASM-42',
              track: TrackItem(
                id: 7,
                code: 'TRACK-7',
                status: 'На сборке',
                date: DateTime.utc(2026, 8, 17),
                createdAt: DateTime.utc(2026, 8, 17),
                updatedAt: DateTime.utc(2026, 8, 17),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('К видео сканирования'), findsNothing);
  });

  testWidgets('session page prioritizes approach summary and video evidence', (
    tester,
  ) async {
    final session = _session('session-1', AssemblyScanSessionStatus.processing);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          assemblyScanSessionsRepositoryProvider.overrideWithValue(
            _WidgetRepository([session]),
          ),
        ],
        child: const MaterialApp(
          home: AssemblyScanSessionScreen(
            assemblyId: 42,
            assemblyNumber: 'ASM-42',
            sessionId: 'session-1',
            approachNumber: 1,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('assembly-scan-session-hero')), findsOneWidget);
    expect(find.text('Сборка ASM-42'), findsOneWidget);
    expect(find.text('Подход 1'), findsOneWidget);
    expect(find.text('Видео обрабатывается'), findsOneWidget);
    expect(find.text('Готовых роликов пока нет'), findsOneWidget);
  });

  testWidgets('session page constrains its desktop content width', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 1000);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final session = _session('session-1', AssemblyScanSessionStatus.processing);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          assemblyScanSessionsRepositoryProvider.overrideWithValue(
            _WidgetRepository([session]),
          ),
        ],
        child: const MaterialApp(
          home: AssemblyScanSessionScreen(
            assemblyId: 42,
            assemblyNumber: 'ASM-42',
            sessionId: 'session-1',
            approachNumber: 1,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.byType(RefreshIndicator)).width,
      lessThanOrEqualTo(1120),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('gap marker is shown as unavailable and cannot seek', (
    tester,
  ) async {
    final session = AssemblyScanSession(
      id: 'session-gap-marker',
      assemblyId: 42,
      employeeId: null,
      employeeName: null,
      statusCode: 'partial',
      status: AssemblyScanSessionStatus.partial,
      startedAt: DateTime.utc(2026, 8, 17, 10),
      recordingStartedAt: null,
      endedAt: DateTime.utc(2026, 8, 17, 10, 1),
      durationMs: 60000,
      stopReason: null,
      interruptionReason: 'network_lost',
      hasKnownGap: true,
      videoCount: 1,
      scanCount: 1,
      videos: const [
        AssemblyScanVideo(
          id: 'ready-video',
          partIndex: 0,
          mimeType: 'video/mp4',
          sizeBytes: 1024,
          durationMs: 1000,
          recordingOffsetMs: 0,
          status: 'ready',
        ),
      ],
      markers: [
        AssemblyScanMarker(
          id: 'gap-marker',
          trackId: 7,
          trackNumber: 'TRACK-GAP',
          productName: null,
          scannedAt: DateTime.utc(2026, 8, 17, 10),
          clientCapturedAt: null,
          sessionOffsetMs: 5000,
          videoId: null,
          videoOffsetMs: null,
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          assemblyScanSessionsRepositoryProvider.overrideWithValue(
            _WidgetRepository([session]),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AssemblyScanVideoPlayer(session: session),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Момент видео недоступен'), findsOneWidget);
    expect(find.byKey(const Key('assembly-scan-player-card')), findsOneWidget);
    expect(find.byKey(const Key('assembly-scan-markers-card')), findsOneWidget);
    final inkWell = tester.widget<InkWell>(
      find.ancestor(of: find.text('TRACK-GAP'), matching: find.byType(InkWell)),
    );
    expect(inkWell.onTap, isNull);
  });
}

class _WidgetRepository implements AssemblyScanSessionsRepository {
  final List<AssemblyScanSession> sessions;

  const _WidgetRepository(this.sessions);

  @override
  Future<List<AssemblyScanSession>> fetchSessions(int assemblyId) async {
    return sessions;
  }

  @override
  Future<AssemblyScanSession> fetchSession({
    required int assemblyId,
    required String sessionId,
  }) async {
    return sessions.firstWhere((session) => session.id == sessionId);
  }

  @override
  Future<AssemblyScanPlaybackToken> createPlaybackToken({
    required int assemblyId,
    required String sessionId,
    required String videoId,
  }) {
    throw UnimplementedError();
  }
}

AssemblyScanSession _session(String id, AssemblyScanSessionStatus status) {
  final position = int.parse(id.split('-').last);
  return AssemblyScanSession(
    id: id,
    assemblyId: 42,
    employeeId: 1,
    employeeName: 'Сотрудник',
    statusCode: status.name,
    status: status,
    startedAt: DateTime.utc(2026, 8, 17, 10, position),
    recordingStartedAt: null,
    endedAt: DateTime.utc(2026, 8, 17, 10, position, 30),
    durationMs: 30000,
    stopReason: null,
    interruptionReason: status == AssemblyScanSessionStatus.partial
        ? 'network_lost'
        : null,
    hasKnownGap: status == AssemblyScanSessionStatus.partial,
    videoCount: 1,
    scanCount: position,
    videos: const [],
    markers: const [],
  );
}
