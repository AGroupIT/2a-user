import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:twoalogisticcabineuser/src/core/cache/stale_data_cache.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Response<dynamic> response(String value) => Response(
    requestOptions: RequestOptions(path: '/statuses'),
    statusCode: 200,
    data: <String, dynamic>{'value': value},
  );
  const cacheKey = 'stale_data_cache_v1:isolation';
  late SharedPreferences prefs;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StaleDataCache.clearAll();
    prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      cacheKey,
      jsonEncode({
        'cachedAt': DateTime.now().toUtc().toIso8601String(),
        'data': {'value': 'real'},
      }),
    );
  });
  Future<Map<String, dynamic>> read(
    ProviderContainer container,
    Future<Response<dynamic>> Function() request,
  ) {
    final provider = FutureProvider(
      (ref) => StaleDataCache.getJson(
        ref: ref,
        cacheKey: 'isolation',
        label: 'test',
        request: request,
      ),
    );
    return container.read(provider.future);
  }

  ProviderContainer isolated() {
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [staleDataCacheEnabledProvider.overrideWithValue(false)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test(
    'isolated response neither reads nor overwrites saved real data',
    () async {
      final before = prefs.getString(cacheKey);
      expect(await read(isolated(), () async => response('fixture')), {
        'value': 'fixture',
      });
      await Future<void>.delayed(Duration.zero);
      expect(prefs.getString(cacheKey), before);
      await expectLater(
        read(
          isolated(),
          () async => throw DioException(
            requestOptions: RequestOptions(path: '/statuses'),
            type: DioExceptionType.connectionError,
          ),
        ),
        throwsA(isA<DioException>()),
      );
      expect(prefs.getString(cacheKey), before);
    },
  );

  test(
    'isolated read does not share live production request with same key',
    () async {
      final normal = ProviderContainer(retry: (_, _) => null);
      addTearDown(normal.dispose);
      final pending = Completer<Response<dynamic>>();
      final production = read(normal, () => pending.future);
      await Future<void>.delayed(Duration.zero);
      final training = await read(
        isolated(),
        () async => response('fixture'),
      ).timeout(const Duration(seconds: 1));
      expect(training, {'value': 'fixture'});
      pending.complete(response('production'));
      expect(await production, {'value': 'production'});
      await Future<void>.delayed(const Duration(milliseconds: 10));
    },
  );
}
