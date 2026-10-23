import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twoalogisticcabineuser/src/core/network/api_client.dart';
import 'package:twoalogisticcabineuser/src/features/invoices/domain/invoice_item.dart';
import 'package:twoalogisticcabineuser/src/features/invoices/presentation/invoices_screen.dart';
import 'package:twoalogisticcabineuser/src/features/payments/data/invoice_payment_options.dart';
import 'package:twoalogisticcabineuser/src/features/payments/presentation/invoice_payment_method_sheet.dart';
import 'package:twoalogisticcabineuser/src/features/tracks/presentation/widgets/track_sheet_surface.dart';

class _Api extends ApiClient {
  String? lastPath;
  dynamic lastData;
  bool locked = false;
  int selections = 0;
  bool failSelection = false;

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    lastPath = path;
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      statusCode: 200,
      data:
          {
                'data': {
                  'methods': [
                    for (final method in [
                      'bank_qr',
                      'usdt_trc20',
                      'alipay',
                      'manager',
                    ])
                      {
                        'code': method,
                        'currency': method == 'alipay' ? 'CNY' : 'RUB',
                        'available': true,
                      },
                  ],
                  'activeMethod': locked ? 'alipay' : null,
                  'canChange': !locked,
                  'lockedReason': locked ? 'payment_review' : null,
                },
              }
              as T,
    );
  }

  @override
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    selections++;
    lastPath = path;
    lastData = data;
    if (failSelection) {
      locked = true;
      throw StateError('locked concurrently');
    }
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      statusCode: 200,
      data:
          {
                'data': {
                  'method': data['method'],
                  'paymentId': 77,
                  'currency': 'USDT',
                  'amount': '123.45',
                  'qrImageUrl': '/uploads/qr.png',
                  'walletAddress': 'TWallet',
                  'network': 'TRC20',
                  'canChange': true,
                },
              }
              as T,
    );
  }
}

Future<void> _pump(
  WidgetTester tester,
  _Api api, {
  Locale locale = const Locale('ru'),
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        invoicePaymentOptionsServiceProvider.overrideWithValue(
          InvoicePaymentOptionsService(api),
        ),
      ],
      child: MaterialApp(
        locale: locale,
        supportedLocales: const [Locale('ru'), Locale('zh')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showModalBottomSheet<InvoicePaymentSelection>(
                context: context,
                isScrollControlled: true,
                builder: (_) =>
                    const InvoicePaymentMethodSheet(invoiceId: '12'),
              ),
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

void main() {
  test(
    'foreign invoice method persists and review/paid cannot reopen payment',
    () {
      for (final method in ['usdt_trc20', 'alipay']) {
        for (final status in [
          'unpaid',
          'processing',
          'payment_review',
          'paid',
          'cancelled',
        ]) {
          final item = InvoiceItem.fromJson({
            'id': 12,
            'invoiceNumber': 'INV-12',
            'status': status,
            'paymentMethod': method,
            'paymentProvider': 'manual',
          });
          expect(item.paymentMethod, method);
          expect(item.paymentProvider, 'manual');
          expect(
            canOpenInvoicePayment(item),
            status == 'unpaid' || status == 'processing',
          );
        }
      }
    },
  );

  test('service preserves invoice scope and foreign decimal amount', () async {
    final api = _Api();
    final service = InvoicePaymentOptionsService(api);
    final options = await service.fetch('12');
    expect(api.lastPath, '/client/invoices/12/payment-options');
    expect(options.methods.length, 4);
    final selection = await service.select('12', 'usdt_trc20');
    expect(api.lastPath, '/client/invoices/12/payment-method');
    expect(api.lastData, {'method': 'usdt_trc20'});
    expect(selection.amount, 123.45);
    expect(selection.paymentId, 77);
    expect(selection.currency, 'USDT');
  });

  test('foreign payment rejects missing credentials and invalid amount', () {
    for (final value in [null, 'NaN', '0', '-1']) {
      expect(
        () => InvoicePaymentSelection.fromJson({
          'method': 'usdt_trc20',
          'amount': value,
        }),
        throwsFormatException,
      );
    }
  });

  testWidgets('review locks all choices without selection requests', (
    tester,
  ) async {
    final api = _Api()..locked = true;
    await _pump(tester, api);
    expect(find.byType(TrackSheetOptionTile), findsNothing);
    expect(find.textContaining('Пока чек на проверке'), findsOneWidget);
    expect(api.selections, 0);
    expect(find.textContaining('Отозвать'), findsNothing);
  });

  testWidgets('four choices submit selected code and no legacy creation', (
    tester,
  ) async {
    final api = _Api();
    await _pump(tester, api);
    expect(find.byType(TrackSheetSurface), findsOneWidget);
    expect(find.byType(TrackSheetPrimaryButton), findsOneWidget);
    expect(find.byType(TrackSheetOptionTile), findsNWidgets(4));
    await tester.tap(find.text('Оплатить USDT · TRC20'));
    await tester.pumpAndSettle();
    expect(api.lastPath, '/client/invoices/12/payment-method');
    expect(api.lastData, {'method': 'usdt_trc20'});
    expect(api.selections, 1);
  });

  testWidgets('concurrent review refreshes lock after failed switch', (
    tester,
  ) async {
    final api = _Api()..failSelection = true;
    await _pump(tester, api);
    await tester.tap(find.text('Оплатить USDT · TRC20'));
    await tester.pumpAndSettle();
    expect(find.byType(TrackSheetOptionTile), findsNothing);
    expect(find.textContaining('Пока чек на проверке'), findsOneWidget);
    expect(api.selections, 1);
  });

  for (final locale in [const Locale('ru'), const Locale('zh')]) {
    for (final width in [280.0, 320.0, 390.0, 600.0]) {
      testWidgets('choices fit $width ${locale.languageCode} with large text', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 640);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 1.5;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await _pump(tester, _Api(), locale: locale);
        await tester.ensureVisible(find.byType(TrackSheetOptionTile).last);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final close = find.byType(TrackSheetPrimaryButton);
        expect(tester.getBottomRight(close).dy, lessThanOrEqualTo(640));
        expect(tester.getTopLeft(close).dy, greaterThan(0));
      });
    }
  }
}
