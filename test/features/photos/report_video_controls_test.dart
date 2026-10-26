import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player/video_player.dart';
import 'package:twoalogisticcabineuser/src/features/photos/presentation/report_video_controls.dart';

class _Controller extends ValueNotifier<VideoPlayerValue>
    implements VideoPlayerController {
  _Controller()
    : super(
        const VideoPlayerValue(
          duration: Duration(minutes: 1),
          isInitialized: true,
          position: Duration(seconds: 5),
        ),
      );
  final seeks = <Duration>[];

  @override
  Future<void> play() async => value = value.copyWith(isPlaying: true);
  @override
  Future<void> pause() async => value = value.copyWith(isPlaying: false);
  @override
  Future<void> seekTo(Duration position) async {
    seeks.add(position);
    value = value.copyWith(position: position);
  }

  @override
  Future<void> dispose() async => super.dispose();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets(
    'download buffer is shown on seek timeline without a second loader',
    (tester) async {
      final controller = _Controller();
      controller.value = controller.value.copyWith(
        isBuffering: true,
        buffered: [DurationRange(Duration.zero, const Duration(seconds: 40))],
      );
      await tester.pumpWidget(
        MaterialApp(
          builder: (_, child) => Material(child: child),
          home: Center(
            child: SizedBox(
              width: 360,
              child: ReportVideoControls(controller: controller),
            ),
          ),
        ),
      );
      final slider = tester.widget<Slider>(find.byType(Slider));
      expect(slider.value, 5000);
      expect(slider.secondaryTrackValue, 40000);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await controller.dispose();
    },
  );

  testWidgets('play/pause, current time, skip bounds and replay at end', (
    tester,
  ) async {
    final controller = _Controller();
    await tester.pumpWidget(
      MaterialApp(
        builder: (_, child) => Material(child: child),
        home: Center(
          child: SizedBox(
            width: 360,
            child: ReportVideoControls(controller: controller),
          ),
        ),
      ),
    );
    expect(find.text('00:05 / 01:00'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await tester.pump();
    expect(controller.value.isPlaying, isTrue);
    await tester.tap(find.byIcon(Icons.pause_rounded));
    await tester.pump();
    expect(controller.value.isPlaying, isFalse);
    await tester.tap(find.byIcon(Icons.replay_10_rounded));
    await tester.pump();
    expect(controller.seeks.last, Duration.zero);
    controller.value = controller.value.copyWith(
      position: const Duration(seconds: 55),
    );
    await tester.pump();
    await tester.tap(find.byIcon(Icons.forward_10_rounded));
    await tester.pump();
    expect(controller.seeks.last, const Duration(minutes: 1));
    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await tester.pump();
    expect(controller.seeks.last, Duration.zero);
    expect(controller.value.isPlaying, isTrue);
    await tester.pumpWidget(const SizedBox());
    await controller.dispose();
  });

  testWidgets('slider seeks while playing and wins the gallery swipe gesture', (
    tester,
  ) async {
    final controller = _Controller();
    await controller.play();
    var page = 0;
    await tester.pumpWidget(
      MaterialApp(
        builder: (_, child) => Material(child: child),
        home: Center(
          child: SizedBox(
            width: 360,
            height: 200,
            child: PageView(
              onPageChanged: (value) => page = value,
              children: [
                Center(child: ReportVideoControls(controller: controller)),
                const Text('next photo'),
              ],
            ),
          ),
        ),
      ),
    );
    final slider = find.byType(Slider);
    await tester.drag(slider, const Offset(70, 0));
    await tester.pump();
    expect(controller.seeks, isNotEmpty);
    expect(controller.seeks.last.inSeconds, greaterThan(30));
    expect(controller.value.isPlaying, isTrue);
    expect(page, 0);
    await tester.pumpWidget(const SizedBox());
    await controller.dispose();
  });

  testWidgets('inactive page cannot resume playback or seek', (tester) async {
    final controller = _Controller();
    await tester.pumpWidget(
      MaterialApp(
        builder: (_, child) => Material(child: child),
        home: Center(
          child: SizedBox(
            width: 360,
            child: ReportVideoControls(controller: controller, active: false),
          ),
        ),
      ),
    );
    expect(tester.widget<Slider>(find.byType(Slider)).onChanged, isNull);
    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.play_arrow_rounded),
          )
          .onPressed,
      isNull,
    );
    await tester.pumpWidget(const SizedBox());
    await controller.dispose();
  });
}
