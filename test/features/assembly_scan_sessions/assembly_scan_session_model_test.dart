import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twoalogisticcabineuser/src/core/network/api_client.dart';
import 'package:twoalogisticcabineuser/src/features/assembly_scan_sessions/data/assembly_scan_sessions_provider.dart';
import 'package:twoalogisticcabineuser/src/features/assembly_scan_sessions/domain/assembly_scan_session.dart';
import 'package:twoalogisticcabineuser/src/features/assembly_scan_sessions/presentation/assembly_scan_text.dart';
import 'package:twoalogisticcabineuser/src/features/assembly_scan_sessions/presentation/assembly_scan_video_player.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AssemblyScanSession', () {
    test('parses lifecycle data and orders videos and markers', () {
      final session = AssemblyScanSession.fromJson({
        'id': 'session-1',
        'assemblyId': 42,
        'status': 'partial',
        'startedAt': '2026-08-17T10:00:00.000Z',
        'durationMs': 12000,
        'hasKnownGap': true,
        'videos': [
          {
            'id': 'video-2',
            'partIndex': 1,
            'durationMs': 5000,
            'recordingOffsetMs': 7000,
            'status': 'ready',
          },
          {
            'id': 'video-1',
            'partIndex': 0,
            'durationMs': 7000,
            'recordingOffsetMs': 0,
            'status': 'ready',
          },
        ],
        'scans': [
          {
            'id': 'scan-2',
            'trackNumber': 'TRACK-2',
            'scannedAt': '2026-08-17T10:00:08.000Z',
            'sessionOffsetMs': 8000,
            'videoId': 'video-2',
            'videoOffsetMs': 1000,
          },
          {
            'id': 'scan-1',
            'trackNumber': 'TRACK-1',
            'scannedAt': '2026-08-17T10:00:03.000Z',
            'sessionOffsetMs': 3000,
            'videoId': 'video-1',
            'videoOffsetMs': 3000,
          },
        ],
      });

      expect(session.status, AssemblyScanSessionStatus.partial);
      expect(session.hasKnownGap, isTrue);
      expect(session.isPlayable, isTrue);
      expect(session.readyVideos.map((video) => video.id), [
        'video-1',
        'video-2',
      ]);
      expect(session.markers.map((marker) => marker.trackNumber), [
        'TRACK-1',
        'TRACK-2',
      ]);

      final secondMarker = session.markers.last;
      final video = session.videoForMarker(secondMarker);
      expect(video?.id, 'video-2');
      expect(
        session.markerOffsetInVideo(secondMarker, video!).inMilliseconds,
        1000,
      );
    });

    test('falls back to recording offsets when marker has no video id', () {
      final session = AssemblyScanSession.fromJson({
        'id': 'session-2',
        'assemblyId': 42,
        'status': 'ready',
        'startedAt': '2026-08-17T10:00:00.000Z',
        'videos': [
          {
            'id': 'video-1',
            'partIndex': 0,
            'durationMs': 5000,
            'recordingOffsetMs': 0,
            'status': 'ready',
          },
          {
            'id': 'video-2',
            'partIndex': 1,
            'durationMs': 5000,
            'recordingOffsetMs': 5000,
            'status': 'ready',
          },
        ],
        'scans': [
          {
            'id': 'scan-1',
            'trackNumber': 'TRACK-2',
            'scannedAt': '2026-08-17T10:00:07.500Z',
            'sessionOffsetMs': 7500,
          },
        ],
      });

      final marker = session.markers.single;
      final video = session.videoForMarker(marker)!;
      expect(video.id, 'video-2');
      expect(
        session.markerOffsetInVideo(marker, video),
        const Duration(milliseconds: 2500),
      );
    });

    test('orders recovery parts by recording offset and seeks into them', () {
      final session = AssemblyScanSession.fromJson({
        'id': 'session-recovery',
        'assemblyId': 42,
        'status': 'partial',
        'startedAt': '2026-08-17T10:00:00.000Z',
        'videos': [
          {
            'id': 'egress-after',
            'partIndex': 1,
            'durationMs': 5000,
            'recordingOffsetMs': 10000,
            'status': 'ready',
          },
          {
            'id': 'recovery',
            'partIndex': -1,
            'durationMs': 5000,
            'recordingOffsetMs': 5000,
            'status': 'ready',
          },
          {
            'id': 'egress-before',
            'partIndex': 0,
            'durationMs': 5000,
            'recordingOffsetMs': 0,
            'status': 'ready',
          },
        ],
        'scans': [
          {
            'id': 'recovery-marker',
            'trackNumber': 'TRACK-RECOVERY',
            'scannedAt': '2026-08-17T10:00:07.000Z',
            'sessionOffsetMs': 7000,
          },
        ],
      });

      expect(session.readyVideos.map((video) => video.id), [
        'egress-before',
        'recovery',
        'egress-after',
      ]);
      final marker = session.markers.single;
      final video = session.videoForMarker(marker)!;
      expect(video.id, 'recovery');
      expect(
        session.markerOffsetInVideo(marker, video),
        const Duration(milliseconds: 2000),
      );
    });

    test('does not map markers outside recorded video intervals', () {
      final session = AssemblyScanSession.fromJson({
        'id': 'session-with-gap',
        'assemblyId': 42,
        'status': 'partial',
        'startedAt': '2026-08-17T10:00:00.000Z',
        'hasKnownGap': true,
        'videos': [
          {
            'id': 'video-before-gap',
            'partIndex': 0,
            'durationMs': 4000,
            'recordingOffsetMs': 1000,
            'status': 'ready',
          },
          {
            'id': 'video-after-gap',
            'partIndex': 1,
            'durationMs': 4000,
            'recordingOffsetMs': 7000,
            'status': 'ready',
          },
        ],
        'scans': [
          {
            'id': 'before-first',
            'trackNumber': 'TRACK-BEFORE',
            'scannedAt': '2026-08-17T10:00:00.500Z',
            'sessionOffsetMs': 500,
          },
          {
            'id': 'at-first-end',
            'trackNumber': 'TRACK-GAP',
            'scannedAt': '2026-08-17T10:00:05.000Z',
            'sessionOffsetMs': 5000,
          },
          {
            'id': 'after-last',
            'trackNumber': 'TRACK-AFTER',
            'scannedAt': '2026-08-17T10:00:12.000Z',
            'sessionOffsetMs': 12000,
          },
        ],
      });

      for (final marker in session.markers) {
        expect(session.videoForMarker(marker), isNull);
        expect(
          assemblyScanMarkerOffsetForVideo(
            session,
            marker,
            session.readyVideos.first,
          ),
          isNull,
        );
      }
    });

    test('does not replace an unavailable explicit video link', () {
      final session = AssemblyScanSession.fromJson({
        'id': 'session-explicit-missing',
        'assemblyId': 42,
        'status': 'partial',
        'startedAt': '2026-08-17T10:00:00.000Z',
        'videos': [
          {
            'id': 'ready-video',
            'partIndex': 0,
            'durationMs': 5000,
            'recordingOffsetMs': 0,
            'status': 'ready',
          },
        ],
        'scans': [
          {
            'id': 'linked-to-failed-video',
            'trackNumber': 'TRACK-EXPLICIT',
            'scannedAt': '2026-08-17T10:00:02.000Z',
            'sessionOffsetMs': 2000,
            'videoId': 'failed-video',
            'videoOffsetMs': 1000,
          },
        ],
      });

      expect(session.videoForMarker(session.markers.single), isNull);
    });

    test('reloads the player when a processing session gains ready media', () {
      final processing = AssemblyScanSession.fromJson({
        'id': 'session-refresh',
        'assemblyId': 42,
        'status': 'processing',
        'startedAt': '2026-08-17T10:00:00.000Z',
        'videos': const [],
        'scans': const [],
      });
      final ready = AssemblyScanSession.fromJson({
        'id': 'session-refresh',
        'assemblyId': 42,
        'status': 'ready',
        'startedAt': '2026-08-17T10:00:00.000Z',
        'videos': [
          {
            'id': 'ready-video',
            'partIndex': 0,
            'durationMs': 5000,
            'recordingOffsetMs': 0,
            'status': 'ready',
          },
        ],
        'scans': const [],
      });

      expect(shouldReloadAssemblyScanVideoPlayer(processing, ready), isTrue);
      expect(shouldReloadAssemblyScanVideoPlayer(ready, ready), isFalse);
    });
  });

  group('Russian scan-session counters', () {
    test('declines approach count', () {
      expect(ruApproachCount(1), '1 подход');
      expect(ruApproachCount(2), '2 подхода');
      expect(ruApproachCount(4), '4 подхода');
      expect(ruApproachCount(5), '5 подходов');
      expect(ruApproachCount(11), '11 подходов');
      expect(ruApproachCount(21), '21 подход');
    });

    test('declines track count', () {
      expect(ruTrackCount(1), '1 трек');
      expect(ruTrackCount(2), '2 трека');
      expect(ruTrackCount(4), '4 трека');
      expect(ruTrackCount(5), '5 треков');
      expect(ruTrackCount(11), '11 треков');
      expect(ruTrackCount(21), '21 трек');
    });
  });

  test(
    'sessions provider delegates to repository and preserves result',
    () async {
      final repository = _FakeRepository();
      final container = ProviderContainer(
        overrides: [
          assemblyScanSessionsRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      final sessions = await container.read(
        assemblyScanSessionsProvider(42).future,
      );

      expect(repository.requestedAssemblyId, 42);
      expect(sessions.single.id, 'session-from-repository');
    },
  );

  test('api repository uses client scan-session routes and video id', () async {
    final apiClient = _RecordingApiClient();
    final repository = ApiAssemblyScanSessionsRepository(apiClient);

    final sessions = await repository.fetchSessions(42);
    final detail = await repository.fetchSession(
      assemblyId: 42,
      sessionId: 'session-1',
    );
    final token = await repository.createPlaybackToken(
      assemblyId: 42,
      sessionId: 'session-1',
      videoId: 'video-1',
    );

    expect(sessions.single.id, 'session-1');
    expect(detail.id, 'session-1');
    expect(token.url.host, 'media.example.com');
    expect(apiClient.requests, hasLength(3));
    expect(apiClient.requests[0].$1, 'GET');
    expect(apiClient.requests[0].$2, '/client/assemblies/42/scan-sessions');
    expect(apiClient.requests[1].$1, 'GET');
    expect(
      apiClient.requests[1].$2,
      '/client/assemblies/42/scan-sessions/session-1',
    );
    expect(apiClient.requests[2].$1, 'POST');
    expect(
      apiClient.requests[2].$2,
      '/client/assemblies/42/scan-sessions/session-1/playback-token',
    );
    expect(apiClient.requests[2].$3, {'videoId': 'video-1'});
  });
}

class _FakeRepository implements AssemblyScanSessionsRepository {
  int? requestedAssemblyId;

  @override
  Future<List<AssemblyScanSession>> fetchSessions(int assemblyId) async {
    requestedAssemblyId = assemblyId;
    return [_session('session-from-repository')];
  }

  @override
  Future<AssemblyScanSession> fetchSession({
    required int assemblyId,
    required String sessionId,
  }) async {
    return _session(sessionId);
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

AssemblyScanSession _session(String id) {
  return AssemblyScanSession(
    id: id,
    assemblyId: 42,
    employeeId: null,
    employeeName: null,
    statusCode: 'processing',
    status: AssemblyScanSessionStatus.processing,
    startedAt: DateTime.utc(2026, 8, 17),
    recordingStartedAt: null,
    endedAt: null,
    durationMs: null,
    stopReason: null,
    interruptionReason: null,
    hasKnownGap: false,
    videoCount: 0,
    scanCount: 0,
    videos: const [],
    markers: const [],
  );
}

class _RecordingApiClient extends ApiClient {
  final requests = <(String, String, dynamic)>[];

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    requests.add(('GET', path, null));
    final session = _sessionJson();
    final data = path.endsWith('/session-1')
        ? {'session': session}
        : {
            'sessions': [session],
          };
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      statusCode: 200,
      data: data as T,
    );
  }

  @override
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    requests.add(('POST', path, data));
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      statusCode: 200,
      data:
          {
                'url':
                    'https://media.example.com/private/video.mp4?token=short',
                'expiresInSeconds': 900,
              }
              as T,
    );
  }
}

Map<String, dynamic> _sessionJson() {
  return {
    'id': 'session-1',
    'assemblyId': 42,
    'status': 'ready',
    'startedAt': '2026-08-17T10:00:00.000Z',
    'videos': const [],
    'scans': const [],
  };
}
