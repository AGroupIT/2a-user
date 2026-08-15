import 'package:flutter_test/flutter_test.dart';
import 'package:twoalogisticcabineuser/src/features/sp_finance/data/sp_organizer_analytics_models.dart';

void main() {
  test('analytics parses mixed server values without changing formulas', () {
    final analytics = SpOrganizerAnalytics.fromJson({
      'contractVersion': '1',
      'mode': 'read_only',
      'persisted': false,
      'asOf': '2026-07-27T03:04:05.000Z',
      'filter': {
        'period': 'custom',
        'audience': 'client',
        'kind': 'group',
        'selfItemsAsPersonal': true,
        'dateFrom': '2026-01-01T00:00:00.000Z',
        'dateTo': '2026-02-28T23:59:59.999Z',
      },
      'summary': {
        'purchasesCount': '2',
        'customersCount': 3.0,
        'itemsCount': '4',
        'turnoverRub': '565,00',
        'paidRub': 160,
        'receivableRub': '405',
        'costRub': 435.0,
        'profitRub': '130',
        'totalWeightKg': '3.500',
        'averageDeliveryDays': '5.5',
      },
      'comparison': {
        'available': true,
        'previousPeriod': {'dateFrom': '2025-11-03', 'dateTo': '2025-12-31'},
        'previous': {
          'purchasesCount': 1,
          'customersCount': '2',
          'itemsCount': 2,
          'turnoverRub': '100',
          'profitRub': 20,
          'averagePurchaseRub': 100,
          'averageDeliveryDays': 7,
        },
        'changes': {
          'purchasesCount': '100',
          'customersCount': 50,
          'itemsCount': 100,
          'turnoverRub': '465',
          'profitRub': 550,
          'averagePurchaseRub': '182.5',
          'averageDeliveryDays': '-21.43',
        },
      },
      'integrations': {
        'buyoutLinkedItemsCount': '2',
        'buyoutLinkedItemsShare': '50',
        'trackLinkedItemsCount': 2,
        'trackLinkedItemsShare': 50.0,
        'fulfillmentPurchasesCount': '2',
        'fulfillmentPurchasesShare': '100',
        'invoiceLinkedPurchasesCount': 1,
        'invoiceLinkedPurchasesShare': 50,
      },
      'series': [
        {
          'month': '2026-01',
          'purchasesCount': '1',
          'turnoverRub': '225.5',
          'profitRub': '55',
        },
      ],
      'topPurchases': [
        {
          'id': '17',
          'title': '  Закупка января  ',
          'kind': 'group',
          'status': 'active',
          'createdAt': '2026-01-15T10:00:00.000Z',
          'itemsCount': '2',
          'customersCount': 2,
          'turnoverRub': '225.5',
          'paidRub': 100,
          'profitRub': '55',
          'has2aFulfillment': true,
        },
      ],
      'topCustomers': [
        {
          'id': '15',
          'fullName': '  Иван Иванов  ',
          'displayName': 'Иван Иванов',
          'purchasesCount': '2',
          'itemsCount': 3,
          'turnoverRub': '400',
          'paidRub': 300,
          'profitRub': '80',
        },
      ],
      'topProducts': [
        {
          'id': 7,
          'title': '  Куртка  ',
          'marketplaceCode': '1688',
          'purchasesCount': 2,
          'customersCount': '3',
          'quantity': '4',
          'turnoverRub': 500,
          'costRub': '350',
          'profitRub': '150',
        },
      ],
      'topMarketplaces': [
        {
          'code': '1688',
          'productsCount': '1',
          'purchasesCount': 2,
          'quantity': 4,
          'turnoverRub': '500',
          'profitRub': 150,
        },
      ],
      'formulas': {
        'turnoverRub': 'legacy_stats.totalDueRub',
        'profitRub': 'legacy_stats.totalProfitRub',
      },
      'warnings': ['period_uses_purchase_created_at'],
    });

    expect(analytics.mode, 'read_only');
    expect(analytics.persisted, isFalse);
    expect(analytics.filter.period, 'custom');
    expect(analytics.filter.audience, 'client');
    expect(analytics.filter.kind, 'group');
    expect(analytics.filter.selfItemsAsPersonal, isTrue);
    expect(analytics.summary.purchasesCount, 2);
    expect(analytics.summary.customersCount, 3);
    expect(analytics.summary.turnoverRub, 565);
    expect(analytics.summary.receivableRub, 405);
    expect(analytics.summary.profitRub, 130);
    expect(analytics.summary.totalWeightKg, 3.5);
    expect(analytics.summary.averageDeliveryDays, 5.5);
    expect(analytics.comparison.available, isTrue);
    expect(analytics.comparison.previousDateFrom, DateTime(2025, 11, 3));
    expect(analytics.comparison.previous?.turnoverRub, 100);
    expect(analytics.comparison.changes?.averageDeliveryDays, -21.43);
    expect(analytics.integrations.fulfillmentPurchasesShare, 100);
    expect(analytics.series.single.month, '2026-01');
    expect(analytics.topPurchases.single.id, 17);
    expect(analytics.topPurchases.single.title, 'Закупка января');
    expect(analytics.topPurchases.single.has2aFulfillment, isTrue);
    expect(analytics.topCustomers.single.displayName, 'Иван Иванов');
    expect(analytics.topProducts.single.title, 'Куртка');
    expect(analytics.topMarketplaces.single.code, '1688');
    expect(analytics.formulas['turnoverRub'], 'legacy_stats.totalDueRub');
    expect(analytics.warnings, ['period_uses_purchase_created_at']);
  });

  test('filter equality is stable for Riverpod family cache keys', () {
    final from = DateTime(2026, 1, 1);
    final to = DateTime(2026, 2, 28);
    final first = SpOrganizerAnalyticsFilter(
      period: 'custom',
      audience: 'client',
      kind: 'group',
      selfItemsAsPersonal: true,
      dateFrom: from,
      dateTo: to,
    );
    final same = SpOrganizerAnalyticsFilter(
      period: 'custom',
      audience: 'client',
      kind: 'group',
      selfItemsAsPersonal: true,
      dateFrom: from,
      dateTo: to,
    );

    expect(first, same);
    expect(first.hashCode, same.hashCode);
    expect(
      first.copyWith(period: '30d', clearDates: true),
      const SpOrganizerAnalyticsFilter(
        period: '30d',
        audience: 'client',
        kind: 'group',
        selfItemsAsPersonal: true,
      ),
    );
  });
}
