import 'package:flutter_test/flutter_test.dart';
import 'package:twoalogisticcabineuser/src/features/sp_finance/data/sp_organizer_customer_models.dart';

void main() {
  test('customer directory parses mixed values and full server metrics', () {
    final page = SpOrganizerCustomerPage.fromJson({
      'items': [
        {
          'id': '17',
          'fullName': '  Анна Петрова  ',
          'phone': '+7 900 000-00-00',
          'telegram': '@anna',
          'archivedAt': '2026-07-27T04:00:00.000Z',
          'metrics': {
            'purchasesCount': '3',
            'itemsCount': 7,
            'turnoverRub': '1234.50',
            'paidRub': 1000,
            'balanceRub': '234.5',
            'debtRub': 234.5,
            'profitRub': '180',
            'totalWeightKg': '2.75',
            'shipmentsCount': 2,
            'lastPurchase': {
              'id': 91,
              'title': 'Весенняя закупка',
              'status': 'completed',
              'kind': 'group',
              'createdAt': '2026-06-01T00:00:00.000Z',
            },
          },
        },
      ],
      'total': '31',
      'page': 2,
      'limit': '20',
      'totalPages': 2,
      'scope': 'archived',
      'sortBy': 'turnoverRub',
      'sortDirection': 'desc',
      'mode': 'read_only',
      'persisted': false,
    });

    expect(page.total, 31);
    expect(page.page, 2);
    expect(page.scope, 'archived');
    expect(page.sortBy, 'turnoverRub');
    expect(page.sortDirection, 'desc');
    expect(page.persisted, isFalse);
    expect(page.hasMore, isFalse);
    final customer = page.items.single;
    expect(customer.id, 17);
    expect(customer.fullName, 'Анна Петрова');
    expect(customer.isArchived, isTrue);
    expect(customer.compactContacts, ['+7 900 000-00-00', '@anna']);
    expect(customer.metrics.purchasesCount, 3);
    expect(customer.metrics.turnoverRub, 1234.5);
    expect(customer.metrics.debtRub, 234.5);
    expect(customer.metrics.totalWeightKg, 2.75);
    expect(customer.metrics.lastPurchase?.title, 'Весенняя закупка');
  });

  test('detail keeps customer ledger separate and merges history pages', () {
    Map<String, dynamic> response({
      required int page,
      required int purchaseId,
      required String title,
    }) {
      return {
        'customer': {'id': 7, 'fullName': 'Клиент'},
        'metrics': {
          'purchasesCount': 2,
          'turnoverRub': 290,
          'paidRub': 100,
          'balanceRub': 190,
          'debtRub': 190,
          'profitRub': 100,
        },
        'history': {
          'items': [
            {
              'id': purchaseId,
              'title': title,
              'status': 'collecting_payments',
              'kind': 'group',
              'metrics': {
                'itemsCount': 1,
                'turnoverRub': 145,
                'paidRub': 50,
                'balanceRub': 95,
              },
              'items': [
                {
                  'id': purchaseId * 10,
                  'title': 'Товар',
                  'status': 'purchased',
                  'quantity': '2',
                  'totalDueRub': '145',
                },
              ],
              'payments': [
                {
                  'id': purchaseId * 100,
                  'type': 'goods_payment',
                  'status': 'paid',
                  'amountRub': '50',
                },
              ],
              'shipments': [
                {
                  'id': purchaseId * 1000,
                  'carrierName': 'СДЭК',
                  'trackingNumber': 'TRACK-$purchaseId',
                  'status': 'sent',
                },
              ],
            },
          ],
          'total': 2,
          'page': page,
          'limit': 1,
          'totalPages': 2,
        },
        'mode': 'read_only',
        'persisted': false,
        'financialScope': 'organizer_customer_ledger',
      };
    }

    final first = SpOrganizerCustomerDetail.fromJson(
      response(page: 1, purchaseId: 10, title: 'Первая'),
    );
    final second = SpOrganizerCustomerDetail.fromJson(
      response(page: 2, purchaseId: 11, title: 'Вторая'),
    );
    final merged = first.mergePage(second);

    expect(first.financialScope, 'organizer_customer_ledger');
    expect(first.persisted, isFalse);
    expect(first.hasMore, isTrue);
    expect(merged.history.page, 2);
    expect(merged.hasMore, isFalse);
    expect(merged.history.items.map((purchase) => purchase.title), [
      'Первая',
      'Вторая',
    ]);
    expect(
      merged.history.items.first.shipments.single.trackingNumber,
      'TRACK-10',
    );
  });

  test('old or partial customer DTO safely defaults new fields', () {
    final customer = SpOrganizerCustomer.fromJson({
      'id': 3,
      'fullName': 'Legacy customer',
    });

    expect(customer.isArchived, isFalse);
    expect(customer.metrics.purchasesCount, 0);
    expect(customer.metrics.turnoverRub, 0);
    expect(customer.compactContacts, isEmpty);
  });
}
