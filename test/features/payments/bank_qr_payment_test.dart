import 'package:flutter_test/flutter_test.dart';
import 'package:twoalogisticcabineuser/src/features/payments/data/bank_qr_payment.dart';
import 'package:twoalogisticcabineuser/src/features/payments/domain/payment_model.dart';
import 'package:twoalogisticcabineuser/src/features/invoices/domain/invoice_item.dart';

void main() {
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
