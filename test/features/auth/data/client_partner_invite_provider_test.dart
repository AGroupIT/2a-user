import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:twoalogisticcabineuser/src/core/network/api_client.dart';
import 'package:twoalogisticcabineuser/src/features/auth/data/client_partner_invite_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const token =
      '123e4567-e89b-12d3-a456-426614174000.1.AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';
  const secondToken =
      '223e4567-e89b-12d3-a456-426614174000.1.BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB';

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'валидирует приглашение и сохраняет стабильный ключ регистрации',
    () async {
      final api = _InviteApiClient();
      final container = ProviderContainer(
        overrides: [apiClientProvider.overrideWithValue(api)],
      );
      addTearDown(container.dispose);
      final notifier = container.read(clientPartnerInviteProvider.notifier);

      expect(await notifier.captureToken(token), isTrue);
      final firstKey = container
          .read(clientPartnerInviteProvider)
          .registrationIdempotencyKey;
      expect(firstKey, isNotEmpty);
      expect(await notifier.validate(), isTrue);

      final state = container.read(clientPartnerInviteProvider);
      expect(state.isValidated, isTrue);
      expect(state.partnerName, 'Партнёр Иван');
      expect(state.agentName, 'Agent A');
      expect(state.agentDomain, 'agent-a.test');
      expect(state.colorPrimary, '#123456');
      expect(state.colorSecondary, '#ABCDEF');
      expect(state.prefix, 'PA');
      expect(api.requestedPaths, [
        '/public/client-partner-invites/${Uri.encodeComponent(token)}',
      ]);

      expect(await notifier.captureToken(token), isTrue);
      expect(
        container.read(clientPartnerInviteProvider).registrationIdempotencyKey,
        firstKey,
      );
    },
  );

  test('отклоняет повреждённый token без запроса к API', () async {
    final api = _InviteApiClient();
    final container = ProviderContainer(
      overrides: [apiClientProvider.overrideWithValue(api)],
    );
    addTearDown(container.dispose);

    final result = await container
        .read(clientPartnerInviteProvider.notifier)
        .captureToken('wrong-token');

    expect(result, isFalse);
    expect(
      container.read(clientPartnerInviteProvider).phase,
      ClientPartnerInvitePhase.error,
    );
    expect(api.requestedPaths, isEmpty);
  });

  test(
    'восстанавливает token и тот же idempotency key после перезапуска',
    () async {
      final firstContainer = ProviderContainer(
        overrides: [apiClientProvider.overrideWithValue(_InviteApiClient())],
      );
      final firstNotifier = firstContainer.read(
        clientPartnerInviteProvider.notifier,
      );
      expect(await firstNotifier.captureToken(token), isTrue);
      final firstKey = firstContainer
          .read(clientPartnerInviteProvider)
          .registrationIdempotencyKey;
      firstContainer.dispose();

      final restoredApi = _InviteApiClient();
      final restoredContainer = ProviderContainer(
        overrides: [apiClientProvider.overrideWithValue(restoredApi)],
      );
      addTearDown(restoredContainer.dispose);
      restoredContainer.read(clientPartnerInviteProvider);
      await _waitFor(
        () => restoredContainer.read(clientPartnerInviteProvider).isValidated,
      );

      final restored = restoredContainer.read(clientPartnerInviteProvider);
      expect(restored.token, token);
      expect(restored.registrationIdempotencyKey, firstKey);
      expect(restoredApi.requestedPaths, hasLength(1));
    },
  );

  test('сохраняет token и ключ после revoked ответа 410', () async {
    final api = _RevokedInviteApiClient();
    final container = ProviderContainer(
      overrides: [apiClientProvider.overrideWithValue(api)],
    );
    addTearDown(container.dispose);
    final notifier = container.read(clientPartnerInviteProvider.notifier);

    expect(await notifier.captureToken(token), isTrue);
    final key = container
        .read(clientPartnerInviteProvider)
        .registrationIdempotencyKey;
    expect(await notifier.validate(), isFalse);

    final state = container.read(clientPartnerInviteProvider);
    expect(state.phase, ClientPartnerInvitePhase.error);
    expect(state.token, token);
    expect(state.registrationIdempotencyKey, key);
    expect(
      state.error,
      'Ссылка больше не активна. Попросите партнёра отправить новую.',
    );
  });

  test('повторяет проверку после сетевой ошибки без смены ключа', () async {
    final api = _RetryInviteApiClient();
    final container = ProviderContainer(
      overrides: [apiClientProvider.overrideWithValue(api)],
    );
    addTearDown(container.dispose);
    final notifier = container.read(clientPartnerInviteProvider.notifier);

    expect(await notifier.captureToken(token), isTrue);
    final key = container
        .read(clientPartnerInviteProvider)
        .registrationIdempotencyKey;
    expect(await notifier.validate(), isFalse);
    expect(
      container.read(clientPartnerInviteProvider).phase,
      ClientPartnerInvitePhase.error,
    );

    expect(await notifier.validate(), isTrue);
    expect(container.read(clientPartnerInviteProvider).isValidated, isTrue);
    expect(
      container.read(clientPartnerInviteProvider).registrationIdempotencyKey,
      key,
    );
    expect(api.requestedPaths, hasLength(2));
  });

  test('устаревший ответ A не перезаписывает новое приглашение B', () async {
    final api = _DeferredInviteApiClient();
    final container = ProviderContainer(
      overrides: [apiClientProvider.overrideWithValue(api)],
    );
    addTearDown(container.dispose);
    final notifier = container.read(clientPartnerInviteProvider.notifier);

    expect(await notifier.captureToken(token), isTrue);
    final firstValidation = notifier.validate();
    await api.waitUntilRequested(token);

    expect(await notifier.captureToken(secondToken), isTrue);
    final secondValidation = notifier.validate();
    await api.waitUntilRequested(secondToken);

    api.complete(secondToken, partnerName: 'Партнёр B', prefix: 'PB');
    expect(await secondValidation, isTrue);
    api.complete(token, partnerName: 'Партнёр A', prefix: 'PA');
    expect(await firstValidation, isFalse);

    final state = container.read(clientPartnerInviteProvider);
    expect(state.token, secondToken);
    expect(state.partnerName, 'Партнёр B');
    expect(state.prefix, 'PB');
    expect(state.isValidated, isTrue);
  });
}

