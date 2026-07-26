import 'package:flutter_test/flutter_test.dart';
import 'package:twoalogisticcabineuser/src/features/garage/domain/garage_models.dart';

void main() {
  test('availability parses optional processor and VIN readiness', () {
    final availability = GarageAvailability.fromJson({
      'available': true,
      'reason': null,
      'processorAgentId': '42',
      'vinLookupConfigured': true,
    });

    expect(availability.available, isTrue);
    expect(availability.processorAgentId, 42);
    expect(availability.vinLookupConfigured, isTrue);
  });

  test('vehicle input normalizes VIN and trims optional values', () {
    const input = GarageVehicleInput(
      vin: '  jtdkn3du0d1234567 ',
      make: ' Toyota ',
      model: ' Prius ',
      modelYear: 2013,
      nickname: '  Семейная ',
      comment: '   ',
    );

    expect(input.toJson(), {
      'vin': 'JTDKN3DU0D1234567',
      'make': 'Toyota',
      'model': 'Prius',
      'modelYear': 2013,
      'nickname': 'Семейная',
      'generation': null,
      'trim': null,
      'bodyType': null,
      'engineCode': null,
      'engineVolume': null,
      'fuelType': null,
      'transmission': null,
      'driveType': null,
      'comment': null,
    });
  });

  test('request preserves backend status and exposes immutable item list', () {
    final request = GarageRequest.fromJson({
      'id': '11',
      'requestNumber': 'GAR-A-01',
      'vehicleId': 7,
      'status': 'needs_clarification',
      'needsEmployeeResponse': false,
      'needsClientResponse': true,
      'vehicleSnapshot': {'make': 'Toyota'},
      'statusHistory': [
        {
          'id': 501,
          'eventType': 'created',
          'previousStatus': null,
          'status': 'draft',
          'changedAt': '2026-07-23T08:00:00.000Z',
        },
        {
          'id': 502,
          'eventType': 'submitted',
          'oldStatus': 'draft',
          'newStatus': 'new',
          'createdAt': '2026-07-23T09:00:00.000Z',
        },
      ],
      'items': [
        {
          'id': 101,
          'requestId': 11,
          'orderNumber': 1,
          'partName': 'Колодки',
          'partNumber': '04465-33480',
          'preference': 'original',
          'existUrl': 'https://exist.ru/item',
          'quantity': 2,
          'isOptional': false,
        },
      ],
    });

    expect(request.id, 11);
    expect(request.status, 'needs_clarification');
    expect(request.needsClientResponse, isTrue);
    expect(request.statusHistory, hasLength(2));
    expect(request.statusHistory.last.previousStatus, 'draft');
    expect(request.statusHistory.last.status, 'new');
    expect(
      request.statusHistory.last.changedAt,
      DateTime.parse('2026-07-23T09:00:00.000Z'),
    );
    expect(request.items.single.preference, GaragePartPreference.original);
    expect(
      () => request.statusHistory.add(request.statusHistory.first),
      throwsUnsupportedError,
    );
    expect(
      () => request.items.add(request.items.single),
      throwsUnsupportedError,
    );
    expect(
      () => request.vehicleSnapshot!['make'] = 'Honda',
      throwsUnsupportedError,
    );
  });

  test('Garage request statuses normalize legacy and payment states', () {
    expect(canonicalGarageRequestStatus('submitted'), 'new');
    expect(canonicalGarageRequestStatus('in_review'), 'in_progress');
    expect(canonicalGarageRequestStatus('offer_ready'), 'pending_confirmation');
    expect(canonicalGarageRequestStatus('converted_to_order'), 'unpaid');

    final order = GarageOrder.fromJson({
      'id': 44,
      'orderNumber': 'GO-A-01',
      'requestId': 11,
      'status': 'payment_review',
      'totalCny': '100',
      'totalRub': '12500',
      'invoice': {
        'id': 55,
        'invoiceNumber': 'GI-A-01',
        'orderId': 44,
        'status': 'payment_review',
        'totalCny': '100',
        'totalRub': '12500',
      },
    });
    expect(
      canonicalGarageRequestStatus('unpaid', order: order),
      'payment_review',
    );
  });

  test('Garage message parses image and file attachments', () {
    final message = GarageRequestMessage.fromJson({
      'id': 71,
      'requestId': 11,
      'senderType': 'employee',
      'senderName': 'Менеджер',
      'messageType': 'comment',
      'content': '',
      'attachments': [
        {
          'id': 81,
          'fileName': 'detail.jpg',
          'fileType': 'image/jpeg',
          'fileSize': 2048,
          'url': '/uploads/garage/chat/detail.jpg',
        },
        {
          'id': 82,
          'fileName': 'specification.pdf',
          'fileType': 'application/pdf',
          'fileSize': 4096,
          'url': '/uploads/garage/chat/specification.pdf',
        },
      ],
    });

    expect(message.attachments, hasLength(2));
    expect(message.attachments.first.isImage, isTrue);
    expect(message.attachments.last.fileName, 'specification.pdf');
  });

  test('VIN result keeps provider data and marks partial response', () {
    final result = GarageVinLookupResult.fromJson({
      'vin': 'jtdkn3du0d1234567',
      'make': 'Toyota',
      'normalizedData': {'source': 'api-ninjas'},
    });

    expect(result.vinNormalized, 'JTDKN3DU0D1234567');
    expect(result.normalizedData['source'], 'api-ninjas');
    expect(result.isPartial, isTrue);
  });

  test('offer calculation parses list selections and nested totals', () {
    final calculation = GarageOfferCalculation.fromJson({
      'offerId': 88,
      'selections': [
        {'requestItemId': 101, 'optionId': 501, 'quantity': 2},
        {'requestItemId': 101, 'optionId': 502, 'quantity': 3},
      ],
      'totals': {
        'goodsTotalCny': '100.20',
        'chinaDeliveryTotalCny': '15',
        'serviceFeeTotalCny': '7.50',
        'discountCny': '2',
        'totalCny': '120.70',
        'totalRub': '15087.50',
        'clientCnyRubRateSnapshot': '125',
      },
    });

    expect(calculation.offerId, 88);
    expect(
      calculation.selections.map(
        (selection) =>
            (selection.requestItemId, selection.optionId, selection.quantity),
      ),
      [(101, 501, 2), (101, 502, 3)],
    );
    expect(calculation.totalCny, 120.7);
    expect(calculation.totalRub, 15087.5);
    expect(calculation.cnyRubRate, 125);
  });

  test('request parses current offer options and linked order', () {
    final request = GarageRequest.fromJson({
      'id': 11,
      'requestNumber': 'GAR-A-01',
      'vehicleId': 7,
      'status': 'offer_ready',
      'items': [
        {
          'id': 101,
          'requestId': 11,
          'orderNumber': 1,
          'partName': 'Колодки',
          'partNumber': '04465',
          'preference': 'any',
          'existUrl': 'https://exist.ru/item',
          'quantity': 1,
        },
      ],
      'currentOffer': {
        'id': 88,
        'requestId': 11,
        'version': 2,
        'status': 'published',
        'options': [
          {
            'id': 501,
            'offerId': 88,
            'requestItemId': 101,
            'manufacturer': '丰田',
            'manufacturerRu': 'Toyota',
            'partNumber': '04465',
            'optionType': 'original',
            'imageUrl': '/uploads/garage-options/brakes.jpg',
            'imageUrls': [
              '/uploads/garage-options/brakes.jpg',
              '/uploads/garage-options/brakes-side.jpg',
            ],
            'description': '原厂刹车片',
            'descriptionRu': 'Оригинальные тормозные колодки',
            'employeeComment': '推荐',
            'employeeCommentRu': 'Рекомендуем',
            'availabilityStatus': 'available',
            'clientUnitPriceCny': '100',
            'clientUnitPriceRub': '1250',
          },
        ],
      },
      'order': {
        'id': 44,
        'orderNumber': 'GO-A-01',
        'requestId': 11,
        'status': 'awaiting_payment',
        'totalCny': '100',
        'totalRub': '12500',
      },
    });

    expect(request.items.single.preference, GaragePartPreference.any);
    expect(request.currentOffer!.optionsFor(101).single.id, 501);
    expect(
      request.currentOffer!.optionsFor(101).single.imageUrl,
      '/uploads/garage-options/brakes.jpg',
    );
    expect(request.currentOffer!.optionsFor(101).single.imageUrls, [
      '/uploads/garage-options/brakes.jpg',
      '/uploads/garage-options/brakes-side.jpg',
    ]);
    expect(
      request.currentOffer!.optionsFor(101).single.clientUnitPriceRub,
      1250,
    );
    expect(
      request.currentOffer!.optionsFor(101).single.displayManufacturer,
      'Toyota',
    );
    expect(
      request.currentOffer!.optionsFor(101).single.displayDescription,
      'Оригинальные тормозные колодки',
    );
    expect(
      request.currentOffer!.optionsFor(101).single.displayEmployeeComment,
      'Рекомендуем',
    );
    expect(request.order!.orderNumber, 'GO-A-01');
  });

  test(
    'order item keeps nested selected option and normalizes empty refund state',
    () {
      final order = GarageOrder.fromJson({
        'id': 44,
        'orderNumber': 'GO-A-01',
        'requestId': 11,
        'status': 'paid',
        'refundState': 'none',
        'items': [
          {
            'id': 601,
            'orderId': 44,
            'requestItemId': 101,
            'partName': 'Тормозные колодки',
            'quantity': 2,
            'clientUnitPriceCny': '100',
            'clientUnitPriceRub': '1250',
            'lineTotalCny': '200',
            'lineTotalRub': '2500',
            'purchaseStatus': 'purchased',
            'supplierOrderNumber': 'SUP-44',
            'purchasedAt': '2026-07-25T09:30:00.000Z',
            'selectedOption': {
              'id': 501,
              'manufacturer': '丰田',
              'manufacturerRu': 'Toyota',
              'partNumber': '04465-33480',
              'optionType': 'original',
              'imageUrl': '/uploads/garage-options/brakes.jpg',
              'imageUrls': [
                '/uploads/garage-options/brakes.jpg',
                '/uploads/garage-options/brakes-side.jpg',
              ],
              'description': '原厂刹车片',
              'descriptionRu': 'Оригинальные тормозные колодки',
            },
          },
        ],
      });

      expect(order.refundState, 'not_refunded');
      expect(order.items, hasLength(1));
      expect(order.items.single.selectedOptionId, 501);
      expect(order.items.single.purchaseStatus, 'purchased');
      expect(order.items.single.supplierOrderNumber, 'SUP-44');
      expect(
        order.items.single.purchasedAt,
        DateTime.parse('2026-07-25T09:30:00.000Z'),
      );
      expect(order.items.single.manufacturer, '丰田');
      expect(order.items.single.manufacturerRu, 'Toyota');
      expect(order.items.single.partNumber, '04465-33480');
      expect(order.items.single.imageUrl, '/uploads/garage-options/brakes.jpg');
      expect(order.items.single.imageUrls, [
        '/uploads/garage-options/brakes.jpg',
        '/uploads/garage-options/brakes-side.jpg',
      ]);
      expect(
        order.items.single.descriptionRu,
        'Оригинальные тормозные колодки',
      );
    },
  );

  test('legacy option image is exposed as a one-image gallery', () {
    final option = GaragePartOption.fromJson({
      'id': 501,
      'requestItemId': 101,
      'imageUrl': '/uploads/garage-options/legacy.jpg',
    });

    expect(option.imageUrl, '/uploads/garage-options/legacy.jpg');
    expect(option.imageUrls, ['/uploads/garage-options/legacy.jpg']);
  });

  test('message page parses unread cursor and employee question', () {
    final page = GarageMessagePage.fromJson({
      'messages': [
        {
          'id': 71,
          'requestId': 11,
          'senderType': 'employee',
          'senderId': 5,
          'senderName': 'Менеджер',
          'messageType': 'question',
          'requiresResponseFrom': 'client',
          'content': '原厂件可以吗？',
          'contentRu': 'Подойдёт оригинал?',
          'createdAt': '2026-07-23T10:00:00.000Z',
        },
      ],
      'nextCursor': 71,
      'unreadCount': 1,
      'lastReadMessageId': 60,
    });

    expect(page.messages.single.awaitsClientAnswer, isTrue);
    expect(page.messages.single.isFromClient, isFalse);
    expect(page.messages.single.displayContent, 'Подойдёт оригинал?');
    expect(page.nextCursor, 71);
    expect(page.unreadCount, 1);
    expect(page.lastReadMessageId, 60);
  });
}
