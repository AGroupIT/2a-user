import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:twoalogisticcabineuser/src/features/tracks/presentation/widgets/track_sheet_surface.dart';
import 'package:twoalogisticcabineuser/src/core/ui/sheet_handle.dart';
import 'package:twoalogisticcabineuser/src/features/tracks/domain/photo_report_options.dart';
import 'package:twoalogisticcabineuser/src/features/tracks/domain/track_item.dart';
import 'package:twoalogisticcabineuser/src/features/tracks/presentation/widgets/photo_report_selection_sheet.dart';
import 'package:twoalogisticcabineuser/src/features/tracks/presentation/widgets/photo_report_summary.dart';
import 'package:twoalogisticcabineuser/src/features/invoices/domain/invoice_item.dart';

void main() {
  PhotoReportOptions options({
    bool standard = true,
    bool custom = true,
    String price = '5.00',
  }) => PhotoReportOptions.fromJson({
    'standard': {'enabled': standard, 'priceUsd': '0.00'},
    'custom': {'enabled': custom, 'priceUsd': price},
  });
  Future<void> open(
    WidgetTester tester, {
    String locale = 'ru',
    PhotoReportOptions? value,
    String? initialType,
    String? savedPrice,
    bool allowTypeChange = true,
    void Function(PhotoReportSelection?)? result,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: Locale(locale),
          supportedLocales: const [Locale('ru'), Locale('zh')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  final selection =
                      await showModalBottomSheet<PhotoReportSelection>(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => PhotoReportSelectionSheet(
                          trackNumber: 'TEST-001',
                          initialType: initialType,
                          savedPriceUsd: savedPrice,
                          allowTypeChange: allowTypeChange,
                          initialWish: initialType == 'custom'
                              ? 'Check size'
                              : null,
                          loadOptions: () async => value ?? options(),
                        ),
                      );
                  result?.call(selection);
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  for (final width in [320.0, 393.0, 720.0]) {
    testWidgets('warehouse rules use the shared modal and fit at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await open(tester);
      expect(find.byType(TrackSheetSurface), findsOneWidget);
      expect(find.byType(SheetHandle), findsOneWidget);
      expect(find.text('Трек TEST-001'), findsOneWidget);
      for (final rule in [
        'Регламент склада',
        'Проверка целостности',
        'Проверка явного брака',
        'Замер стельки',
        'Фото товара с разных сторон',
      ]) {
        await tester.ensureVisible(find.text(rule));
        expect(find.text(rule), findsOneWidget);
      }
      final action = tester.getRect(find.byType(TrackSheetPrimaryButton));
      expect(action.top, greaterThan(0));
      expect(action.bottom, lessThanOrEqualTo(852));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Chinese warehouse rules are localized', (tester) async {
    await open(tester, locale: 'zh');
    for (final rule in ['仓库标准检查内容', '检查完整性', '检查明显瑕疵', '测量鞋垫长度', '从不同角度拍摄商品']) {
      expect(find.text(rule), findsOneWidget);
    }
    expect(find.text('Регламент склада'), findsNothing);
  });

  testWidgets('custom input and action remain reachable above the keyboard', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await open(tester);
    await tester.tap(find.text('Проверка по заданию'));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'Проверить размер');
    final action = tester.getRect(find.byType(TrackSheetPrimaryButton));
    expect(action.top, greaterThan(0));
    expect(action.bottom, lessThanOrEqualTo(500));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'standard has no wishes and sends the displayed zero-price selection',
    (tester) async {
      PhotoReportSelection? result;
      await open(tester, result: (value) => result = value);
      expect(find.byType(TextField), findsNothing);
      await tester.tap(find.text('Запросить фотоотчёт'));
      await tester.pumpAndSettle();
      expect(result?.reportType, 'standard');
      expect(result?.wish, isNull);
      expect(result?.expectedPriceUsd, '0.00');
    },
  );

  testWidgets('custom requires wishes even when free', (tester) async {
    PhotoReportSelection? result;
    await open(
      tester,
      value: options(price: '0.00'),
      result: (value) => result = value,
    );
    await tester.tap(find.text('Проверка по заданию'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Запросить фотоотчёт'));
    await tester.pumpAndSettle();
    expect(find.text('Напишите пожелания к проверке'), findsOneWidget);
    expect(result, isNull);
    await tester.enterText(find.byType(TextField), '  Проверить размер  ');
    await tester.ensureVisible(find.text('Запросить фотоотчёт'));
    await tester.tap(find.text('Запросить фотоотчёт'));
    await tester.pumpAndSettle();
    expect(result?.wish, 'Проверить размер');
    expect(result?.expectedPriceUsd, '0.00');
  });

  testWidgets(
    'paid custom requires explicit charge acceptance and clears acceptance on type change',
    (tester) async {
      tester.view.physicalSize = const Size(360, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await open(tester);
      await tester.tap(find.text('Проверка по заданию'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TrackSheetPrimaryButton>(
              find.byType(TrackSheetPrimaryButton),
            )
            .onTap,
        isNull,
      );
      await tester.ensureVisible(find.byType(CheckboxListTile));
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TrackSheetPrimaryButton>(
              find.byType(TrackSheetPrimaryButton),
            )
            .onTap,
        isNotNull,
      );
      await tester.ensureVisible(find.text('Стандартный фотоотчёт'));
      await tester.tap(find.text('Стандартный фотоотчёт'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Проверка по заданию'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TrackSheetPrimaryButton>(
              find.byType(TrackSheetPrimaryButton),
            )
            .onTap,
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('same-type edits retain saved price even after tariff changes', (
    tester,
  ) async {
    PhotoReportSelection? result;
    await open(
      tester,
      value: options(price: '9.00'),
      initialType: 'custom',
      savedPrice: '5.00',
      result: (value) => result = value,
    );
    expect(find.text('\$5.00'), findsOneWidget);
    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Сохранить'));
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    expect(result?.expectedPriceUsd, '5.00');
    expect(result?.wish, 'Check size');
  });

  testWidgets(
    'after arrival custom wishes can change but report type stays locked',
    (tester) async {
      PhotoReportSelection? result;
      await open(
        tester,
        initialType: 'custom',
        savedPrice: '0.00',
        allowTypeChange: false,
        result: (value) => result = value,
      );
      expect(find.text('Стандартный фотоотчёт'), findsNothing);
      expect(
        tester
            .widget<TrackSheetOptionTile>(find.byType(TrackSheetOptionTile))
            .onTap,
        isNull,
      );
      await tester.enterText(find.byType(TextField), 'New wishes');
      await tester.ensureVisible(find.text('Сохранить'));
      await tester.tap(find.text('Сохранить'));
      await tester.pumpAndSettle();
      expect(result?.reportType, 'custom');
      expect(result?.wish, 'New wishes');
      expect(result?.expectedPriceUsd, '0.00');
    },
  );

  testWidgets('Chinese narrow layout handles all disabled types', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await open(
      tester,
      locale: 'zh',
      value: options(standard: false, custom: false),
    );
    expect(find.text('目前无法申请拍照报告'), findsOneWidget);
    expect(
      tester
          .widget<TrackSheetPrimaryButton>(find.byType(TrackSheetPrimaryButton))
          .onTap,
      isNull,
    );
    expect(find.byType(TrackSheetOptionTile), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test(
    'snapshots report price and blocks editing once work starts or finishes',
    () {
      PhotoRequest request(Map<String, dynamic> fields) =>
          PhotoRequest.fromJson({
            'id': 7,
            'status': 'new',
            'reportType': 'custom',
            'priceUsd': '5.00',
            'wish': 'Размер',
            ...fields,
          });
      expect(request({}).canEditWish, isTrue);
      expect(request({'startedAt': '2026-10-23T00:00:00Z'}).canChange, isFalse);
      expect(request({'status': 'in_progress'}).canChange, isFalse);
      expect(request({'status': 'completed'}).canChange, isFalse);
      expect(request({'status': 'cancelled'}).canChange, isFalse);
      expect(PhotoRequest.fromJson({'id': 8}).reportType, 'legacy');
      expect(PhotoRequest.fromJson({'id': 8}).priceUsd, '0');
    },
  );

  test(
    'invoice parses fixed report charges without rewriting historical coefficient',
    () {
      final invoice = InvoiceItem.fromJson({
        'id': 1,
        'invoiceNumber': 'INV-1',
        'photoReportCoefficient': '1.20',
        'photoReportCostUsd': '10.00',
        'photoReportCharges': [
          {
            'id': 4,
            'photoRequestId': 7,
            'trackNumber': 'RETURNED-TRACK',
            'amountUsd': '5.00',
          },
          {
            'id': 5,
            'photoRequestId': 8,
            'trackNumber': 'TEST-002',
            'amountUsd': '5.00',
          },
        ],
      });
      expect(invoice.photoReportCostUsd, 10);
      expect(invoice.photoReportCharges.first.trackNumber, 'RETURNED-TRACK');
      expect(invoice.photoReportCharges.last.amountUsd, 5);
      expect(invoice.photoReportCoefficient, 1.2);
      expect(InvoiceItem.fromJson({'id': 2}).photoReportCostUsd, 0);
    },
  );

  testWidgets('report summary shows pending charge even for returned goods', (
    tester,
  ) async {
    final request = PhotoRequest.fromJson({
      'id': 1,
      'status': 'completed',
      'reportType': 'custom',
      'priceUsd': '5.00',
      'charge': {'amountUsd': '5.00', 'status': 'pending'},
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PhotoReportSummary(request: request)),
      ),
    );
    expect(find.text('Проверка по заданию · \$5.00'), findsOneWidget);
    expect(
      find.text('Будет включено в ближайший счёт на доставку'),
      findsOneWidget,
    );
  });
}
