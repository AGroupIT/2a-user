import 'package:flutter_test/flutter_test.dart';
import 'package:twoalogisticcabineuser/src/features/sp_finance/data/sp_organizer_fulfillment_models.dart';

void main() {
  test('read-only fulfillment DTO keeps core domains separate', () {
    final overview = SpOrganizerFulfillmentOverview.fromJson({
      'contractVersion': 1,
      'mode': 'read_only',
      'persisted': false,
      'purchaseId': '17',
      'items': [
        {'id': 5, 'title': 'Куртка'},
        {'id': '6', 'title': 'Брюки'},
      ],
      'summary': {
        'itemsCount': 2,
        'selfBuyoutRequestsCount': 1,
        'garageOrderItemsCount': 1,
        'tracksCount': 1,
        'photosCount': 3,
        'photoRequestsCount': 1,
        'assembliesCount': 1,
        'invoicesCount': 1,
      },
      'selfBuyoutRequests': [
        {
          'itemId': 5,
          'itemTitle': 'Куртка',
          'request': {
            'id': 8,
            'requestNumber': 'SB-001',
            'status': {
              'code': 'new',
              'nameRu': 'Новая',
              'nameZh': '新建',
              'sortOrder': '10',
            },
          },
        },
      ],
      'tracks': [
        {
          'itemId': 5,
          'itemTitle': 'Куртка',
          'source': 'garage_product_info',
          'track': {
            'id': '12',
            'trackNumber': 'TRACK-001',
            'photosCount': '3',
            'photos': [
              {
                'id': '31',
                'url': '/uploads/sp-e13/photo.jpg',
                'createdAt': '2026-07-27T08:00:00.000Z',
              },
            ],
            'photoRequestsCount': 1,
            'status': {
              'code': 'in_warehouse',
              'nameRu': 'На складе',
              'nameZh': '已入库',
              'sortOrder': 20,
            },
            'warehouseDelivery': {'isDelivered': true},
          },
        },
      ],
      'invoices': [
        {
          'id': 21,
          'invoiceNumber': 'INV-001',
          'source': 'assembly',
          'totalCostRUB': '1250.50',
          'totalCostCNY': 96,
          'status': {'code': 'unpaid', 'nameRu': 'Не оплачен'},
        },
      ],
      'warnings': ['read_only_overview'],
    });

    expect(overview.persisted, isFalse);
    expect(overview.items, hasLength(2));
    expect(overview.items.first.title, 'Куртка');
    expect(overview.summary.hasLinks, isTrue);
    expect(overview.summary.photosCount, 3);
    expect(overview.selfBuyoutRequests.single.requestNumber, 'SB-001');
    expect(overview.tracks.single.warehouseDelivered, isTrue);
    expect(overview.tracks.single.isAutomaticGarageTrack, isTrue);
    expect(overview.tracks.single.photos.single.id, 31);
    expect(
      overview.tracks.single.photos.single.url,
      '/uploads/sp-e13/photo.jpg',
    );
    expect(
      overview.tracks.single.photos.single.createdAt,
      DateTime.parse('2026-07-27T08:00:00.000Z'),
    );
    expect(overview.tracks.single.status.labelFor('zh'), '已入库');
    expect(overview.invoices.single.totalCostRub, 1250.5);
    expect(overview.warnings, contains('read_only_overview'));
  });

  test('link candidates keep server status and pagination metadata', () {
    final page = SpOrganizerFulfillmentCandidatePage.fromJson({
      'kind': 'assembly',
      'candidates': [
        {
          'id': '31',
          'title': 'ASM-031',
          'subtitle': 'Основная · 4 треков',
          'linked': false,
          'legacyLinked': true,
          'amountRub': null,
          'amountCny': null,
          'status': {
            'code': 'packed',
            'nameRu': 'Упакована',
            'nameZh': '已打包',
            'color': '#239B63',
            'sortOrder': '20',
          },
        },
      ],
      'pagination': {'total': '21', 'page': 1, 'limit': '20', 'totalPages': 2},
    });

    expect(page.kind, SpOrganizerFulfillmentLinkKind.assembly);
    expect(page.hasMore, isTrue);
    expect(page.candidates.single.legacyLinked, isTrue);
    expect(page.candidates.single.status.sortOrder, 20);
    expect(page.candidates.single.status.labelFor('zh'), '已打包');
  });
}
