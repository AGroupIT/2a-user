import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twoalogisticcabineuser/src/features/garage/domain/garage_models.dart';
import 'package:twoalogisticcabineuser/src/features/garage/presentation/garage_invoice_card.dart';
import 'package:twoalogisticcabineuser/src/features/garage/presentation/garage_order_detail_screen.dart';
import 'package:twoalogisticcabineuser/src/features/garage/presentation/garage_request_detail_screen.dart';
import 'package:twoalogisticcabineuser/src/features/invoices/domain/invoice_item.dart';
import 'package:twoalogisticcabineuser/src/features/invoices/presentation/invoices_screen.dart';
import 'package:twoalogisticcabineuser/src/features/payments/data/client_payment_summary.dart';
import 'package:twoalogisticcabineuser/src/features/payments/presentation/client_payment_summary_panel.dart';

void main() {
  group('exact client payment amounts', () {
    test('keeps one kopeck and large safe values without double rounding', () {
      expect(RubAmount.tryParse('0.01')?.kopecks, 1);
      expect(RubAmount.tryParse('0.01')?.decimal, '0.01');

      final large = RubAmount.tryParse('90071992547409.91');
      expect(large?.kopecks, 9007199254740991);
      expect(large?.decimal, '90071992547409.91');
    });

    testWidgets('summary panel renders exact RU and ZH amounts', (
      tester,
    ) async {
      final summary = ClientPaymentSummary.tryParse(_summary())!;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ClientPaymentSummaryPanel(summary: summary)),
        ),
      );
      expect(find.text('Частично оплачено'), findsOneWidget);
      expect(find.text('0.01 ₽'), findsOneWidget);

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Localizations.override(
              context: context,
              locale: const Locale('zh'),
              child: Scaffold(
                body: ClientPaymentSummaryPanel(summary: summary),
              ),
            ),
          ),
        ),
      );
      expect(find.text('部分付款'), findsOneWidget);
      expect(find.text('剩余金额'), findsOneWidget);
      expect(find.text('0.01 ₽'), findsOneWidget);
    });

    testWidgets(
      'terminal refunded summary is neutral and never asks for payment',
      (tester) async {
        final summary = ClientPaymentSummary.tryParse({
          ..._summary(state: 'refunded'),
          'creditedRub': '0.00',
          'remainingRub': '100.00',
        })!;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ClientPaymentSummaryPanel(
                summary: summary,
                terminalRefund: true,
              ),
            ),
          ),
        );

        expect(find.text('Оплата возвращена'), findsOneWidget);
        expect(find.text('Сумма счёта'), findsOneWidget);
        expect(find.text('100.00 ₽'), findsOneWidget);
        expect(find.text('Получено'), findsNothing);
        expect(find.text('Осталось'), findsNothing);
        expect(find.text('Переплата'), findsNothing);

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Localizations.override(
                context: context,
                locale: const Locale('zh'),
                child: Scaffold(
                  body: ClientPaymentSummaryPanel(
                    summary: summary,
                    terminalRefund: true,
                  ),
                ),
              ),
            ),
          ),
        );
        expect(find.text('款项已退回'), findsOneWidget);
        expect(find.text('账单金额'), findsOneWidget);
        expect(find.text('已收金额'), findsNothing);
        expect(find.text('剩余金额'), findsNothing);
      },
    );

    testWidgets('reopened refunded summary keeps remaining payment visible', (
      tester,
    ) async {
      final summary = ClientPaymentSummary.tryParse({
        ..._summary(state: 'refunded'),
        'creditedRub': '0.00',
        'remainingRub': '100.00',
      })!;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ClientPaymentSummaryPanel(summary: summary)),
        ),
      );

      expect(find.text('Оплата возвращена'), findsOneWidget);
      expect(find.text('К оплате'), findsOneWidget);
      expect(find.text('Получено'), findsOneWidget);
      expect(find.text('Осталось'), findsOneWidget);
      expect(find.text('Сумма счёта'), findsNothing);
    });

    test('missing or malformed DTO fails safely', () {
      expect(ClientPaymentSummary.tryParse(null), isNull);
      expect(ClientPaymentSummary.tryParse({'state': 'partial'}), isNull);

      final unknown = ClientPaymentSummary.tryParse(
        _summary(state: 'future_state'),
      );
      expect(unknown, isNotNull);
      expect(unknown!.isUnknown, isTrue);
      expect(unknown.isPartial, isFalse);
    });

    testWidgets(
      'accepted shortfall is paid, shows the waived amount and asks no top-up',
      (tester) async {
        final summary = ClientPaymentSummary.tryParse({
          ..._summary(state: 'paid'),
          'creditedRub': '99.25',
          'remainingRub': '0.00',
          'waivedShortfallRub': '0.75',
          'closureKind': 'shortfall_accepted',
          'shortfallAccepted': true,
        })!;

        expect(summary.hasAcceptedShortfall, isTrue);
        expect(summary.isPartial, isFalse);
        expect(summary.hasRemaining, isFalse);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: ClientPaymentSummaryPanel(summary: summary)),
          ),
        );
        expect(find.text('Оплачено'), findsOneWidget);
        expect(find.text('Недостача принята'), findsOneWidget);
        expect(find.text('0.75 ₽'), findsOneWidget);
        expect(find.textContaining('Доплачивать'), findsOneWidget);
      },
    );

    test('legacy summary defaults shortfall fields without changing state', () {
      final summary = ClientPaymentSummary.tryParse(_summary())!;
      expect(summary.waivedShortfallRub.kopecks, 0);
      expect(summary.closureKind, isNull);
      expect(summary.shortfallAccepted, isFalse);
      expect(summary.isPartial, isTrue);
    });

    test('active top-up requires exact RUB pending Bank QR contract', () {
      final topUp = ClientActiveTopUp.tryParse({
        'paymentId': 71,
        'amountRub': '0.01',
        'currency': 'RUB',
        'status': 'pending',
        'provider': 'bank_qr',
        'method': 'bank_qr',
      });

      expect(topUp?.amountRub.kopecks, 1);
      expect(topUp?.isPayableBankQr, isTrue);
      expect(
        ClientActiveTopUp.tryParse({
          'paymentId': 71,
          'amountRub': '0.01',
          'currency': 'RUB',
          'status': 'success',
          'provider': 'bank_qr',
          'method': 'bank_qr',
        })?.isPayableBankQr,
        isFalse,
      );
    });
  });

  group('Invoice and Garage compatibility/terminal guards', () {
    test('old DTOs without payment projection remain parseable', () {
      final invoice = InvoiceItem.fromJson(_invoiceJson());
      final garageInvoice = GarageInvoice.fromJson(_garageInvoiceJson());

      expect(invoice.paymentSummary, isNull);
      expect(invoice.activeTopUp, isNull);
      expect(garageInvoice.paymentSummary, isNull);
      expect(garageInvoice.activeTopUp, isNull);
    });

    test(
      'Invoice partial permits top-up only while domain remains payable',
      () {
        final partial = InvoiceItem.fromJson(
          _invoiceJson(status: 'processing', summary: _summary()),
        );
        final cancelled = InvoiceItem.fromJson(
          _invoiceJson(status: 'cancelled', summary: _summary()),
        );

        expect(canOpenInvoiceBankQr(partial), isTrue);
        expect(canOpenInvoiceBankQr(cancelled), isFalse);
      },
    );

    test(
      'Garage partial permits top-up only while every owner state is payable',
      () {
        final invoice = GarageInvoice.fromJson(
          _garageInvoiceJson(summary: _summary()),
        );
        final payable = GarageOrder.fromJson(
          _garageOrderJson(status: 'awaiting_payment'),
        );
        final cancelled = GarageOrder.fromJson(
          _garageOrderJson(status: 'cancelled'),
        );

        expect(canPayGarageOrder(payable, invoice), isTrue);
        expect(canPayGarageOrder(cancelled, invoice), isFalse);
        expect(
          canPayGarageRequestOrder(
            payable,
            invoice,
            requestStatus: 'cancelled',
          ),
          isFalse,
        );
      },
    );

    test(
      'Garage refundState distinguishes terminal refund from reopened target',
      () {
        final invoice = GarageInvoice.fromJson(
          _garageInvoiceJson(
            status: 'unpaid',
            summary: _summary(state: 'refunded'),
          ),
        );
        final terminal = GarageOrder.fromJson(
          _garageOrderJson(status: 'awaiting_payment', refundState: 'refunded'),
        );
        final reopened = GarageOrder.fromJson(
          _garageOrderJson(
            status: 'awaiting_payment',
            refundState: 'not_refunded',
          ),
        );

        expect(isTerminalGarageRefund(invoice, terminal), isTrue);
        expect(isTerminalGarageRefund(invoice, reopened), isFalse);
      },
    );
  });
}