Future<void> _waitFor(bool Function() predicate) async {
  for (var attempt = 0; attempt < 50; attempt += 1) {
    if (predicate()) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('Condition was not met in time');
}

class _InviteApiClient extends ApiClient {
  final requestedPaths = <String>[];

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    requestedPaths.add(path);
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      statusCode: 200,
      data:
          {
                'data': {
                  'partnerName': 'Партнёр Иван',
                  'agentName': 'Agent A',
                  'agentDomain': 'agent-a.test',
                  'colorPrimary': '#123456',
                  'colorSecondary': '#ABCDEF',
                  'prefix': 'PA',
                  'shortCode': 'ABCDEFGH',
                },
              }
              as T,
    );
  }
}

class _RevokedInviteApiClient extends ApiClient {
  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) => throw DioException(
    requestOptions: RequestOptions(path: path),
    response: Response<dynamic>(
      requestOptions: RequestOptions(path: path),
      statusCode: 410,
      data: const <String, dynamic>{},
    ),
  );
}

class _RetryInviteApiClient extends _InviteApiClient {
  var _attempt = 0;

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    _attempt += 1;
    if (_attempt == 1) {
      requestedPaths.add(path);
      throw DioException(requestOptions: RequestOptions(path: path));
    }
    return super.get<T>(
      path,
      queryParameters: queryParameters,
      options: options,
    );
  }
}

class _DeferredInviteApiClient extends ApiClient {
  final _responses = <String, Completer<Response<Map<String, dynamic>>>>{};

  Future<void> waitUntilRequested(String token) async {
    await _waitFor(
      () => _responses.containsKey(
        '/public/client-partner-invites/${Uri.encodeComponent(token)}',
      ),
    );
  }

  void complete(
    String token, {
    required String partnerName,
    required String prefix,
  }) {
    final path = '/public/client-partner-invites/${Uri.encodeComponent(token)}';
    _responses[path]!.complete(
      Response<Map<String, dynamic>>(
        requestOptions: RequestOptions(path: path),
        statusCode: 200,
        data: {
          'data': {
            'partnerName': partnerName,
            'agentName': 'Agent $prefix',
            'agentDomain': '${prefix.toLowerCase()}.test',
            'colorPrimary': '#123456',
            'colorSecondary': '#ABCDEF',
            'prefix': prefix,
            'shortCode': 'ABCDEFGH',
          },
        },
      ),
    );
  }

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    final completer = _responses.putIfAbsent(path, Completer.new);
    return await completer.future as Response<T>;
  }
}
