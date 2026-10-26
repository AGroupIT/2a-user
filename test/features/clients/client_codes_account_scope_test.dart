import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:twoalogisticcabineuser/src/core/network/api_client.dart';
import 'package:twoalogisticcabineuser/src/core/persistence/shared_preferences_provider.dart';
import 'package:twoalogisticcabineuser/src/features/auth/data/auth_provider.dart';
import 'package:twoalogisticcabineuser/src/features/clients/application/client_codes_controller.dart';

class _Auth extends AuthNotifier {
  @override
  AuthState build() => _account(1, ['AA-84']);
  void change(int id, List<String> codes, {String domain = 'example'}) =>
      state = _account(id, codes, domain: domain);
  void clearSession() => state = const AuthState(isLoading: false);
}

AuthState _account(int id, List<String> codes, {String domain = 'example'}) =>
    AuthState(
      isLoggedIn: true,
      isLoading: false,
      clientId: id,
      userDomain: domain,
      clientData: {
        'codes': [
          for (final code in codes) {'code': code},
        ],
      },
    );

class _Api extends ApiClient {
  Completer<void>? pending;
  @override
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    expect(path, '/client-codes/link-by-pin');
    if (pending != null) await pending!.future;
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      statusCode: 200,
      data: <String, dynamic>{} as T,
    );
  }
}

Future<({ProviderContainer container, SharedPreferences prefs, _Api api})>
_fixture(Map<String, Object> initial) async {
  SharedPreferences.setMockInitialValues(initial);
  final prefs = await SharedPreferences.getInstance();
  final api = _Api();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      apiClientProvider.overrideWithValue(api),
      authProvider.overrideWith(_Auth.new),
    ],
  );
  addTearDown(container.dispose);
  return (container: container, prefs: prefs, api: api);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'legacy cache migrates only server-owned codes, preserving valid active code',
    () async {
      final f = await _fixture({
        'client_codes_list': ['OLD-1', 'OLD-2', 'AA-84'],
        'active_client_code': 'AA-84',
      });
      final state = await f.container.read(
        clientCodesControllerProvider.future,
      );
      expect(state.codes, ['AA-84']);
      expect(state.activeCode, 'AA-84');
      expect(f.prefs.getStringList('client_codes_list:example:1'), ['AA-84']);
    },
  );

  test('foreign legacy active code is rejected', () async {
    final f = await _fixture({
      'client_codes_list': ['FOREIGN'],
      'active_client_code': 'FOREIGN',
    });
    final state = await f.container.read(clientCodesControllerProvider.future);
    expect(state.codes, ['AA-84']);
    expect(state.activeCode, 'AA-84');
  });

  test(
    'PIN-linked code survives same-account rebuild but never crosses accounts',
    () async {
      final f = await _fixture({});
      await f.container.read(clientCodesControllerProvider.future);
      await f.container
          .read(clientCodesControllerProvider.notifier)
          .addClient(code: 'PIN-1', pin: '1234');
      f.container.invalidate(clientCodesControllerProvider);
      expect(
        (await f.container.read(clientCodesControllerProvider.future)).codes,
        ['AA-84', 'PIN-1'],
      );
      final auth = f.container.read(authProvider.notifier) as _Auth;
      auth.change(2, ['BB-2']);
      expect(
        (await f.container.read(clientCodesControllerProvider.future)).codes,
        ['BB-2'],
      );
      auth.change(1, ['AA-84']);
      expect(
        (await f.container.read(clientCodesControllerProvider.future)).codes,
        ['AA-84', 'PIN-1'],
      );
      expect(f.prefs.getStringList('client_codes_list:example:2'), ['BB-2']);
    },
  );

  test('same client id on another domain uses a separate cache', () async {
    final f = await _fixture({
      'client_codes_list:other:1': ['OTHER'],
    });
    expect(
      (await f.container.read(clientCodesControllerProvider.future)).codes,
      ['AA-84'],
    );
    (f.container.read(authProvider.notifier) as _Auth).change(1, [
      'DOMAIN-1',
    ], domain: 'other');
    expect(
      (await f.container.read(clientCodesControllerProvider.future)).codes,
      ['DOMAIN-1', 'OTHER'],
    );
  });

  test('late PIN response cannot update another account', () async {
    final f = await _fixture({});
    await f.container.read(clientCodesControllerProvider.future);
    f.api.pending = Completer<void>();
    final linking = f.container
        .read(clientCodesControllerProvider.notifier)
        .addClient(code: 'LATE', pin: '1234');
    (f.container.read(authProvider.notifier) as _Auth).change(2, ['BB-2']);
    await f.container.read(clientCodesControllerProvider.future);
    f.api.pending!.complete();
    await linking;
    expect(
      (await f.container.read(clientCodesControllerProvider.future)).codes,
      ['BB-2'],
    );
    expect(f.prefs.getStringList('client_codes_list:example:2'), ['BB-2']);
  });

  test('logged-out state hides all cached client codes', () async {
    final f = await _fixture({});
    await f.container.read(clientCodesControllerProvider.future);
    (f.container.read(authProvider.notifier) as _Auth).clearSession();
    final state = await f.container.read(clientCodesControllerProvider.future);
    expect(state.codes, isEmpty);
    expect(state.activeCode, isNull);
  });
}
