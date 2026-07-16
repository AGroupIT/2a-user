import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twoalogisticcabineuser/src/core/network/api_client.dart';
import 'package:twoalogisticcabineuser/src/features/payments/data/bank_qr_payment.dart';
import 'package:twoalogisticcabineuser/src/features/payments/domain/payment_model.dart';
import 'package:twoalogisticcabineuser/src/features/payments/presentation/bank_qr_payment_screen.dart';
import 'package:twoalogisticcabineuser/src/features/payments/presentation/payment_receipt_picker.dart';
import 'package:twoalogisticcabineuser/src/features/invoices/domain/invoice_item.dart';
import 'package:twoalogisticcabineuser/src/features/self_buyout/data/self_buyout_models.dart';
import 'package:twoalogisticcabineuser/src/features/self_buyout/data/self_buyout_service.dart';
import 'package:twoalogisticcabineuser/src/features/self_buyout/presentation/self_buyout_qr_sheet.dart';

import '../../helpers/pump_app.dart';

class _FakeBankQrPaymentService extends BankQrPaymentService {
  _FakeBankQrPaymentService() : super(ApiClient());

  int uploadCalls = 0;

  @override
  Future<BankQrPaymentResult?> startBankQrPayment(String invoiceId) async {
    return const BankQrPaymentResult(
      paymentId: 101,
      invoiceId: 1,
      invoiceNumber: 'QR-1',
      amountRub: 1000,
      sumKopecks: 100000,
      purpose: 'Оплата счёта QR-1',
      qrPayload: 'ST00012|Name=Test|Sum=100000|Purpose=QR-1',
      status: 'pending',
    );
  }

  @override
  Future<PaymentReceiptUploadResult?> uploadBankQrReceipt({
    required int paymentId,
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
  }) async {
    uploadCalls++;
    return const PaymentReceiptUploadResult(
      receiptId: 1,
      paymentId: 101,
      invoiceStatus: 'payment_review',
    );
  }
}

class _FakeSelfBuyoutService extends SelfBuyoutService {
  _FakeSelfBuyoutService() : super(ApiClient());

  int uploadCalls = 0;

  @override
  Future<SelfBuyoutPaymentInfo?> startBankQr(int requestId) async {
    return const SelfBuyoutPaymentInfo(
      paymentId: 202,
      status: 'pending',
      amountRub: 1150,
      sumKopecks: 115000,
      purpose: 'Оплата самовыкупа SB-1',
      qrPayload: 'ST00012|Name=Test|Sum=115000|Purpose=SB-1',
    );
  }

  @override
  Future<bool> uploadReceipt({
    required int paymentId,
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
  }) async {
    uploadCalls++;
    return true;
  }
}

Finder _paidButtonInkWell() {
  return find.ancestor(
    of: find.text('Я оплатил'),
    matching: find.byType(InkWell),
  );
}

