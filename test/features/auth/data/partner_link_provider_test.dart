import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:twoalogisticcabineuser/src/core/network/api_client.dart';
import 'package:twoalogisticcabineuser/src/features/auth/data/partner_link_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const token = 'abcdefghijklmnopqrstuvwxyz_ABCDEFGHIJKLMNOPQRSTUVWXYZ-1234';

  test(
    'восстанавливает partner-link token между этапами регистрации',
    () async {
      SharedPreferences.setMockInitialValues({
        'pending_partner_link_token_v1': token,
      });
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(_PartnerLinkApiClient()),
        ],
      );
      addTearDown(container.dispose);

      container.read(partnerLinkProvider);
      final restored = await _waitForState(
        container,
        (state) => state.phase == PartnerLinkPhase.pending,
      );

      expect(restored.token, token);
      expect(restored.hasPendingToken, isTrue);
    },
  );

  test('валидирует, завершает и удаляет одноразовый token', () async {
    SharedPreferences.setMockInitialValues({});
    final apiClient = _PartnerLinkApiClient();
    final container = ProviderContainer(
      overrides: [apiClientProvider.overrideWithValue(apiClient)],
    );
    addTearDown(container.dispose);
    final notifier = container.read(partnerLinkProvider.notifier);

    expect(await notifier.captureToken(token), isTrue);
    expect(await notifier.validate(), isTrue);
    expect(await notifier.complete(), isTrue);

    final state = container.read(partnerLinkProvider);
    expect(state.phase, PartnerLinkPhase.completed);
    expect(state.token, token);
    expect(state.clientCode, 'PL-1001');
    expect(state.hasPendingToken, isFalse);
    expect(apiClient.requestedPaths, [
      '/partner-link/sessions/$token',
      '/partner-link/sessions/$token/complete',
    ]);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('pending_partner_link_token_v1'), isNull);
  });

  test('отклоняет malformed token до сетевого запроса', () async {
    SharedPreferences.setMockInitialValues({});
    final apiClient = _PartnerLinkApiClient();
    final container = ProviderContainer(
      overrides: [apiClientProvider.overrideWithValue(apiClient)],
    );
    addTearDown(container.dispose);

    final captured = await container
        .read(partnerLinkProvider.notifier)
        .captureToken('short token');

    expect(captured, isFalse);
    expect(container.read(partnerLinkProvider).phase, PartnerLinkPhase.error);
    expect(apiClient.requestedPaths, isEmpty);
  });

  test(
    'после отказа от невалидной ссылки роут не захватывает её повторно',
    () async {
      SharedPreferences.setMockInitialValues({});
      final apiClient = _PartnerLinkApiClient(getStatusCode: 404);
      final container = ProviderContainer(
        overrides: [apiClientProvider.overrideWithValue(apiClient)],
      );
      addTearDown(container.dispose);
      final notifier = container.read(partnerLinkProvider.notifier);

      expect(await notifier.captureToken(token), isTrue);
      expect(await notifier.validate(), isFalse);
      expect(container.read(partnerLinkProvider).phase, PartnerLinkPhase.error);

      await notifier.clear();

      final dismissed = container.read(partnerLinkProvider);
      expect(dismissed.hasPendingToken, isFalse);
      expect(dismissed.shouldCaptureRouteToken(token), isFalse);
      expect(dismissed.pendingTokenForRoute(token), isNull);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('pending_partner_link_token_v1'), isNull);

      const newToken =
          'new_abcdefghijklmnopqrstuvwxyz_ABCDEFGHIJKLMNOPQRSTUVWXYZ-1234';
      expect(dismissed.shouldCaptureRouteToken(newToken), isTrue);
      expect(dismissed.pendingTokenForRoute(newToken), newToken);
      expect(await notifier.captureToken(newToken), isTrue);
      expect(container.read(partnerLinkProvider).token, newToken);
      expect(container.read(partnerLinkProvider).hasPendingToken, isTrue);
    },
  );
}

Future<PartnerLinkState> _waitForState(
  ProviderContainer container,
  bool Function(PartnerLinkState state) predicate,
) async {
  final stopwatch = Stopwatch()..start();
  while (stopwatch.elapsed < const Duration(seconds: 1)) {
    final state = container.read(partnerLinkProvider);
    if (predicate(state)) return state;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  return container.read(partnerLinkProvider);
}

class _PartnerLinkApiClient extends ApiClient {
  _PartnerLinkApiClient({this.getStatusCode = 200});

  final int getStatusCode;
  final requestedPaths = <String>[];

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    requestedPaths.add(path);
    if (getStatusCode != 200) {
      final requestOptions = RequestOptions(path: path);
      throw DioException.badResponse(
        statusCode: getStatusCode,
        requestOptions: requestOptions,
        response: Response<dynamic>(
          requestOptions: requestOptions,
          statusCode: getStatusCode,
          data: {'error': 'Сессия привязки не найдена'},
        ),
      );
    }
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      statusCode: 200,
      data:
          {
                'data': {
                  'status': 'pending',
                  'partnerName': 'Exchange Partner',
                  'registrationAgent': '2a-logistic.ru',
                  'clientCodePrefix': 'PL',
                },
              }
              as T,
    );
  }

  @override
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
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
                  'status': 'linked',
                  'clientId': 101,
                  'clientCode': 'PL-1001',
                  'clientCodes': ['PL-1001'],
                  'accessMode': 'pl_prefix',
                  'agent': '2a-logistic.ru',
                },
              }
              as T,
    );
  }
}
