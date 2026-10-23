import 'dart:async';
import 'dart:ui' as ui;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twoalogisticcabineuser/src/core/media/authenticated_media.dart';
import 'package:twoalogisticcabineuser/src/core/network/api_client.dart';
import 'package:twoalogisticcabineuser/src/core/ui/app_cached_media_image.dart';
import 'package:twoalogisticcabineuser/src/core/ui/blurred_media_backdrop.dart';
import '../../fixtures/media_api.dart';

class _ImageApi extends ApiClient {
  @override
  Future<Response<T>> getWithProgress<T>(
    String path, {
    Options? options,
    required ProgressCallback onReceiveProgress,
  }) => get<T>(path, options: options);

  List<int> payload = [1, 2, 3];
  int requests = 0;
  @override
  Future<String> getMediaCacheIdentity() async => 'image-decoder-session';
  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    requests++;
    return Response<T>(
      data: payload as T,
      statusCode: 200,
      requestOptions: RequestOptions(path: path),
    );
  }
}

class _FrameFailureCodec implements ui.Codec {
  @override
  int get frameCount => 1;
  @override
  int get repetitionCount => 0;
  @override
  Future<ui.FrameInfo> getNextFrame() async =>
      throw StateError('Corrupt image frame');
  @override
  void dispose() {}
}

Future<bool> _decode(
  AuthenticatedMediaImage provider, {
  ImageDecoderCallback? decoder,
}) async {
  final key = await provider.obtainKey(ImageConfiguration.empty);
  final completer = provider.loadImage(
    key,
    decoder ?? PaintingBinding.instance.instantiateImageCodecWithSize,
  );
  final result = Completer<bool>();
  final listener = ImageStreamListener((image, _) {
    image.dispose();
    result.complete(true);
  }, onError: (Object error, StackTrace? stack) => result.complete(false));
  completer.addListener(listener);
  try {
    return await result.future.timeout(const Duration(seconds: 5));
  } finally {
    completer.removeListener(listener);
  }
}

void main() {
  testWidgets(
    'shared photo loaders bound decode size without stretching images',
    (tester) async {
      late BuildContext context;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [apiClientProvider.overrideWithValue(mediaFixtureApi())],
          child: MaterialApp(
            home: Builder(
              builder: (ctx) {
                context = ctx;
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      final cached =
          const AuthenticatedCachedImage(
                imageUrl: '/uploads/full.jpg',
              ).build(context)
              as Image;
      final cachedProvider = cached.image as ResizeImage;
      expect(cachedProvider.width, 1600);
      expect(cachedProvider.height, 1600);
      expect(cachedProvider.policy, ResizeImagePolicy.fit);
      final original =
          const AuthenticatedImage.network(
                '/uploads/full.jpg',
                cacheWidth: 320,
              ).build(context)
              as Image;
      final imageProvider = original.image as ResizeImage;
      expect(imageProvider.width, 320);
      expect(imageProvider.height, isNull);
      expect(imageProvider.policy, ResizeImagePolicy.fit);
    },
  );
  testWidgets(
    'blurred fullscreen backdrop uses a small thumbnail and only one blur',
    (tester) async {
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) {
              context = ctx;
              return const SizedBox();
            },
          ),
        ),
      );
      final stack =
          const BlurredMediaBackdrop(
                imageUrl: '/uploads/full.jpg',
                child: SizedBox(),
              ).build(context)
              as Stack;
      final positioned = stack.children.whereType<Positioned>().first;
      final filter = positioned.child as ImageFiltered;
      final transform = filter.child as Transform;
      final thumbnail = transform.child as AppCachedMediaImage;
      expect(thumbnail.thumbnailSize, 360);
      expect(thumbnail.memCacheWidth, 360);
      expect(thumbnail.memCacheHeight, 360);
      final image = thumbnail.build(context) as AuthenticatedCachedImage;
      expect(image.imageUrl, contains('/preview/360/'));
      expect(stack.children.whereType<BackdropFilter>(), isEmpty);
      expect(
        (stack.children.whereType<Positioned>().last).child,
        isA<ColoredBox>(),
      );
    },
  );
  testWidgets(
    'fit decoder actually reduces a large original while preserving aspect ratio',
    (tester) async {
      final image = await tester.runAsync(() async {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        canvas.drawColor(Colors.blue, BlendMode.src);
        final picture = recorder.endRecording();
        final original = await picture.toImage(2400, 1200);
        picture.dispose();
        final bytes = await original.toByteData(format: ui.ImageByteFormat.png);
        original.dispose();
        final provider = ResizeImage(
          MemoryImage(bytes!.buffer.asUint8List()),
          width: 1600,
          height: 1600,
          policy: ResizeImagePolicy.fit,
        );
        final result = Completer<ImageInfo>();
        final stream = provider.resolve(ImageConfiguration.empty);
        final listener = ImageStreamListener(
          (info, _) => result.complete(info),
          onError: (Object error, StackTrace? stack) =>
              result.completeError(error, stack),
        );
        stream.addListener(listener);
        try {
          return await result.future.timeout(const Duration(seconds: 5));
        } finally {
          stream.removeListener(listener);
        }
      });
      expect(image!.image.width, 1600);
      expect(image.image.height, 800);
      image.dispose();
    },
  );
  testWidgets(
    'invalid HTTP 200 image is evicted and a repaired same URL refetches',
    (tester) async {
      await tester.runAsync(() async {
        final api = _ImageApi();
        final provider = AuthenticatedMediaImage(
          '/uploads/preview/360/repaired.jpg',
          api,
        );
        expect(await _decode(provider), isFalse);
        expect(api.requests, 1);
        final recorder = ui.PictureRecorder();
        Canvas(recorder).drawColor(Colors.blue, BlendMode.src);
        final picture = recorder.endRecording();
        final image = await picture.toImage(2, 1);
        picture.dispose();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        api.payload = bytes!.buffer.asUint8List();
        expect(await _decode(provider), isTrue);
        expect(api.requests, 2);
        expect(await _decode(provider), isTrue);
        expect(api.requests, 2, reason: 'Valid bytes are reused after repair');
      });
    },
  );
  testWidgets('late codec frame failure also evicts HTTP 200 encoded bytes', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final api = _ImageApi();
      final provider = AuthenticatedMediaImage(
        '/uploads/frame-corrupt.jpg',
        api,
      );
      Future<ui.Codec> failedFrame(
        ui.ImmutableBuffer buffer, {
        ui.TargetImageSizeCallback? getTargetSize,
      }) async {
        buffer.dispose();
        return _FrameFailureCodec();
      }

      expect(await _decode(provider, decoder: failedFrame), isFalse);
      expect(api.requests, 1);
      expect(await _decode(provider, decoder: failedFrame), isFalse);
      expect(
        api.requests,
        2,
        reason: 'A late frame failure cannot poison the byte cache',
      );
    });
  });
}
