import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:twoalogisticcabineuser/training_preview.dart';

// Explicit visual-review helper; not part of the regular test directory.
// TRAINING_RENDER_DIR=/absolute/output flutter test --no-pub tools/training/render_preview_test.dart
void main() {
  testWidgets('render training catalog and assembly instructions', (
    tester,
  ) async {
    final output = Platform.environment['TRAINING_RENDER_DIR'];
    expect(
      output,
      isNotNull,
      reason: 'Set TRAINING_RENDER_DIR for review artifacts',
    );
    final directory = Directory(output!);
    await tester.runAsync(() => directory.create(recursive: true));
    // This explicit flutter_test harness lives under tools, outside test/.
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final loader = FontLoader('Gilroy')
      ..addFont(rootBundle.load('assets/fonts/gilroy/Gilroy-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/gilroy/Gilroy-Bold.ttf'));
    await loader.load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    final boundaryKey = GlobalKey();
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundaryKey,
        child: TrainingPreviewApp(preferences: prefs),
      ),
    );
    await tester.pumpAndSettle();

    Future<void> capture(String name) async {
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final boundary =
            boundaryKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1);
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          '${directory.path}/$name.png',
        ).writeAsBytes(png!.buffer.asUint8List());
        image.dispose();
      });
    }

    Future<void> tap(String key) async {
      final finder = find.byKey(ValueKey(key));
      if (finder.evaluate().isEmpty) {
        await tester.scrollUntilVisible(
          finder,
          300,
          scrollable: find.byType(Scrollable).first,
        );
      }
      await tester.ensureVisible(finder);
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }

    await capture('01-catalog-mobile');
    tester.view.physicalSize = const Size(1024, 900);
    await tester.pumpAndSettle();
    await capture('02-catalog-desktop');
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();
    await tap('training-lesson-assembly');
    await capture('03-assembly-instructions');
    expect(find.byKey(const Key('training-practice')), findsNothing);
  });
}
