import 'package:flutter_test/flutter_test.dart';
import 'package:twoalogisticcabineuser/src/features/shop/domain/purchase_list.dart';

void main() {
  test('purchase list parses 1688 order status, totals and logistics', () {
    final list = PurchaseList.fromJson({
      'id': 7,
      'status': 'processing',
      'totalItems': 2,
      'createdAt': '2026-07-23T00:00:00.000Z',
      'items': <dynamic>[],
      'marketplaceOrder': {
        'id': 11,
        'platform': '1688',
        'status': 'shipped',
        'totals': {'payable': '2400.50', 'freight': '25.00', 'currency': 'CNY'},
        'lastSyncedAt': '2026-07-23T10:00:00.000Z',
        'groups': [
          {
            'supplierName': 'Supplier',
            'status': 'created',
            'externalOrders': [
              {
                'externalOrderId': '90001',
                'status': 'shipped',
                'logistics': {
                  'shipments': [
                    {
                      'companyName': 'SF',
                      'trackingNumber': 'SF123',
                      'status': 'shipping',
                    },
                  ],
                },
              },
            ],
          },
        ],
      },
    });

    expect(list.marketplaceOrder, isNotNull);
    expect(list.marketplaceOrder!.statusDisplay, 'Отправлен');
    expect(list.marketplaceOrder!.payableCny, 2400.50);
    expect(
      list
          .marketplaceOrder!
          .groups
          .single
          .externalOrders
          .single
          .shipments
          .single
          .trackingNumber,
      'SF123',
    );
  });

  test('marketplace order preserves JD platform code', () {
    final order = MarketplaceOrderSummary.fromJson({
      'id': 12,
      'platform': 'jd',
      'status': 'previewed',
      'totals': {'payable': '99.90', 'freight': '0', 'currency': 'CNY'},
      'groups': <dynamic>[],
    });

    expect(order.platform, 'jd');
    expect(order.statusDisplay, 'Рассчитан');
  });
}
