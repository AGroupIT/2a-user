import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:twoalogisticcabineuser/src/core/network/api_client.dart';
import 'package:twoalogisticcabineuser/src/core/services/runtime/app_runtime_info.dart';
import 'package:twoalogisticcabineuser/src/features/profile/data/problem_report_queue.dart';
import 'package:twoalogisticcabineuser/src/features/profile/data/problem_report_repository.dart';
import 'package:twoalogisticcabineuser/src/features/profile/data/profile_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('queues remain isolated and survive an account transition', () async {
    final queue = ProblemReportQueue();
    await queue.enqueue(accountId: 11, payload: {'description': 'first'});
    await queue.enqueue(accountId: 22, payload: {'description': 'second'});

    final accountOne = await queue.load(accountId: 11);
    final accountTwo = await queue.load(accountId: 22);

    expect(accountOne.single.accountId, 11);
    expect(accountOne.single.payload['description'], 'first');
    expect(accountTwo.single.accountId, 22);
    expect(accountTwo.single.payload['description'], 'second');
  });

  test('legacy ownerless queue entries are discarded', () async {
    SharedPreferences.setMockInitialValues({
      'problem_report_queue_v1': [
        '{"localId":"legacy","queuedAt":"2026-01-01T00:00:00Z",'
            '"payload":{"description":"unknown owner"}}',
      ],
    });
    final queue = ProblemReportQueue();

    expect(await queue.load(accountId: 11), isEmpty);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('problem_report_queue_v1'), isFalse);
  });

  test(
    'permanent rejection is discarded and does not block later items',
    () async {
      final queue = ProblemReportQueue();
      await queue.enqueue(accountId: 11, payload: {'description': 'invalid'});
      await queue.enqueue(accountId: 11, payload: {'description': 'valid'});
      final api = _RecordingProblemReportApiClient(
        statusByDescription: {'invalid': 422},
      );
      final repository = ProblemReportRepository(
        api,
        queue: queue,
        activeClientId: () => 11,
      );

      final sent = await repository.flushQueuedReports(clientId: 11);

      expect(sent, 1);
      expect(api.posts, hasLength(2));
      expect(await queue.load(accountId: 11), isEmpty);
    },
  );

  test('transient rejection keeps the current and later queue items', () async {
    final queue = ProblemReportQueue();
    await queue.enqueue(accountId: 11, payload: {'description': 'retry'});
    await queue.enqueue(accountId: 11, payload: {'description': 'later'});
    final api = _RecordingProblemReportApiClient(
      statusByDescription: {'retry': 500},
    );
    final repository = ProblemReportRepository(
      api,
      queue: queue,
      activeClientId: () => 11,
    );

    final sent = await repository.flushQueuedReports(clientId: 11);

    expect(sent, 0);
    expect(api.posts, hasLength(1));
    final remaining = await queue.load(accountId: 11);
    expect(remaining.map((item) => item.payload['description']), [
      'retry',
      'later',
    ]);
  });

  test('account mismatch preserves queue and prevents POST', () async {
    final queue = ProblemReportQueue();
    await queue.enqueue(accountId: 11, payload: {'description': 'first'});
    await queue.enqueue(accountId: 22, payload: {'description': 'second'});
    final api = _RecordingProblemReportApiClient();
    var activeClientId = 22;
    final repository = ProblemReportRepository(
      api,
      queue: queue,
      activeClientId: () => activeClientId,
    );

    expect(await repository.flushQueuedReports(clientId: 11), 0);
    expect(api.posts, isEmpty);
    expect(await queue.load(accountId: 11), hasLength(1));
    expect(await queue.load(accountId: 22), hasLength(1));

    expect(await repository.flushQueuedReports(clientId: 22), 1);
    expect(api.posts, hasLength(1));
    expect(await queue.load(accountId: 11), hasLength(1));
    expect(await queue.load(accountId: 22), isEmpty);

    activeClientId = 11;
    expect(await repository.flushQueuedReports(clientId: 11), 1);
    expect(await queue.load(accountId: 11), isEmpty);
  });

  test('send rejects a stale profile before making a POST', () async {
    final api = _RecordingProblemReportApiClient();
    final repository = ProblemReportRepository(api, activeClientId: () => 22);

    await expectLater(
      repository.send(
        description: 'stale account report',
        profile: _profile(id: 11),
        currentScreen: '/profile',
      ),
      throwsA(isA<ProblemReportAccountChangedException>()),
    );
    expect(api.posts, isEmpty);
  });

  test(
    'mid-flight account switch neither posts nor queues stale data',
    () async {
      final queue = ProblemReportQueue();
      final api = _RecordingProblemReportApiClient();
      var activeClientId = 11;
      final repository = ProblemReportRepository(
        api,
        queue: queue,
        activeClientId: () => activeClientId,
        runtimeSnapshot: () async {
          activeClientId = 22;
          return const AppRuntimeSnapshot(
            appVersion: '1.2.29',
            buildNumber: '60',
            platform: 'test',
            device: 'test',
            osVersion: 'test',
          );
        },
        collectDiagnostics: (_) async => null,
      );

      await expectLater(
        repository.send(
          description: 'switched account report',
          profile: _profile(id: 11),
          currentScreen: '/profile',
        ),
        throwsA(isA<ProblemReportAccountChangedException>()),
      );

      expect(api.posts, isEmpty);
      expect(await queue.load(accountId: 11), isEmpty);
      expect(await queue.load(accountId: 22), isEmpty);
    },
  );

  test('queued idempotency key is identical in body and header', () async {
    final queue = ProblemReportQueue();
    await queue.enqueue(accountId: 11, payload: {'description': 'offline'});
    final api = _RecordingProblemReportApiClient();
    final repository = ProblemReportRepository(
      api,
      queue: queue,
      activeClientId: () => 11,
    );

    expect(await repository.flushQueuedReports(clientId: 11), 1);
    final post = api.posts.single;
    final bodyKey = post.data['idempotencyKey'];

    expect(bodyKey, isA<String>());
    expect(bodyKey, isNotEmpty);
    expect(post.headers['Idempotency-Key'], bodyKey);
  });

  test('send includes only a validated non-empty Sentry event id', () async {
    const eventId = 'a0aaf0f0bd3541ffafeb4a86f0cab9dc';
    final api = _RecordingProblemReportApiClient();
    final repository = ProblemReportRepository(
      api,
      activeClientId: () => 11,
      runtimeSnapshot: _runtimeSnapshot,
      collectDiagnostics: (_) async => null,
      sentryLastEventId: () => eventId,
    );

    await repository.send(
      description: 'cannot open payment',
      profile: _profile(id: 11),
      currentScreen: '/payments/123',
    );

    final runtime = Map<String, dynamic>.from(
      api.posts.single.data['runtime'] as Map,
    );
    expect(runtime['sentryLastEventId'], eventId);
  });

  test('send omits malformed Sentry event ids', () async {
    final api = _RecordingProblemReportApiClient();
    final repository = ProblemReportRepository(
      api,
      activeClientId: () => 11,
      runtimeSnapshot: _runtimeSnapshot,
      collectDiagnostics: (_) async => null,
      sentryLastEventId: () => 'event@example.test',
    );

    await repository.send(
      description: 'cannot open payment',
      profile: _profile(id: 11),
      currentScreen: '/payments/123',
    );

    final runtime = Map<String, dynamic>.from(
      api.posts.single.data['runtime'] as Map,
    );
    expect(runtime, isNot(contains('sentryLastEventId')));
  });
}

