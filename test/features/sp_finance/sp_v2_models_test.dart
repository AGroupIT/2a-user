import 'package:flutter_test/flutter_test.dart';
import 'package:twoalogisticcabineuser/src/features/sp_finance/data/sp_v2_models.dart';

void main() {
  group('SpV2Purchase backward-compatible parsing', () {
    test('старый минимальный DTO сохраняет текущие defaults', () {
      final purchase = SpV2Purchase.fromJson({
        'id': '42',
        'title': '  Existing SP  ',
        'status': 'open',
      });

      expect(purchase.id, 42);
      expect(purchase.kind, 'group');
      expect(purchase.title, 'Existing SP');
      expect(purchase.status, 'open');
      expect(purchase.statusLabel, 'Принимает товары');
      expect(purchase.isAcceptingItems, isTrue);
      expect(purchase.currency, 'CNY');
      expect(purchase.purchaseRate, 0);
      expect(purchase.commissionMode, 'hidden_margin');
      expect(purchase.clientCardSections.showTariff, isTrue);
      expect(purchase.clientCardSections.showCustomPrice, isTrue);
      expect(purchase.clientCardSections.showFinance, isTrue);
      expect(purchase.clientCardSections.showDelivery, isTrue);
      expect(purchase.startedAt, isNull);
      expect(purchase.dispatchedFromChinaAt, isNull);
      expect(purchase.completedAt, isNull);
      expect(purchase.clientCode, isNull);
      expect(purchase.items, isEmpty);
      expect(purchase.expenses, isEmpty);
      expect(purchase.payments, isEmpty);
      expect(purchase.shipments, isEmpty);
      expect(purchase.stats.totalDueRub, 0);
      expect(purchase.stats.totalProfitRub, 0);
    });

    test('текущий detail DTO принимает Decimal-строки и вложенные связи', () {
      final purchase = SpV2Purchase.fromJson({
        'id': 7,
        'kind': 'individual',
        'title': 'Detailed SP',
        'status': 'purchasing',
        'statusLabel': 'Серверный этап',
        'isAcceptingItems': false,
        'currency': 'rub',
        'purchaseRate': '12,25',
        'commissionMode': 'fixed',
        'showClientTariff': false,
        'showClientCustomPrice': false,
        'showClientFinance': false,
        'showClientDelivery': false,
        'startedAt': '2026-07-20T12:00:00.000Z',
        'dispatchedFromChinaAt': '2026-07-24T12:00:00.000Z',
        'completedAt': '2026-07-27T12:00:00.000Z',
        'createdAt': '2026-07-27T01:02:03.000Z',
        'clientCode': {'id': '5', 'code': '2A-77'},
        'stats': {
          'customersCount': '2',
          'itemsCount': 1,
          'goodsDueRub': '560.50',
          'paidRub': '245',
          'totalProfitRub': '234,25',
        },
        'items': [
          {
            'id': '10',
            'spProductId': '21',
            'title': 'Item',
            'status': 'purchased',
            'quantity': '2',
            'purchasePriceYuan': '6,5',
            'costPriceRub': '60',
            'clientPriceRub': 100,
            'shippingCostRub': '30',
            'actualWeightKg': '1.500',
            'customer': {'id': 3, 'fullName': 'Participant'},
            'tracks': [
              {
                'track': {
                  'id': 8,
                  'trackNumber': 'TRACK-8',
                  'status': 'in_warehouse',
                },
              },
            ],
            'payments': [
              {
                'id': 11,
                'type': 'goods_payment',
                'status': 'paid',
                'amountRub': '200.00',
                'paidAt': '2026-07-27T02:03:04.000Z',
              },
            ],
          },
        ],
        'shipments': [
          {
            'id': 12,
            'spCustomerId': 3,
            'status': 'sent',
            'costRub': '450,75',
            'sentAt': '2026-07-27T03:04:05.000Z',
          },
        ],
      });

      expect(purchase.kind, 'individual');
      expect(purchase.statusLabel, 'Серверный этап');
      expect(purchase.isAcceptingItems, isFalse);
      expect(purchase.currency, 'RUB');
      expect(purchase.purchaseRate, 12.25);
      expect(purchase.clientCardSections.showTariff, isFalse);
      expect(purchase.clientCardSections.showCustomPrice, isFalse);
      expect(purchase.clientCardSections.showFinance, isFalse);
      expect(purchase.clientCardSections.showDelivery, isFalse);
      expect(purchase.startedAt, DateTime.parse('2026-07-20T12:00:00.000Z'));
      expect(
        purchase.dispatchedFromChinaAt,
        DateTime.parse('2026-07-24T12:00:00.000Z'),
      );
      expect(purchase.completedAt, DateTime.parse('2026-07-27T12:00:00.000Z'));
      expect(purchase.createdAt, DateTime.parse('2026-07-27T01:02:03.000Z'));
      expect(purchase.clientCode?.id, 5);
      expect(purchase.clientCode?.code, '2A-77');
      expect(purchase.stats.customersCount, 2);
      expect(purchase.stats.goodsDueRub, 560.5);
      expect(purchase.stats.paidRub, 245);
      expect(purchase.stats.totalProfitRub, 234.25);

      final item = purchase.items.single;
      expect(item.spProductId, 21);
      expect(item.statusLabel, 'Выкуплен');
      expect(item.quantity, 2);
      expect(item.purchasePriceForCurrency('CNY'), 6.5);
      expect(item.purchasePriceForCurrency('RUB'), 60);
      expect(item.clientPriceForCurrency('RUB'), 100);
      expect(item.actualWeightKg, 1.5);
      expect(item.customer?.fullName, 'Participant');
      expect(item.tracks.single.trackNumber, 'TRACK-8');
      expect(item.tracks.single.status, 'in_warehouse');
      expect(item.payments.single.isPaid, isTrue);
      expect(item.isPurchased, isTrue);
      expect(item.isGoodsPaid, isTrue);
      expect(item.isDeliveryPaid, isFalse);

      final shipment = purchase.shipments.single;
      expect(shipment.status, 'sent');
      expect(shipment.costRub, 450.75);
      expect(shipment.sentAt, DateTime.parse('2026-07-27T03:04:05.000Z'));
    });
  });

  group('SP purchase directory contract', () {
    test('enhanced query sends only server-supported directory parameters', () {
      final query = SpV2PurchaseDirectoryQuery(
        query: '  июль  ',
        status: 'purchasing',
        kind: 'group',
        scope: 'all',
        dateFrom: DateTime(2026, 7, 1),
        dateTo: DateTime(2026, 7, 31),
        sortBy: 'totalProfitRub',
        sortDirection: 'asc',
        page: 2,
        limit: 30,
      );

      expect(query.toQueryParameters(), {
        'page': 2,
        'limit': 30,
        'scope': 'all',
        'sortBy': 'totalProfitRub',
        'sortDirection': 'asc',
        'q': 'июль',
        'status': 'purchasing',
        'kind': 'group',
        'dateFrom': '2026-07-01',
        'dateTo': '2026-07-31',
      });
      expect(query.activeFilterCount, 5);
      expect(
        query.copyWith(status: null, kind: null).toQueryParameters(),
        isNot(containsPair('status', anything)),
      );
    });

    test(
      'legacy raw list remains readable when backend is not upgraded yet',
      () {
        final page = SpV2PurchaseDirectoryPage.fromResponse([
          {
            'id': 1,
            'title': 'Legacy purchase',
            'status': 'open',
            'stats': {'itemsCount': 2, 'totalDueRub': '350'},
          },
        ]);

        expect(page.usedLegacyResponse, isTrue);
        expect(page.purchases.single.kind, 'group');
        expect(page.pagination.total, 1);
        expect(page.pagination.hasNextPage, isFalse);
        expect(page.summary.activePurchasesCount, 1);
        expect(page.summary.itemsCount, 2);
        expect(page.summary.totalDueRub, 350);
        expect(page.statusOptions.first.code, 'draft');
        expect(page.purchases.single.directory.available, isFalse);
      },
    );

    test(
      'enhanced envelope keeps canonical server status order and totals',
      () {
        final page = SpV2PurchaseDirectoryPage.fromResponse({
          'data': [
            {
              'id': 7,
              'title': 'Server page',
              'status': 'purchasing',
              'stats': {'itemsCount': 4, 'totalProfitRub': '125.50'},
              'directory': {
                'createdAt': '2026-07-01T08:00:00.000Z',
                'updatedAt': '2026-07-02T08:00:00.000Z',
                'stageAt': '2026-07-02T08:00:00.000Z',
                'weightKg': '4.250',
                'weightSource': 'actual',
                'costRub': '875.50',
                'outstandingRub': '600',
                'profitRub': '125.50',
                'integrations': {
                  'selfBuyoutRequestsCount': 1,
                  'garageOrderItemsCount': 2,
                  'tracksCount': 3,
                  'photosCount': 4,
                  'photoRequestsCount': 1,
                  'assembliesCount': 2,
                  'invoicesCount': 1,
                  'connectedServicesCount': 7,
                },
              },
            },
          ],
          'pagination': {
            'page': 2,
            'limit': 20,
            'total': 41,
            'totalPages': 3,
            'hasNextPage': true,
            'hasPreviousPage': true,
          },
          'summary': {
            'purchasesCount': 41,
            'activePurchasesCount': 30,
            'itemsCount': 95,
            'totalDueRub': '145000.75',
            'totalProfitRub': '18250.25',
          },
          'filterOptions': {
            'statuses': [
              {'code': 'open', 'label': 'Сервер: открыта'},
              {'code': 'purchasing', 'label': 'Сервер: выкуп'},
            ],
          },
        });

        expect(page.usedLegacyResponse, isFalse);
        expect(page.pagination.page, 2);
        expect(page.pagination.total, 41);
        expect(page.pagination.hasNextPage, isTrue);
        expect(page.summary.itemsCount, 95);
        expect(page.summary.totalDueRub, 145000.75);
        expect(page.statusOptions.map((status) => status.code), [
          'open',
          'purchasing',
        ]);
        expect(page.statusOptions.last.label, 'Сервер: выкуп');
        expect(page.purchases.single.directory.available, isTrue);
        expect(page.purchases.single.directory.weightKg, 4.25);
        expect(page.purchases.single.directory.costRub, 875.5);
        expect(
          page.purchases.single.directory.integrations.connectedServicesCount,
          7,
        );
        expect(
          page.purchases.single.directory.integrations.photoRequestsCount,
          1,
        );
      },
    );
  });

  group('SP status and legacy fallbacks', () {
    test('известные статусы используют текущие подписи', () {
      expect(SpV2PurchaseStatusInfo.labelFor('completed'), 'Завершено');
      expect(SpV2ItemStatusInfo.labelFor('ready_to_ship'), 'Готов к отправке');
      expect(SpV2ShipmentStatusInfo.labelFor('delivered'), 'Доставлено');
    });

    test('неизвестный новый статус остаётся читаемым, а не ломает DTO', () {
      expect(
        SpV2PurchaseStatusInfo.labelFor('future_purchase_status'),
        'future_purchase_status',
      );
      expect(
        SpV2ItemStatusInfo.labelFor('future_item_status'),
        'future_item_status',
      );
      expect(
        SpV2ShipmentStatusInfo.labelFor('future_shipment_status'),
        'future_shipment_status',
      );
    });

    test('legacy manual expense сохраняет существующий UI fallback', () {
      expect(
        SpV2ExpenseAllocationInfo.labelFor('manual'),
        'Поровну между клиентами',
      );
    });
  });

  group('SP create DTO contract', () {
    test('покупка не отправляет пустые optional-поля', () {
      const input = CreateSpV2PurchaseInput(
        title: 'New SP',
        description: '   ',
        currency: 'CNY',
        purchaseRate: 12.5,
      );

      expect(input.toJson(), {
        'title': 'New SP',
        'currency': 'CNY',
        'purchaseRate': 12.5,
        'showClientTariff': true,
        'showClientCustomPrice': true,
        'showClientFinance': true,
        'showClientDelivery': true,
      });
    });

    test('kind отправляется только новым capability-aware клиентом', () {
      const legacyInput = CreateSpV2PurchaseInput(title: 'Legacy');
      const typedInput = CreateSpV2PurchaseInput(
        title: 'Personal',
        kind: 'personal',
      );

      expect(legacyInput.toJson().containsKey('kind'), isFalse);
      expect(typedInput.toJson()['kind'], 'personal');
    });

    test('статус и даты отправляются как календарные даты без потери дня', () {
      final input = CreateSpV2PurchaseInput(
        title: 'Delivered',
        status: 'completed',
        startedAt: DateTime(2026, 7, 20, 23, 59),
        dispatchedFromChinaAt: DateTime(2026, 7, 24, 8, 30),
        completedAt: DateTime(2026, 7, 27, 15),
      );

      expect(input.toJson(), {
        'title': 'Delivered',
        'status': 'completed',
        'currency': 'CNY',
        'startedAt': '2026-07-20',
        'dispatchedFromChinaAt': '2026-07-24',
        'completedAt': '2026-07-27',
        'showClientTariff': true,
        'showClientCustomPrice': true,
        'showClientFinance': true,
        'showClientDelivery': true,
      });
    });

    test(
      'разделы карточки клиента отправляются отдельными boolean-флагами',
      () {
        const input = CreateSpV2PurchaseInput(
          title: 'Private sections',
          clientCardSections: SpV2ClientCardSections(
            showTariff: false,
            showCustomPrice: true,
            showFinance: false,
            showDelivery: true,
          ),
        );

        expect(input.toJson(), containsPair('showClientTariff', false));
        expect(input.toJson(), containsPair('showClientCustomPrice', true));
        expect(input.toJson(), containsPair('showClientFinance', false));
        expect(input.toJson(), containsPair('showClientDelivery', true));
      },
    );

    test('RUB item сохраняет текущие имена price-полей', () {
      const input = CreateSpV2ItemInput(
        spCustomerId: 3,
        spProductId: 9,
        title: 'RUB item',
        quantity: 2,
        currency: 'RUB',
        purchasePrice: 60,
        clientPriceRub: 100,
        shippingCostRub: 30,
      );

      expect(input.toJson(), {
        'spCustomerId': 3,
        'spProductId': 9,
        'title': 'RUB item',
        'quantity': 2,
        'purchasePriceRub': 60.0,
        'clientPriceRub': 100.0,
        'shippingCostRub': 30.0,
      });
    });
  });

  test('atomic bulk item DTO keeps optimistic-lock timestamp and values', () {
    final updatedAt = DateTime.parse('2026-07-27T03:04:05.000Z');
    final update = SpV2BulkItemUpdate(
      id: 17,
      expectedUpdatedAt: updatedAt,
      clientPriceYuan: 12.5,
      totalDueRub: 325,
    );
    final result = SpV2BulkApplyResult.fromJson({
      'operation': 'client_price',
      'purchaseId': '7',
      'requestedCount': 2,
      'updatedCount': '2',
      'applied': true,
      'itemIds': ['17', 18, 0],
    });

    expect(update.toJson(), {
      'id': 17,
      'expectedUpdatedAt': '2026-07-27T03:04:05.000Z',
      'clientPriceYuan': 12.5,
      'totalDueRub': 325,
    });
    expect(result.purchaseId, 7);
    expect(result.updatedCount, 2);
    expect(result.applied, isTrue);
    expect(result.itemIds, [17, 18]);
  });

  test('bulk options keep server status order and owned move targets', () {
    final options = SpV2BulkOptions.fromJson({
      'purchaseId': '7',
      'maxItems': 500,
      'statuses': [
        {'code': 'purchased', 'nameRu': 'Выкуплен', 'sortOrder': 40},
        {'code': 'approved', 'nameRu': 'Подтверждён', 'sortOrder': 30},
      ],
      'customers': [
        {'id': 3, 'name': 'Клиент', 'isOrganizerSelf': false},
      ],
      'purchases': [
        {'id': 8, 'title': 'Следующая СП', 'status': 'open'},
      ],
    });

    expect(options.purchaseId, 7);
    expect(options.statuses.map((status) => status.code), [
      'approved',
      'purchased',
    ]);
    expect(options.customers.single.name, 'Клиент');
    expect(options.purchases.single.title, 'Следующая СП');
  });
}