void main() {
  group('Чек обязателен перед подтверждением оплаты', () {
    testWidgets('счёт: «Я оплатил» отключена без приложенного чека', (
      tester,
    ) async {
      final service = _FakeBankQrPaymentService();

      await tester.pumpApp(
        const BankQrPaymentSheet(invoiceId: '1', invoiceNumber: 'QR-1'),
        overrides: [bankQrPaymentServiceProvider.overrideWithValue(service)],
      );
      await tester.pumpAndSettle();

      expect(find.text('Я оплатил'), findsOneWidget);
      expect(tester.widget<InkWell>(_paidButtonInkWell()).onTap, isNull);
      expect(service.uploadCalls, 0);
    });

    testWidgets('самовыкуп: «Я оплатил» отключена без приложенного чека', (
      tester,
    ) async {
      final service = _FakeSelfBuyoutService();

      await tester.pumpApp(
        const SelfBuyoutQrSheet(
          requestId: 1,
          requestNumber: 'SB-1',
          cnyAmount: 100,
        ),
        overrides: [selfBuyoutServiceProvider.overrideWithValue(service)],
      );
      await tester.pumpAndSettle();

      expect(find.text('Я оплатил'), findsOneWidget);
      expect(tester.widget<InkWell>(_paidButtonInkWell()).onTap, isNull);
      expect(service.uploadCalls, 0);
    });

    testWidgets('выбор чека предлагает галерею и файлы', (tester) async {
      final service = _FakeBankQrPaymentService();

      await tester.pumpApp(
        const BankQrPaymentSheet(invoiceId: '1', invoiceNumber: 'QR-1'),
        overrides: [bankQrPaymentServiceProvider.overrideWithValue(service)],
      );
      await tester.pumpAndSettle();

      final attachButton = find.text('Приложить чек (фото/PDF)');
      await tester.ensureVisible(attachButton);
      await tester.pumpAndSettle();
      await tester.tap(attachButton);
      await tester.pumpAndSettle();

      expect(find.text('Приложить чек'), findsOneWidget);
      expect(find.text('Галерея'), findsOneWidget);
      expect(find.text('Файлы'), findsOneWidget);
    });
  });

  group('Форматы чеков', () {
    test('определяет расширение без ложного значения у имени без точки', () {
      expect(paymentReceiptExtension('receipt.PDF'), 'pdf');
      expect(paymentReceiptExtension('receipt'), isNull);
      expect(
        paymentReceiptExtension('receipt', explicitExtension: 'JPG'),
        'jpg',
      );
    });

    test('возвращает корректные MIME-типы', () {
      expect(paymentReceiptMimeType('jpeg'), 'image/jpeg');
      expect(paymentReceiptMimeType('heic'), 'image/heic');
      expect(paymentReceiptMimeType('pdf'), 'application/pdf');
    });
  });

  group('BankQrPaymentResult.fromJson', () {
    test('парсит полный ответ start', () {
      final r = BankQrPaymentResult.fromJson({
        'paymentId': 123,
        'invoiceId': 2675,
        'invoiceNumber': '2A-1080-DS-06-18-1',
        'amountRub': 3752.0,
        'sumKopecks': 375200,
        'purpose': 'Оплата...',
        'qrPayload': 'ST00012|Name=...|Sum=375200|Purpose=...',
        'status': 'pending',
        'reused': false,
      });
      expect(r.paymentId, 123);
      expect(r.sumKopecks, 375200);
      expect(r.qrPayload.startsWith('ST00012|'), isTrue);
      expect(r.reused, isFalse);
    });
  });

  group('PaymentReceiptUploadResult.fromJson', () {
    test('парсит ответ receipt', () {
      final r = PaymentReceiptUploadResult.fromJson({
        'receiptId': 55,
        'paymentId': 123,
        'invoiceStatus': 'payment_review',
      });
      expect(r.receiptId, 55);
      expect(r.invoiceStatus, 'payment_review');
    });
  });

  group('PaymentProvider/Method.bankQr', () {
    test('fromString bank_qr', () {
      expect(PaymentProvider.fromString('bank_qr'), PaymentProvider.bankQr);
      expect(PaymentMethod.fromString('bank_qr'), PaymentMethod.bankQr);
    });
  });

  group('InvoiceItem bank-qr поля', () {
    test('fromJson читает bankQrPaymentAvailable + bankQrPaymentId', () {
      final inv = InvoiceItem.fromJson({
        'id': '1',
        'invoiceNumber': 'QR-1',
        'status': 'unpaid',
        'placesCount': 1,
        'totalCostRub': 3752,
        'bankQrPaymentAvailable': true,
        'bankQrPaymentId': 123,
        'paymentProvider': 'bank_qr',
        'paymentMethod': 'bank_qr',
      });
      expect(inv.bankQrPaymentAvailable, isTrue);
      expect(inv.bankQrPaymentId, 123);
      expect(inv.paymentProvider, 'bank_qr');
    });

    test('по умолчанию bankQrPaymentAvailable=false', () {
      final inv = InvoiceItem.fromJson({
        'id': '2',
        'invoiceNumber': 'QR-2',
        'status': 'unpaid',
        'placesCount': 1,
        'totalCostRub': 100,
      });
      expect(inv.bankQrPaymentAvailable, isFalse);
      expect(inv.bankQrPaymentId, isNull);
    });
  });
}
