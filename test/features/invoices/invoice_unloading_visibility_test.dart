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

  test('сопоставляет физические данные коробки по номеру счёта', () {
    final invoice = InvoiceItem.fromJson({
      'id': 10,
      'invoiceNumber': '2A-01-DS-06-23-2',
      'status': 'paid',
      'placesCount': 1,
      'totalCostRUB': 1000,
      'assembly': {
        'boxes': [
          {
            'id': 101,
            'number': 1,
            'height': 10,
            'width': 20,
            'length': 30,
            'weight': 4,
            'scalePhotos': [],
          },
          {
            'id': 102,
            'number': 2,
            'height': 40,
            'width': 50,
            'length': 60,
            'weight': 12,
            'scalePhotos': [
              {'id': 1, 'url': '/box-2.jpg'},
            ],
          },
        ],
      },
    });

    expect(invoice.boxes, hasLength(1));
    expect(invoice.boxes.single.number, 2);
    expect(invoice.boxes.single.weight, 12);
    expect(invoice.boxes.single.dimensionsDisplay, '40×50×60 см');
    expect(invoice.scalePhotoUrls, ['/box-2.jpg']);
  });
}
