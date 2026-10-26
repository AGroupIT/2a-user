import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:twoalogisticcabineuser/src/core/media/authenticated_media.dart';
import 'package:twoalogisticcabineuser/src/core/network/api_client.dart';
import 'package:twoalogisticcabineuser/src/core/ui/media_loading_indicator.dart';

class _Api extends Mock implements ApiClient {}

final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
);

void main() {
  for (final known in [true, false]) {
    testWidgets(
      'authenticated image reports chunks and finishes (known size: $known)',
      (tester) async {
        final api = _Api();
        final response = Completer<Response<List<int>>>();
        ProgressCallback? onProgress;
        when(
          () => api.getToken(),
        ).thenAnswer((_) async => 'progress-test-session');
        when(
          () => api.getWithProgress<List<int>>(
            any(),
            options: any(named: 'options'),
            onReceiveProgress: any(named: 'onReceiveProgress'),
          ),
        ).thenAnswer((invocation) {
          onProgress =
              invocation.namedArguments[#onReceiveProgress] as ProgressCallback;
          return response.future;
        });
        final url = '/uploads/progress-${known ? 'known' : 'unknown'}.png';
        await tester.pumpWidget(
          ProviderScope(
            overrides: [apiClientProvider.overrideWithValue(api)],
            child: MaterialApp(
              home: Center(
                child: AuthenticatedCachedImage(
                  imageUrl: url,
                  progressIndicatorBuilder: (_, _, event) =>
                      MediaLoadingIndicator(progress: event),
                  errorWidget: (_, _, _) => const Text('image failed'),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(onProgress, isNotNull);
        expect(
          tester.getSize(find.byType(MediaLoadingIndicator)),
          const Size(72, 72),
        );
        onProgress!(34, known ? _png.length : -1);
        await tester.pump();
        final indicator = tester.widget<CircularProgressIndicator>(
          find.byType(CircularProgressIndicator),
        );
        if (known) {
          expect(indicator.value, closeTo(34 / _png.length, .001));
          expect(
            find.text('${(34 / _png.length * 100).floor()}%'),
            findsOneWidget,
          );
        } else {
          expect(indicator.value, isNull);
          expect(find.textContaining('%'), findsNothing);
        }
        onProgress!(_png.length, known ? _png.length : -1);
        response.complete(
          Response<List<int>>(
            data: _png,
            statusCode: 200,
            requestOptions: RequestOptions(path: url),
          ),
        );
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pumpAndSettle();
        expect(find.byType(MediaLoadingIndicator), findsNothing);
        expect(find.text('image failed'), findsNothing);
        await tester.pumpWidget(const SizedBox());
        PaintingBinding.instance.imageCache.clear();
        PaintingBinding.instance.imageCache.clearLiveImages();
      },
    );
  }
  testWidgets('percentage fits inside loader and clamps overshoot', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: MediaLoadingIndicator(
            progress: ImageChunkEvent(
              cumulativeBytesLoaded: 110,
              expectedTotalBytes: 100,
            ),
          ),
        ),
      ),
    );
    expect(find.text('100%'), findsOneWidget);
    expect(
      tester
          .widget<CircularProgressIndicator>(
            find.byType(CircularProgressIndicator),
          )
          .value,
      1,
    );
    expect(tester.takeException(), isNull);
  });
}
