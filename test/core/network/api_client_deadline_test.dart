import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:twoalogisticcabineuser/src/core/network/api_client.dart';

class _Adapter implements HttpClientAdapter {
  final List<String> paths = [];
  DioExceptionType? failure;
  bool block = true;
  final release = Completer<void>();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? body,
    Future<void>? cancelFuture,
  ) async {
    paths.add(options.path);
    if (failure != null) {
      throw DioException(requestOptions: options, type: failure!);
    }
    if (block) {
      await Future.any([
        release.future,
        if (cancelFuture != null) cancelFuture,
      ]);
    }
    return ResponseBody.fromString(
      '{}',
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'hung optional runtime metadata does not prevent HTTP dispatch',
    () async {
      final adapter = _Adapter()..block = false;
      final client = ApiClient(
        adapterFactory: () => adapter,
        runtimeHeaders: () => Completer<Map<String, String>>().future,
        requestTimeout: const Duration(seconds: 5),
      );
      expect((await client.get('/metadata-timeout')).statusCode, 200);
      expect(adapter.paths, ['/metadata-timeout']);
    },
  );

  test(
    'queued GET expires without being sent, and slots remain reusable',
    () async {
      final adapter = _Adapter();
      final client = ApiClient(
        adapterFactory: () => adapter,
        runtimeHeaders: () async => {},
        requestTimeout: const Duration(seconds: 1),
      );
      final requests = List.generate(
        3,
        (i) => client.get(
          '/deadline-$i',
          options: Options(receiveTimeout: const Duration(seconds: 1)),
        ),
      );
      while (adapter.paths.length < 3) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      await expectLater(
        client.get('/deadline-3'),
        throwsA(isA<TimeoutException>()),
      );
      expect(adapter.paths, isNot(contains('/deadline-3')));
      adapter.release.complete();
      expect(
        (await Future.wait(requests)).map((response) => response.statusCode),
        everyElement(200),
      );
      adapter.block = false;
      expect((await client.get('/next')).statusCode, 200);
    },
  );

  for (final type in [
    DioExceptionType.sendTimeout,
    DioExceptionType.connectionError,
  ]) {
    test('JSON POST does not replay an ambiguous $type', () async {
      final adapter = _Adapter()..failure = type;
      final client = ApiClient(
        adapterFactory: () => adapter,
        runtimeHeaders: () async => {},
      );
      await expectLater(
        client.post('/mutation', data: {'amount': 1}),
        throwsA(isA<DioException>()),
      );
      expect(adapter.paths, ['/mutation']);
    });
  }
}
