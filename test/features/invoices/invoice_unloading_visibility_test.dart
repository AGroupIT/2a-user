import 'package:flutter_test/flutter_test.dart';
import 'package:twoalogisticcabineuser/src/features/invoices/domain/invoice_item.dart';

void main() {
  test('клиентский invoice использует только клиентскую цену разгрузки', () {
    final invoice = InvoiceItem.fromJson({
      'id': 'unloading-1',
      'invoiceNumber': 'INV-UNLOADING-1',
      'status': 'unpaid',
      'placesCount': 1,
      'transshipmentCost': 24,
      'ourTransshipmentCost': 11.86,
      'unloadingSelfCostRub': 1100,
      'unloadingClientCostRub': 2289.6,
      'totalCostUSD': 124,
      'totalCostRUB': 11829.6,
    });

    expect(invoice.transshipmentCost, 24);
    expect(invoice.totalCostUsd, 124);
    expect(invoice.totalCostRub, 11829.6);
  });
}
