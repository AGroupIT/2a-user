import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twoalogisticcabineuser/src/core/ui/media_image_viewport.dart';

Future<void> doubleTap(WidgetTester tester) async {
  final center = tester.getCenter(find.byType(InteractiveViewer).first);
  await tester.tapAt(center);
  await tester.pump(const Duration(milliseconds: 100));
  await tester.tapAt(center);
  await tester.pumpAndSettle();
}

double scale(WidgetTester tester) => tester
    .widget<InteractiveViewer>(find.byType(InteractiveViewer).first)
    .transformationController!
    .value
    .getMaxScaleOnAxis();
Widget viewport({
  String identity = 'first',
  bool active = true,
  VoidCallback? dismiss,
  ValueChanged<bool>? blocked,
}) => MaterialApp(
  theme: ThemeData(platform: TargetPlatform.android),
  home: SizedBox.expand(
    child: MediaImageViewport(
      imageKey: identity,
      active: active,
      onDismiss: dismiss,
      onInteractionBlockedChanged: blocked,
      child: const ColoredBox(color: Colors.blue),
    ),
  ),
);

void main() {
  testWidgets('double tap zooms around image and returns to default scale', (
    tester,
  ) async {
    final events = <bool>[];
    await tester.pumpWidget(viewport(blocked: events.add));
    await doubleTap(tester);
    expect(scale(tester), 2.5);
    expect(
      tester
          .widget<InteractiveViewer>(find.byType(InteractiveViewer))
          .panEnabled,
      isTrue,
    );
    await doubleTap(tester);
    expect(scale(tester), 1);
    expect(events, [true, false]);
  });
  testWidgets('changing image or deactivating a page resets transformation', (
    tester,
  ) async {
    await tester.pumpWidget(viewport());
    await doubleTap(tester);
    expect(scale(tester), greaterThan(1));
    await tester.pumpWidget(viewport(identity: 'second'));
    await tester.pump();
    expect(scale(tester), 1);
    await doubleTap(tester);
    await tester.pumpWidget(viewport(identity: 'second', active: false));
    await tester.pump();
    expect(scale(tester), 1);
  });
  testWidgets(
    'pinch clamps scale and cannot dismiss on finger release or zoomed pan',
    (tester) async {
      var dismissed = 0;
      await tester.pumpWidget(viewport(dismiss: () => dismissed++));
      final center = tester.getCenter(find.byType(InteractiveViewer));
      final a = await tester.createGesture(pointer: 1),
          b = await tester.createGesture(pointer: 2);
      await a.down(center - const Offset(20, 0));
      await b.down(center + const Offset(20, 0));
      await tester.pump();
      await a.moveTo(center - const Offset(250, 0));
      await b.moveTo(center + const Offset(250, 0));
      await tester.pump();
      await a.moveTo(center - const Offset(1000, 0));
      await b.moveTo(center + const Offset(1000, 0));
      await tester.pump();
      expect(scale(tester), 4);
      await a.moveTo(center - const Offset(1, 0));
      await b.moveTo(center + const Offset(1, 0));
      await tester.pump();
      expect(scale(tester), 1);
      await a.up();
      await b.up();
      await tester.pumpAndSettle();
      expect(dismissed, 0);
      await doubleTap(tester);
      expect(scale(tester), 2.5);
      await tester.drag(find.byType(InteractiveViewer), const Offset(0, 180));
      await tester.pumpAndSettle();
      expect(dismissed, 0);
    },
  );
  testWidgets(
    'single finger vertical dismiss works at 1x and cancellation does not dismiss',
    (tester) async {
      var dismissed = 0;
      await tester.pumpWidget(viewport(dismiss: () => dismissed++));
      await tester.drag(find.byType(InteractiveViewer), const Offset(0, 180));
      await tester.pumpAndSettle();
      expect(dismissed, 1);
      final gesture = await tester.createGesture(pointer: 3);
      final center = tester.getCenter(find.byType(InteractiveViewer));
      await gesture.down(center);
      await gesture.moveBy(const Offset(0, 180));
      await gesture.cancel();
      await tester.pump(const Duration(milliseconds: 500));
      expect(dismissed, 1);
    },
  );
  testWidgets(
    'zoom blocks page gestures; reset allows horizontal gallery navigation',
    (tester) async {
      bool blocked = false;
      int page = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) => PageView.builder(
              physics: blocked ? const NeverScrollableScrollPhysics() : null,
              itemCount: 2,
              onPageChanged: (index) => setState(() {
                page = index;
                blocked = false;
              }),
              itemBuilder: (_, index) => MediaImageViewport(
                imageKey: index,
                active: index == page,
                onInteractionBlockedChanged: (value) {
                  if (index == page) setState(() => blocked = value);
                },
                child: const ColoredBox(color: Colors.blue),
              ),
            ),
          ),
        ),
      );
      await doubleTap(tester);
      await tester.drag(find.byType(PageView), const Offset(-600, 0));
      await tester.pumpAndSettle();
      expect(page, 0);
      await doubleTap(tester);
      await tester.drag(find.byType(PageView), const Offset(-600, 0));
      await tester.pumpAndSettle();
      expect(page, 1);
    },
  );
  testWidgets('adding a second finger cancels an unfinished dismissal', (
    tester,
  ) async {
    var dismissed = 0;
    await tester.pumpWidget(viewport(dismiss: () => dismissed++));
    final center = tester.getCenter(find.byType(InteractiveViewer));
    final first = await tester.createGesture(pointer: 4);
    final second = await tester.createGesture(pointer: 5);
    await first.down(center);
    await first.moveBy(const Offset(0, 120));
    await second.down(center + const Offset(20, 0));
    await first.up();
    await second.up();
    await tester.pumpAndSettle();
    expect(dismissed, 0);
  });

  testWidgets(
    'disposing a zoomed viewport leaves no callbacks or controller exceptions',
    (tester) async {
      await tester.pumpWidget(viewport());
      await doubleTap(tester);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );
}