Map<String, dynamic> _summary({String state = 'partial'}) => {
  'requiredRub': '100.00',
  'creditedRub': '99.99',
  'remainingRub': '0.01',
  'overpaidRub': '0.00',
  'state': state,
  'valuationAt': '2026-08-29T00:00:00.000Z',
  'lockedAt': null,
  'currencyRateId': 12,
  'ratePolicy': 'current_until_fully_paid',
};

Map<String, dynamic> _invoiceJson({
  String status = 'unpaid',
  Map<String, dynamic>? summary,
}) => {
  'id': '17',
  'invoiceNumber': 'INV-17',
  'status': status,
  'placesCount': 1,
  'density': 1,
  'weight': 1,
  'volume': 1,
  'totalCostRUB': '100.00',
  'paymentSummary': summary,
};

Map<String, dynamic> _garageInvoiceJson({
  String status = 'unpaid',
  Map<String, dynamic>? summary,
}) => {
  'id': 55,
  'invoiceNumber': 'GI-55',
  'orderId': 44,
  'status': status,
  'clientCnyRubRateSnapshot': '12.00',
  'totalCny': '8.33',
  'totalRub': '100.00',
  'paymentSummary': summary,
};

Map<String, dynamic> _garageOrderJson({
  required String status,
  String refundState = 'not_refunded',
}) => {
  'id': 44,
  'orderNumber': 'GO-44',
  'requestId': 11,
  'status': status,
  'refundState': refundState,
  'goodsTotalCny': '8.33',
  'chinaDeliveryTotalCny': '0',
  'serviceFeeTotalCny': '0',
  'totalCny': '8.33',
  'totalRub': '100.00',
  'items': const <Map<String, dynamic>>[],
};
