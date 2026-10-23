import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:twoalogisticcabineuser/src/core/network/api_client.dart';
import 'package:twoalogisticcabineuser/src/core/media/authenticated_media.dart';

class TestMediaApi extends ApiClient {
  @override
  Future<Response<T>> getWithProgress<T>(
    String path, {
    Options? options,
    required ProgressCallback onReceiveProgress,
  }) => get<T>(path, options: options);

  String? token = 'first-session';
  String? requestedPath;
  Options? requestedOptions;
  int responseStatus = 200;
  bool changeSessionDuringRequest = false;
  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    if (changeSessionDuringRequest) token = 'replacement-session';
    requestedPath = path;
    requestedOptions = options;
    return Response<T>(
      data: <int>[1, 2, 3] as T,
      statusCode: responseStatus,
      requestOptions: RequestOptions(path: path),
    );
  }

  @override
  Future<String?> getToken() async => token;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'logout and re-login do not reuse decoded keys with the same credential',
    () async {
      SharedPreferences.setMockInitialValues({});
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final api = TestMediaApi();
      final image = AuthenticatedMediaImage('/uploads/a.jpg', api);
      final original = await image.obtainKey(ImageConfiguration.empty);
      await api.clearToken();
      final loggedOut = await image.obtainKey(ImageConfiguration.empty);
      expect(loggedOut, isNot(original));
      await api.setToken('first-session');
      expect(await image.obtainKey(ImageConfiguration.empty), isNot(original));
      expect(await image.obtainKey(ImageConfiguration.empty), isNot(loggedOut));
    },
  );
  test('decoded cache keys separate accounts and API instances', () async {
    final api = TestMediaApi();
    final image = AuthenticatedMediaImage('/uploads/a.jpg', api);
    final first = await image.obtainKey(ImageConfiguration.empty);
    expect(await image.obtainKey(ImageConfiguration.empty), first);
    api.token = 'another-account';
    final second = await image.obtainKey(ImageConfiguration.empty);
    expect(second, isNot(first));
    api.token = null;
    expect(await image.obtainKey(ImageConfiguration.empty), isNot(first));
    expect(
      await AuthenticatedMediaImage(
        '/uploads/a.jpg',
        TestMediaApi(),
      ).obtainKey(ImageConfiguration.empty),
      isNot(first),
    );
  });

  test(
    'protected download uses API authentication and forbids redirects',
    () async {
      final api = TestMediaApi();
      expect(await loadMediaBytes(api, '/api/uploads/a.jpg'), [1, 2, 3]);
      expect(api.requestedPath, '/uploads/a.jpg');
      expect(api.requestedOptions!.responseType, ResponseType.bytes);
      expect(api.requestedOptions!.followRedirects, false);
      expect(api.requestedOptions!.maxRedirects, 0);
      expect(api.requestedOptions!.extra?['private_media_no_redirect'], true);
      api.responseStatus = 302;
      await expectLater(
        loadMediaBytes(api, '/uploads/a.jpg'),
        throwsStateError,
      );
      api.responseStatus = 404;
      await expectLater(
        loadMediaBytes(api, '/uploads/a.jpg'),
        throwsStateError,
      );
    },
  );
  test('download discards bytes when credentials change in flight', () async {
    final api = TestMediaApi()..changeSessionDuringRequest = true;
    await expectLater(
      loadMediaBytes(api, '/uploads/private.mp4'),
      throwsStateError,
    );
  });
  group('private media URI boundary', () {
    test('uploads and thumbnail query use an authenticated relative route', () {
      expect(
        authenticatedMediaPath('/api/uploads/reports/a.jpg?width=360'),
        '/uploads/reports/a.jpg?width=360',
      );
      expect(
        authenticatedMediaPath('/uploads/reports/a.jpg'),
        '/uploads/reports/a.jpg',
      );
      expect(
        authenticatedMediaPath('https://api.2a-logistic.com/api/uploads/a.jpg'),
        '/uploads/a.jpg',
      );
      expect(
        authenticatedMediaPath('/api/support/attachments/123'),
        '/support/attachments/123',
      );
    });
    test(
      'external origins, userinfo and non-media routes receive no token',
      () {
        for (final value in [
          'https://api.2a-logistic.com.evil.test/uploads/a.jpg',
          'https://evil.test/uploads/a.jpg',
          'https://user@api.2a-logistic.com/uploads/a.jpg',
          'https://api.2a-logistic.com:444/uploads/a.jpg',
          '//api.2a-logistic.com/uploads/a.jpg',
          'data:image/png;base64,abc',
          '/api/employees',
        ]) {
          expect(authenticatedMediaPath(value), isNull, reason: value);
        }
      },
    );
    test(
      'signed scan playback opts into a redirect-free authenticated proxy',
      () {
        final path = authenticatedMediaPath(
          'https://api.2a-logistic.com/api/assembly-scan-media/playback?token=signed%2Bvalue&proxy=0',
        );
        final uri = Uri.parse(path!);
        expect(uri.path, '/assembly-scan-media/playback');
        expect(uri.queryParameters['token'], 'signed+value');
        expect(uri.queryParameters['proxy'], '1');
        expect(
          authenticatedMediaPath(
            'https://evil.test/api/assembly-scan-media/playback?token=x',
          ),
          isNull,
        );
      },
    );
    test('traversal and encoded separators cannot escape media routes', () {
      for (final value in [
        '/uploads/../employees',
        '/uploads/%2e%2e/employees',
        '/uploads/a%2fb.jpg',
        '/uploads/a%5cb.jpg',
        '/uploads/%252e%252e/employees',
      ]) {
        expect(authenticatedMediaPath(value), isNull, reason: value);
      }
    });
  });
}
