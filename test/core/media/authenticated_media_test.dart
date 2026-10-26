import 'package:flutter/painting.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:twoalogisticcabineuser/src/core/media/authenticated_media.dart';
import 'package:twoalogisticcabineuser/src/core/network/api_client.dart';

class _Api extends Mock implements ApiClient {}

void main() {
  test(
    'protected bytes use authenticated API and denial is not retried publicly',
    () async {
      final api = _Api();
      when(
        () => api.get<List<int>>(
          '/uploads/a.jpg',
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response<List<int>>(
          requestOptions: RequestOptions(path: '/uploads/a.jpg'),
          statusCode: 403,
          data: [1, 2, 3],
        ),
      );
      await expectLater(
        loadMediaBytes(api, 'https://api.2a-logistic.com/uploads/a.jpg'),
        throwsStateError,
      );
      final options =
          verify(
                () => api.get<List<int>>(
                  '/uploads/a.jpg',
                  options: captureAny(named: 'options'),
                ),
              ).captured.single
              as Options;
      expect(options.followRedirects, isFalse);
      expect(options.maxRedirects, 0);
      expect(options.headers?['Accept-Encoding'], 'identity');
      verifyNoMoreInteractions(api);
    },
  );

  test('only exact trusted origins and media routes receive authorization', () {
    expect(
      authenticatedMediaPath('/uploads/tracks/a.jpg'),
      '/uploads/tracks/a.jpg',
    );
    expect(
      authenticatedMediaPath(
        'https://api.2a-logistic.com/api/uploads/preview/360/a.jpg',
      ),
      '/uploads/preview/360/a.jpg',
    );
    expect(
      authenticatedMediaPath('/api/assembly-scan-media/playback?token=signed'),
      '/assembly-scan-media/playback?token=signed',
    );
    expect(
      authenticatedMediaPath('/api/support/attachments/123'),
      '/support/attachments/123',
    );
    for (final url in [
      'https://api.2a-logistic.com.evil.test/uploads/a.jpg',
      'https://api.2a-logistic.com@evil.test/uploads/a.jpg',
      '//api.2a-logistic.com/uploads/a.jpg',
      'https://api.2a-logistic.com:8443/uploads/a.jpg',
      'https://example.com/uploads/a.jpg',
      '/api/employees',
      'data:image/png;base64,abc',
    ]) {
      expect(authenticatedMediaPath(url), isNull, reason: url);
    }
  });

  test('decoded image cache key changes after login session changes', () async {
    final api = _Api();
    var session = 'first-session';
    when(() => api.getToken()).thenAnswer((_) async => session);
    final image = AuthenticatedMediaImage('/uploads/a.jpg', api);
    final first = await image.obtainKey(ImageConfiguration.empty);
    expect(await image.obtainKey(ImageConfiguration.empty), first);
    session = 'second-session';
    expect(await image.obtainKey(ImageConfiguration.empty), isNot(first));
  });
}
