import 'dart:async';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:twoalogisticcabineuser/src/core/network/api_client.dart';

class _MediaLaneAdapter implements HttpClientAdapter {
  final release = Completer<void>();
  final requests = <RequestOptions>[];
  int activeMedia = 0, maximumActiveMedia = 0;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (options.responseType == ResponseType.bytes) {
      activeMedia++;
      if (activeMedia > maximumActiveMedia) maximumActiveMedia = activeMedia;
      try {
        await Future.any([
          release.future,
          if (cancelFuture != null) cancelFuture,
        ]);
      } finally {
        activeMedia--;
      }
      return ResponseBody.fromBytes(
        [1, 2, 3],
        200,
        headers: {
          Headers.contentTypeHeader: ['image/jpeg'],
        },
      );
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

class _Client extends ApiClient {
  _Client(
    _MediaLaneAdapter adapter, {
    Duration timeout = const Duration(seconds: 5),
  }) : super(
         adapterFactory: () => adapter,
         runtimeHeaders: () async => {},
         requestTimeout: timeout,
       );
  @override
  Future<String?> getToken() async => 'test-only-media-token';
}

Future<void> _started(_MediaLaneAdapter adapter, int count) async {
  final until = DateTime.now().add(const Duration(seconds: 2));
  while (adapter.requests.length < count) {
    if (DateTime.now().isAfter(until)) fail('HTTP dispatch did not start');
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'slow binary photos cannot occupy metadata slots and remain bounded to two',
    () async {
      final adapter = _MediaLaneAdapter();
      final api = _Client(adapter);
      final downloads = List.generate(
        3,
        (i) => api.get<List<int>>(
          '/uploads/$i.jpg',
          options: Options(
            responseType: ResponseType.bytes,
            followRedirects: false,
            extra: {'private_media_no_redirect': true},
          ),
        ),
      );
      await _started(adapter, 2);
      final metadata = await Future.wait([
        api.get('/photos'),
        api.get('/tracks'),
      ]).timeout(const Duration(seconds: 1));
      expect(metadata.every((response) => response.statusCode == 200), isTrue);
      expect(
        adapter.requests
            .where((request) => request.responseType == ResponseType.bytes)
            .length,
        2,
      );
      expect(adapter.maximumActiveMedia, 2);
      expect(
        adapter.requests.first.headers['Authorization'],
        'Bearer test-only-media-token',
      );
      expect(adapter.requests.first.followRedirects, isFalse);
      expect(adapter.requests.first.extra['private_media_no_redirect'], isTrue);
      adapter.release.complete();
      await Future.wait(downloads);
      expect(adapter.maximumActiveMedia, 2);
      expect(
        adapter.requests
            .where((request) => request.responseType == ResponseType.bytes)
            .length,
        3,
      );
    },
  );
  test(
    'a queued media deadline removes its entry and does not leak a slot',
    () async {
      final adapter = _MediaLaneAdapter();
      final api = _Client(adapter, timeout: const Duration(milliseconds: 100));
      final running = List.generate(
        2,
        (i) => api.get<List<int>>(
          '/uploads/$i.jpg',
          options: Options(
            responseType: ResponseType.bytes,
            receiveTimeout: const Duration(seconds: 1),
          ),
        ),
      );
      await _started(adapter, 2);
      await expectLater(
        api.get<List<int>>(
          '/uploads/expired.jpg',
          options: Options(responseType: ResponseType.bytes),
        ),
        throwsA(isA<TimeoutException>()),
      );
      expect(
        adapter.requests.any((request) => request.path.endsWith('expired.jpg')),
        isFalse,
      );
      expect((await api.get('/tracks')).statusCode, 200);
      adapter.release.complete();
      await Future.wait(running);
      expect(
        (await api.get<List<int>>(
          '/uploads/next.jpg',
          options: Options(responseType: ResponseType.bytes),
        )).statusCode,
        200,
      );
      expect(adapter.maximumActiveMedia, 2);
    },
  );
}
