import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twoalogisticcabineuser/src/features/photos/presentation/photo_report_video_player.dart';
import 'package:video_player/video_player.dart';
import 'package:twoalogisticcabineuser/src/features/photos/presentation/report_video_controls.dart';

class FakeVideoController extends VideoPlayerController {
  FakeVideoController({this.initialization})
    : super.networkUrl(Uri.parse('https://fixture.invalid/video.mp4'));
  final Completer<void>? initialization;
  int plays = 0, disposals = 0;
  @override
  Future<void> initialize() async {
    if (initialization != null) await initialization!.future;
    value = const VideoPlayerValue(
      duration: Duration(seconds: 60),
      size: Size(640, 360),
      isInitialized: true,
    );
  }

  @override
  Future<void> setLooping(bool looping) async {}
  @override
  Future<void> play() async {
    plays++;
    value = value.copyWith(isPlaying: true);
  }

  @override
  Future<void> pause() async {
    value = value.copyWith(isPlaying: false);
  }

  @override
  Future<void> seekTo(Duration position) async {
    value = value.copyWith(position: position);
  }

  @override
  Future<void> dispose() async {
    disposals++;
    await super.dispose();
  }
}

Widget player(
  bool active,
  ReportVideoControllerFactory factory, {
  String url = 'one',
}) => MaterialApp(
  home: Scaffold(
    body: Center(
      child: PhotoReportVideoPlayer(
        url: url,
        active: active,
        controllerFactory: factory,
      ),
    ),
  ),
);

void main() {
  testWidgets(
    'neighboring inactive video opens no stream, visible page starts once',
    (tester) async {
      final created = <FakeVideoController>[];
      Future<VideoPlayerController> factory(
        BuildContext context,
        String url,
      ) async {
        final controller = FakeVideoController();
        created.add(controller);
        return controller;
      }

      await tester.pumpWidget(player(false, factory));
      await tester.pump();
      expect(created, isEmpty);
      await tester.pumpWidget(player(true, factory));
      await tester.pumpAndSettle();
      expect(created.length, 1);
      expect(created.single.plays, 1);
      await tester.pumpWidget(player(false, factory));
      await tester.pump();
      expect(created.single.disposals, 1);
    },
  );

  testWidgets(
    'leaving a page during initialization prevents background autoplay',
    (tester) async {
      final initialization = Completer<void>();
      final controller = FakeVideoController(initialization: initialization);
      Future<VideoPlayerController> factory(
        BuildContext context,
        String url,
      ) async => controller;
      await tester.pumpWidget(player(true, factory));
      await tester.pump();
      await tester.pumpWidget(player(false, factory));
      initialization.complete();
      await tester.pumpAndSettle();
      expect(controller.plays, 0);
      expect(controller.disposals, 1);
      expect(find.byType(VideoPlayer), findsNothing);
    },
  );

  testWidgets(
    'reactivating gallery video restores position and responds to player state',
    (tester) async {
      final created = <FakeVideoController>[];
      Future<VideoPlayerController> factory(
        BuildContext context,
        String url,
      ) async {
        final controller = FakeVideoController();
        created.add(controller);
        return controller;
      }

      await tester.pumpWidget(player(true, factory));
      await tester.pumpAndSettle();
      await created.first.seekTo(const Duration(seconds: 17));
      await tester.pumpWidget(player(false, factory));
      await tester.pumpWidget(player(true, factory));
      await tester.pumpAndSettle();
      expect(created.length, 2);
      expect(created.last.value.position, const Duration(seconds: 17));
      await created.last.pause();
      await tester.pump();
      expect(find.byIcon(Icons.play_arrow_rounded), findsWidgets);
      await created.last.play();
      await tester.pump();
      expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
      expect(find.byType(ReportVideoControls), findsOneWidget);
    },
  );

  testWidgets(
    'changing video during an old pending load never installs stale controller',
    (tester) async {
      final wait = Completer<void>();
      final old = FakeVideoController(initialization: wait);
      final current = FakeVideoController();
      Future<VideoPlayerController> factory(
        BuildContext context,
        String url,
      ) async => url == 'one' ? old : current;
      await tester.pumpWidget(player(true, factory));
      await tester.pump();
      await tester.pumpWidget(player(true, factory, url: 'two'));
      await tester.pumpAndSettle();
      wait.complete();
      await tester.pumpAndSettle();
      expect(old.plays, 0);
      expect(old.disposals, 1);
      expect(current.plays, 1);
      expect(
        tester.widget<VideoPlayer>(find.byType(VideoPlayer)).controller,
        same(current),
      );
    },
  );
}
