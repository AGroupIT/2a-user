import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twoalogisticcabineuser/src/features/payments/presentation/payment_qr_timing_warning.dart';

void main() {
  testWidgets('QR warning закрывается только кнопкой Я понял', (tester) async {
    const brandColor = Color(0xFF1677FF);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: brandColor,
          ).copyWith(primary: brandColor),
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showPaymentQrTimingWarning(context),
              child: const Text('Показать'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Показать'));
    await tester.pumpAndSettle();

    expect(find.text('Важно об оплате по QR'), findsOneWidget);
    expect(find.text('Я понял'), findsOneWidget);
    final dialog = tester.widget<Dialog>(find.byType(Dialog));
    expect(dialog.backgroundColor, Colors.white);
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.style?.backgroundColor?.resolve(<WidgetState>{}), brandColor);

    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.text('Важно об оплате по QR'), findsOneWidget);

    await tester.tap(find.text('Я понял'));
    await tester.pumpAndSettle();
    expect(find.text('Важно об оплате по QR'), findsNothing);
  });
}
