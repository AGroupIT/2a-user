import 'package:flutter_test/flutter_test.dart';
import 'package:twoalogisticcabineuser/src/features/sp_finance/data/sp_organizer_models.dart';

void main() {
  group('SpOrganizerCapabilities backward-compatible parsing', () {
    test('отсутствующие поля выключают новые функции', () {
      final capabilities = SpOrganizerCapabilities.fromJson({});

      expect(capabilities.contractVersion, 1);
      expect(capabilities.organizerV2, isFalse);
      expect(capabilities.products, isFalse);
      expect(capabilities.purchaseBlankImport, isFalse);
      expect(capabilities.previousPurchaseImport, isFalse);
      expect(capabilities.participants, isFalse);
      expect(capabilities.fulfillmentOverview, isFalse);
      expect(capabilities.selfBuyoutLinks, isFalse);
      expect(capabilities.trackLinks, isFalse);
      expect(capabilities.trackImport, isFalse);
      expect(capabilities.analytics, isFalse);
      expect(capabilities.bulkOperations, isFalse);
      expect(capabilities.purchaseExport, isFalse);
      expect(capabilities.customersDirectory, isFalse);
      expect(capabilities.selfBuyout.available, isFalse);
      expect(capabilities.selfBuyout.canCreate, isFalse);
      expect(capabilities.hasOrganizerTools, isFalse);
    });

    test('серверный DTO включает только явно разрешённые возможности', () {
      final capabilities = SpOrganizerCapabilities.fromJson({
        'contractVersion': '2',
        'organizerV2': true,
        'purchaseKinds': true,
        'participants': true,
        'products': true,
        'purchaseBlankImport': true,
        'previousPurchaseImport': true,
        'calculationProfiles': true,
        'fulfillmentOverview': true,
        'selfBuyoutLinks': true,
        'selfBuyout': {
          'available': true,
          'canCreate': false,
          'reason': 'operator_sleeping',
        },
        'garageImport': true,
        'trackLinks': true,
        'trackImport': true,
        'assemblyLinks': true,
        'invoiceLinks': true,
        'analytics': true,
        'bulkOperations': true,
        'purchaseExport': true,
        'customersDirectory': true,
      });

      expect(capabilities.contractVersion, 2);
      expect(capabilities.hasOrganizerTools, isTrue);
      expect(capabilities.participants, isTrue);
      expect(capabilities.purchaseBlankImport, isTrue);
      expect(capabilities.previousPurchaseImport, isTrue);
      expect(capabilities.calculationProfiles, isTrue);
      expect(capabilities.fulfillmentOverview, isTrue);
      expect(capabilities.selfBuyoutLinks, isTrue);
      expect(capabilities.trackLinks, isTrue);
      expect(capabilities.trackImport, isTrue);
      expect(capabilities.analytics, isTrue);
      expect(capabilities.bulkOperations, isTrue);
      expect(capabilities.purchaseExport, isTrue);
      expect(capabilities.customersDirectory, isTrue);
      expect(capabilities.hasFulfillmentLinkActions, isTrue);
      expect(capabilities.selfBuyout.available, isTrue);
      expect(capabilities.selfBuyout.canCreate, isFalse);
      expect(capabilities.selfBuyout.reason, 'operator_sleeping');
      expect(capabilities.garageImport, isTrue);
    });
  });

  group('SpOrganizerProduct parsing', () {
    test('принимает смешанные числовые типы и архивное состояние', () {
      final page = SpOrganizerProductPage.fromJson({
        'items': [
          {
            'id': '7',
            'title': '  Куртка  ',
            'archivedAt': '2026-07-27T03:04:05.000Z',
            'primaryMedia': {
              'id': 8,
              'url': 'https://example.test/original.jpg',
              'thumbnailUrl': 'https://example.test/thumb.jpg',
            },
            'media': [
              {
                'id': '9',
                'url': 'https://example.test/second.jpg',
                'sortOrder': '2',
              },
            ],
            '_count': {'items': '12'},
          },
        ],
        'total': '41',
        'page': 2,
        'limit': '20',
        'totalPages': 3,
        'sortBy': 'itemsCount',
        'sortDirection': 'desc',
      });

      expect(page.total, 41);
      expect(page.hasMore, isTrue);
      expect(page.sortBy, 'itemsCount');
      expect(page.sortDirection, 'desc');
      expect(page.items, hasLength(1));

      final product = page.items.single;
      expect(product.id, 7);
      expect(product.title, 'Куртка');
      expect(product.isArchived, isTrue);
      expect(product.itemsCount, 12);
      expect(product.imageUrl, 'https://example.test/thumb.jpg');
      expect(product.media.single.sortOrder, 2);
    });

    test('input не отправляет пустые необязательные поля', () {
      const input = SpOrganizerProductInput(
        title: 'Товар',
        sourceUrl: '  ',
        barcode: '123',
        mediaUrls: ['https://example.test/item.jpg'],
      );

      expect(input.toJson(), {
        'title': 'Товар',
        'barcode': '123',
        'mediaUrls': ['https://example.test/item.jpg'],
      });
    });

    test('update явно очищает пустые редактируемые поля', () {
      const input = SpOrganizerProductInput(
        title: 'Товар',
        sourceUrl: '  ',
        marketplaceCode: '1688',
        barcode: '',
        description: null,
      );

      expect(input.toUpdateJson(), {
        'title': 'Товар',
        'sourceUrl': null,
        'marketplaceCode': '1688',
        'barcode': null,
        'description': null,
      });
    });

    test('update добавляет новое фото и QR без удаления старых media', () {
      const input = SpOrganizerProductInput(
        title: 'Товар',
        qrImageUrl: '/uploads/sp-v2/qr.png',
        mediaUrls: ['/uploads/sp-v2/main.jpg'],
      );

      expect(input.toUpdateJson(), {
        'title': 'Товар',
        'sourceUrl': null,
        'marketplaceCode': null,
        'barcode': null,
        'description': null,
        'qrImageUrl': '/uploads/sp-v2/qr.png',
        'mediaUrls': ['/uploads/sp-v2/main.jpg'],
      });
    });

    test('детальная карточка парсит серверную историю и агрегаты', () {
      final detail = SpOrganizerProductDetail.fromJson({
        'product': {
          'id': 7,
          'title': 'Куртка',
          '_count': {'items': 3},
        },
        'summary': {
          'itemsCount': '3',
          'purchasesCount': 2,
          'customersCount': '2',
          'totalQuantity': 5,
          'totalWeightKg': '1.25',
          'turnoverRub': '2500.50',
          'costRub': 1800,
          'profitRub': '700.50',
          'averageClientPriceRub': 500.1,
          'averageCostRub': '360',
        },
        'history': {
          'items': [
            {
              'id': 90,
              'title': 'Куртка XL',
              'quantity': '2',
              'status': 'purchased',
              'statusLabel': 'Выкуплен',
              'purchasePriceYuan': '30',
              'clientPriceYuan': 42,
              'purchaseRate': '12.5',
              'purchase': {
                'id': 11,
                'title': 'СП июль',
                'kind': 'group',
                'status': 'purchasing',
                'statusLabel': 'Выкуп',
                'currency': 'CNY',
                'purchaseRate': '12.7',
              },
              'customer': {
                'id': 15,
                'fullName': 'Иван Иванов',
                'displayName': 'Иван Иванов',
                'isOrganizerSelf': false,
              },
            },
          ],
          'total': '1',
          'page': 1,
          'limit': 20,
          'totalPages': 1,
        },
        'filterOptions': {
          'statuses': [
            {
              'code': 'purchased',
              'nameRu': 'Выкуплен',
              'nameZh': '已购买',
              'color': '#16A34A',
              'sortOrder': '40',
            },
          ],
        },
      });

      expect(detail.product.id, 7);
      expect(detail.summary.totalWeightKg, 1.25);
      expect(detail.summary.profitRub, 700.5);
      expect(detail.history.items, hasLength(1));
      expect(detail.history.items.single.purchase.purchaseRate, 12.7);
      expect(detail.history.items.single.customer.displayName, 'Иван Иванов');
      expect(detail.statusOptions.single.sortOrder, 40);
    });

    test('query сравнивается по всем серверным фильтрам', () {
      const initial = SpOrganizerProductDetailQuery(productId: 7);
      final filtered = initial.copyWith(
        query: 'Куртка',
        status: 'purchased',
        scope: 'active',
        page: 2,
      );

      expect(filtered, isNot(initial));
      expect(
        filtered,
        const SpOrganizerProductDetailQuery(
          productId: 7,
          query: 'Куртка',
          status: 'purchased',
          scope: 'active',
          page: 2,
        ),
      );
      expect(filtered.copyWith(status: null).status, isNull);
    });
  });

  test('legacy-участник сохраняет null id и пометку источника', () {
    final list = SpOrganizerParticipantList.fromJson({
      'source': 'explicit_and_legacy',
      'participants': [
        {
          'id': null,
          'spPurchaseId': '11',
          'spCustomerId': 15,
          'displayOrder': '3',
          'legacyDerived': true,
          'customer': {
            'id': 15,
            'fullName': 'Организатор',
            'displayName': 'Я',
            'isOrganizerSelf': true,
          },
        },
      ],
    });

    expect(list.source, 'explicit_and_legacy');
    expect(list.participants, hasLength(1));
    expect(list.participants.single.id, isNull);
    expect(list.participants.single.legacyDerived, isTrue);
    expect(list.participants.single.customer.displayName, 'Я');
    expect(list.participants.single.customer.isOrganizerSelf, isTrue);
  });
}
