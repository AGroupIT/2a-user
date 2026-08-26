import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:twoalogisticcabineuser/src/features/invoices/domain/invoice_item.dart';
import 'package:twoalogisticcabineuser/src/features/profile/data/invoice_export_data.dart';

void main() {
  test('invoice export has the requested columns in the requested order', () {
    expect(invoiceExportHeaders, hasLength(18));
    expect(invoiceExportHeaders.first, 'Номер счёта');
    expect(invoiceExportHeaders[8], 'Тариф, USD/кг');
    expect(invoiceExportHeaders[13], 'Курс юаня, ₽/¥');
    expect(invoiceExportHeaders.sublist(15), [
      'Итоговая стоимость, ₽',
      'Итоговая стоимость, USD',
      'Итоговая стоимость, ¥',
    ]);
  });

  test(
    'invoice export uses client-facing financial values and invoice dates',
    () {
      final invoice = InvoiceItem(
        id: '1',
        invoiceNumber: '2A-01-DS-08-26-1',
        createdAt: DateTime.utc(2026, 8, 1),
        sendDate: DateTime.utc(2026, 8, 2),
        paidAt: DateTime.utc(2026, 8, 3),
        arrivalDate: DateTime.utc(2026, 8, 4),
        status: 'paid',
        placesCount: 2,
        density: 0,
        weight: 50,
        volume: 0.2,
        clientPricePerKg: 3.4,
        transshipmentCost: 12,
        insuranceCost: 5,
        insuranceCostClient: 7,
        packagingCostTotal: 9,
        shippingCost: 170,
        clientRubRate: 90,
        clientYuanRate: 12,
        totalCostRub: 17820,
        totalCostUsd: 198,
        totalCostCny: 2376,
      );

      final row = buildInvoiceExportRow(
        invoice,
        dateFormat: DateFormat('dd.MM.yyyy'),
      );

      expect(row, hasLength(invoiceExportHeaders.length));
      expect(row.sublist(0, 4), [
        '2A-01-DS-08-26-1',
        '01.08.2026',
        '03.08.2026',
        '04.08.2026',
      ]);
      expect(row[7], 250);
      expect(row[8], 3.4);
      expect(row[9], 12);
      expect(row[10], 7);
      expect(row[11], 9);
      expect(row[12], 170);
      expect(row[13], 7.5);
      expect(row[14], 90);
      expect(row.sublist(15), [17820, 198, 2376]);
    },
  );
}
