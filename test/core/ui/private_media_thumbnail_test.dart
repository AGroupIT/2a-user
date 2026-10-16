import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twoalogisticcabineuser/src/core/network/api_client.dart';
import 'package:twoalogisticcabineuser/src/core/ui/app_cached_media_image.dart';

class ThumbnailApi extends ApiClient {
  final requests = <String>[];
  @override
  Future<String?> getToken() async => 'test-session';

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    requests.add(path);
    expect(options!.followRedirects, false);
    expect(options.responseType, ResponseType.bytes);
    final thumbnail = path.startsWith('/uploads/preview/');
    return Response<T>(
      statusCode: thumbnail ? 404 : 200,
      data:
          base64Decode(
                'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4z8DwHwAFAAH/iZk9HQAAAABJRU5ErkJggg==',
              )
              as T,
      requestOptions: RequestOptions(path: path),
    );
  }
}

void main() {
  testWidgets('private thumbnail falls back through the authenticated API', (
    tester,
  ) async {
    final api = ThumbnailApi();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(api)],
        child: const MaterialApp(
          home: SizedBox(
            width: 100,
            height: 100,
            child: AppCachedMediaImage(url: '/uploads/report/a.png'),
          ),
        ),
      ),
    );
    // Codec work runs outside the fake clock used by widget animations.
    for (var attempt = 0; attempt < 5; attempt++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump();
    }
    expect(api.requests, [
      '/uploads/preview/360/report/a.png',
      '/uploads/report/a.png',
    ]);
    expect(find.byIcon(Icons.broken_image_outlined), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
