import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twoalogisticcabineuser/src/core/ui/blurred_modal_bottom_sheet.dart';

void main() {
  testWidgets('keeps bottom-sheet actions above Android system navigation', (
    tester,
  ) async {
    const systemNavigationInset = 48.0;
    const screenSize = Size(360, 800);

    tester.view.physicalSize = screenSize;
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(bottom: systemNavigationInset);
    tester.view.viewPadding = const FakeViewPadding(
      bottom: systemNavigationInset,
    );
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewPadding);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => showBlurredModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.white,
                  builder: (_) => const SizedBox(
                    height: 240,
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: SizedBox(
                        height: 48,
                        child: Text('Нижнее действие'),
                      ),
                    ),
                  ),
                ),
                child: const Text('Открыть'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Открыть'));
    await tester.pumpAndSettle();

    final actionBottom = tester.getBottomRight(find.text('Нижнее действие')).dy;
    expect(actionBottom, lessThanOrEqualTo(800 - systemNavigationInset));
    final modalSurface = find.byWidgetPredicate(
      (widget) =>
          widget is ColoredBox && widget.color == const Color(0xFFFFFFFF),
    );
    expect(modalSurface, findsWidgets);
    final roundedMobileSurface = find.byWidgetPredicate((widget) {
      if (widget is! ClipRRect) return false;
      final radius = widget.borderRadius;
      return radius is BorderRadius &&
          radius.topLeft == const Radius.circular(30) &&
          radius.topRight == const Radius.circular(30) &&
          radius.bottomLeft == Radius.zero &&
          radius.bottomRight == Radius.zero;
    });
    expect(roundedMobileSurface, findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
