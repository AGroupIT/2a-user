import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:twoalogisticcabineuser/src/core/cache/stale_data_cache.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const key = 'stale_data_cache_v1:test';
  Response<dynamic> response() => Response(
    requestOptions: RequestOptions(path: '/test'),
    statusCode: 200,
    data: <String, dynamic>{'value': 'fresh'},
  );
  Future<Map<String, dynamic>> read(
    Future<Response<dynamic>> Function() request,
  ) {
    final provider = FutureProvider(
      (ref) => StaleDataCache.getJson(
        ref: ref,
        cacheKey: 'test',
        label: 'test',
        request: request,
        timeout: const Duration(milliseconds: 10),
      ),
    );
    final container = ProviderContainer(retry: (_, _) => null);
    addTearDown(container.dispose);
    return container.read(provider.future);
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StaleDataCache.clearAll();
  });

  test(
    'late successful response refreshes cache after reader timed out',
    () async {
      final pending = Completer<Response<dynamic>>();
      await expectLater(
        read(() => pending.future),
        throwsA(isA<TimeoutException>()),
      );
      pending.complete(response());
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final prefs = await SharedPreferences.getInstance();
      expect(jsonDecode(prefs.getString(key)!)['data']['value'], 'fresh');
    },
  );

  test('same cache key shares one in-flight read', () async {
    final pending = Completer<Response<dynamic>>();
    var calls = 0;
    Future<Response<dynamic>> request() {
      calls++;
      return pending.future;
    }

    final first = read(request);
    final second = read(request);
    await Future<void>.delayed(Duration.zero);
    pending.complete(response());
    expect(await first, {'value': 'fresh'});
    expect(await second, {'value': 'fresh'});
    expect(calls, 1);
  });

  test('logout fences late responses from repopulating cache', () async {
    final pending = Completer<Response<dynamic>>();
    await expectLater(
      read(() => pending.future),
      throwsA(isA<TimeoutException>()),
    );
    await StaleDataCache.clearAll();
    pending.complete(response());
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect((await SharedPreferences.getInstance()).getString(key), isNull);
  });

  test(
    'response from a previous session is not returned to its reader',
    () async {
      final pending = Completer<Response<dynamic>>();
      final result = read(() => pending.future);
      final rejected = expectLater(result, throwsA(isA<StateError>()));
      await Future<void>.delayed(Duration.zero);
      await StaleDataCache.clearAll();
      pending.complete(response());
      await rejected;
    },
  );

  test('expired snapshots are not returned as fallback', () async {
    SharedPreferences.setMockInitialValues({
      key: jsonEncode({
        'cachedAt': DateTime.now()
            .subtract(const Duration(days: 8))
            .toIso8601String(),
        'data': {'value': 'expired'},
      }),
    });
    await expectLater(
      read(() => Future.error(TimeoutException('offline'))),
      throwsA(isA<TimeoutException>()),
    );
  });

  test(
    'disposed reader does not emit a notice into its dead provider',
    () async {
      SharedPreferences.setMockInitialValues({
        key: jsonEncode({
          'cachedAt': DateTime.now().toUtc().toIso8601String(),
          'data': {'value': 'saved'},
        }),
      });
      final container = ProviderContainer();
      final ref = container.read(Provider<Ref>((ref) => ref));
      container.dispose();
      expect(ref.mounted, isFalse);
      final data = await StaleDataCache.getJson(
        ref: ref,
        cacheKey: 'test',
        label: 'test',
        request: () => Future.error(TimeoutException('offline')),
      );
      expect(data, {'value': 'saved'});
    },
  );

  test('retention evicts oldest entries above count limit', () async {
    SharedPreferences.setMockInitialValues({
      for (var i = 0; i < StaleDataCache.maxEntries; i++)
        'stale_data_cache_v1:old-$i': jsonEncode({
          'cachedAt': DateTime.now()
              .subtract(Duration(minutes: i + 1))
              .toIso8601String(),
          'data': {'i': i},
        }),
    });
    await read(() async => response());
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getKeys().where((k) => k.startsWith('stale_data_cache_v1:')),
      hasLength(100),
    );
    expect(prefs.getString('stale_data_cache_v1:old-99'), isNull);
    expect(prefs.getString(key), isNotNull);
  });
}