Future<AppRuntimeSnapshot> _runtimeSnapshot() async {
  return const AppRuntimeSnapshot(
    appVersion: '1.2.29',
    buildNumber: '60',
    platform: 'test',
    device: 'test',
    osVersion: 'test',
  );
}

ClientProfile _profile({required int id}) {
  return ClientProfile(
    id: id,
    fullName: 'Test Client',
    email: 'client@example.test',
    balance: 0,
    isActive: true,
    codes: const [],
    createdAt: DateTime.utc(2026),
  );
}

class _RecordedPost {
  const _RecordedPost({required this.data, required this.headers});

  final Map<String, dynamic> data;
  final Map<String, dynamic> headers;
}

class _RecordingProblemReportApiClient extends ApiClient {
  _RecordingProblemReportApiClient({this.statusByDescription = const {}});

  final Map<String, int> statusByDescription;
  final List<_RecordedPost> posts = [];

  @override
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    final body = Map<String, dynamic>.from(data as Map);
    posts.add(
      _RecordedPost(
        data: body,
        headers: Map<String, dynamic>.from(options?.headers ?? const {}),
      ),
    );
    final statusCode = statusByDescription[body['description']];
    final requestOptions = RequestOptions(path: path);
    if (statusCode != null) {
      throw DioException(
        requestOptions: requestOptions,
        response: Response<void>(
          requestOptions: requestOptions,
          statusCode: statusCode,
        ),
        type: DioExceptionType.badResponse,
      );
    }
    return Response<T>(
      requestOptions: requestOptions,
      statusCode: 201,
      data: {'id': posts.length} as T,
    );
  }
}
