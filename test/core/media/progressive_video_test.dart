import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
// The existing video_player platform dependency supplies the official test seam.
// ignore: depend_on_referenced_packages
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:twoalogisticcabineuser/src/core/media/authenticated_video.dart';
import 'package:twoalogisticcabineuser/src/core/network/api_client.dart';

class _Api extends Mock implements ApiClient {}

class _Platform extends VideoPlayerPlatform {
  final events = StreamController<VideoEvent>();
  DataSource? source;
  Duration position = Duration.zero;
  @override
  Future<void> init() async {}
  @override
  Future<int> createWithOptions(VideoCreationOptions options) async {
    source = options.dataSource;
    events.add(
      VideoEvent(
        eventType: VideoEventType.initialized,
        duration: const Duration(seconds: 30),
        size: const Size(1920, 1080),
      ),
    );
    return 7;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => events.stream;
  @override
  Future<void> dispose(int playerId) async {
    await events.close();
  }

  @override
  Future<void> play(int playerId) async {}
  @override
  Future<void> pause(int playerId) async {}
  @override
  Future<void> setLooping(int playerId, bool looping) async {}
  @override
  Future<void> setVolume(int playerId, double volume) async {}
  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}
  @override
  Future<Duration> getPosition(int playerId) async => position;
  @override
  Future<void> seekTo(int playerId, Duration position) async {
    this.position = position;
  }
}

void main() {
  for (final missingChannel in [true, false]) {
    testWidgets(
      'native tuning failure keeps video playable (missing: $missingChannel)',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        final old = VideoPlayerPlatform.instance;
        final platform = _Platform();
        VideoPlayerPlatform.instance = platform;
        addTearDown(() {
          debugDefaultTargetPlatformOverride = null;
          VideoPlayerPlatform.instance = old;
        });
        final api = _Api();
        when(() => api.getToken()).thenAnswer((_) async => 'fixture-session');
        const channel = MethodChannel('com.twoalogistic.user/video_playback');
        var calls = 0;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          missingChannel
              ? null
              : (call) async {
                  calls++;
                  throw PlatformException(code: 'PLAYER_UNAVAILABLE');
                },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            channel,
            null,
          ),
        );
        late BuildContext context;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [apiClientProvider.overrideWithValue(api)],
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
        final controller = await createAuthenticatedVideoController(
          context,
          '/uploads/video.mp4',
          progressivePlayback: true,
        );
        final initialization = controller.initialize();
        await tester.pump();
        await initialization;
        await tester.runAsync(() => controller.play());
        expect(controller.value.isInitialized, isTrue);
        expect(controller.value.isPlaying, isTrue);
        expect(controller.value.hasError, isFalse);
        await tester.runAsync(
          () => controller.seekTo(const Duration(seconds: 15)),
        );
        expect(controller.value.position, const Duration(seconds: 15));
        await tester.runAsync(() => controller.pause());
        expect(controller.value.isPlaying, isFalse);
        await tester.runAsync(() => controller.play());
        expect(controller.value.isPlaying, isTrue);
        expect(
          calls,
          missingChannel ? 0 : 1,
          reason: 'Unavailable tuning must not be retried on every action',
        );
        await tester.runAsync(() => controller.dispose());
        debugDefaultTargetPlatformOverride = null;
      },
    );
  }
  testWidgets(
    'iOS streams, starts with partial buffer, resumes after seeks and respects pause',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final old = VideoPlayerPlatform.instance;
      final platform = _Platform();
      VideoPlayerPlatform.instance = platform;
      addTearDown(() {
        debugDefaultTargetPlatformOverride = null;
        VideoPlayerPlatform.instance = old;
      });
      final api = _Api();
      when(() => api.getToken()).thenAnswer((_) async => 'fixture-session');
      const channel = MethodChannel('com.twoalogistic.user/video_playback');
      final native = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        native.add(call);
        return null;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      late BuildContext context;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [apiClientProvider.overrideWithValue(api)],
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
      final controller = await createAuthenticatedVideoController(
        context,
        '/uploads/video.mp4',
        progressivePlayback: true,
      );
      final initialization = controller.initialize();
      await tester.pump();
      await initialization;
      expect(platform.source!.sourceType, DataSourceType.network);
      expect(
        platform.source!.httpHeaders['Authorization'],
        'Bearer fixture-session',
      );
      verifyNever(
        () => api.get<List<int>>(any(), options: any(named: 'options')),
      );
      controller.value = controller.value.copyWith(
        isBuffering: true,
        buffered: [DurationRange(Duration.zero, const Duration(seconds: 2))],
      );
      await tester.runAsync(() => controller.play());
      await tester.pump();
      expect(native, isNotEmpty);
      expect(native.last.method, 'playAvailable');
      expect(native.last.arguments['playerId'], 7);
      expect(
        controller.value.buffered.single.end,
        lessThan(controller.value.duration),
      );
      await tester.runAsync(
        () => controller.seekTo(const Duration(seconds: 15)),
      );
      await tester.pump();
      native.clear();
      controller.value = controller.value.copyWith(
        position: const Duration(seconds: 15),
        isBuffering: true,
        buffered: [DurationRange(Duration.zero, const Duration(seconds: 5))],
      );
      await tester.pump();
      expect(
        native,
        isEmpty,
        reason: 'Data at another position cannot resume a seek',
      );
      controller.value = controller.value.copyWith(
        buffered: [
          DurationRange(
            const Duration(seconds: 15),
            const Duration(seconds: 18),
          ),
        ],
      );
      await tester.pump();
      expect(native, isNotEmpty);
      await tester.runAsync(() => controller.pause());
      native.clear();
      controller.value = controller.value.copyWith(
        isBuffering: true,
        buffered: [
          DurationRange(
            const Duration(seconds: 15),
            const Duration(seconds: 22),
          ),
        ],
      );
      await tester.pump();
      expect(
        native,
        isEmpty,
        reason: 'Buffer updates must never cancel a manual pause',
      );
      await tester.runAsync(() => controller.dispose());
      await tester.pumpWidget(const SizedBox());
      debugDefaultTargetPlatformOverride = null;
    },
  );
}
