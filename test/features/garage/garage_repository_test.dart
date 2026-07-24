import 'dart:collection';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twoalogisticcabineuser/src/features/garage/data/garage_remote_client.dart';
import 'package:twoalogisticcabineuser/src/features/garage/data/garage_repository.dart';
import 'package:twoalogisticcabineuser/src/features/garage/domain/garage_models.dart';

void main() {
  late _RecordingGarageRemoteClient client;
  late RemoteGarageRepository repository;

  setUp(() {
    client = _RecordingGarageRemoteClient();
    repository = RemoteGarageRepository(client);
  });

  test('availability and VIN lookup use the client Garage contract', () async {
    client.responses.addAll([
      {'available': true, 'processorAgentId': 5, 'vinLookupConfigured': true},
      {
        'vehicle': {
          'vinNormalized': 'JTDKN3DU0D1234567',
          'make': 'Toyota',
          'model': 'Prius',
          'modelYear': 2013,
        },
      },
    ]);

    final availability = await repository.getAvailability();
    final vin = await repository.lookupVin(' jtdkn3du0d1234567 ');

    expect(availability.processorAgentId, 5);
    expect(vin.model, 'Prius');
    expect(client.calls[0].path, '/client/garage/availability');
    expect(client.calls[1].path, '/client/garage/vin/lookup');
    expect(client.calls[1].data, {'vin': 'JTDKN3DU0D1234567'});
  });

  test('vehicle CRUD uses dedicated Garage endpoints', () async {
    final vehicleJson = _vehicleJson(id: 7);
    client.responses.addAll([
      {
        'data': {
          'vehicles': [vehicleJson],
        },
      },
      {
        'data': {'vehicle': vehicleJson},
      },
      {'data': vehicleJson},
      {'vehicle': vehicleJson},
      null,
    ]);

    const input = GarageVehicleInput(
      vin: 'JTDKN3DU0D1234567',
      make: 'Toyota',
      model: 'Prius',
      modelYear: 2013,
    );

    expect((await repository.getVehicles()).single.id, 7);
    await repository.createVehicle(input);
    await repository.getVehicle(7);
    await repository.updateVehicle(7, input);
    await repository.deleteVehicle(7);

    expect(client.calls.map((call) => '${call.method} ${call.path}'), [
      'GET /client/garage/vehicles',
      'POST /client/garage/vehicles',
      'GET /client/garage/vehicles/7',
      'PATCH /client/garage/vehicles/7',
      'DELETE /client/garage/vehicles/7',
    ]);
  });

  test(
    'request submit and item CRUD use correct paths and idempotency',
    () async {
      final requestJson = _requestJson(id: 11, status: 'draft');
      final submittedJson = _requestJson(id: 11, status: 'submitted');
      final itemJson = _itemJson(id: 101, requestId: 11);
      client.responses.addAll([
        {
          'requests': [requestJson],
        },
        {'request': requestJson},
        {'request': requestJson},
        {'request': requestJson},
        {'request': submittedJson},
        {'item': itemJson},
        {'item': itemJson},
        null,
      ]);

      await repository.getRequests(vehicleId: 7);
      await repository.createRequest(
        const GarageRequestInput(
          vehicleId: 7,
          clientCodeId: 3,
          clientComment: ' Нужны детали ',
        ),
        idempotencyKey: ' create-1 ',
      );
      await repository.getRequest(11);
      await repository.updateRequest(
        11,
        const GarageRequestUpdate(clientComment: 'Уточнение'),
      );
      final submitted = await repository.submitRequest(
        11,
        idempotencyKey: 'submit-1',
      );
      const itemInput = GarageRequestItemInput(
        partName: 'Колодки',
        partNumber: '04465-33480',
        preference: GaragePartPreference.original,
        existUrl: 'https://exist.ru/item',
        quantity: 2,
      );
      await repository.addRequestItem(11, itemInput);
      await repository.updateRequestItem(101, itemInput);
      await repository.deleteRequestItem(101);

      expect(submitted.status, 'submitted');
      expect(client.calls[0].queryParameters, {'vehicleId': 7});
      expect(client.calls[1].headers, {'Idempotency-Key': 'create-1'});
      expect(client.calls[1].data, {
        'vehicleId': 7,
        'clientCodeId': 3,
        'clientComment': 'Нужны детали',
      });
      expect(client.calls[4].headers, {'Idempotency-Key': 'submit-1'});
      expect(client.calls.map((call) => '${call.method} ${call.path}'), [
        'GET /client/garage/requests',
        'POST /client/garage/requests',
        'GET /client/garage/requests/11',
        'PATCH /client/garage/requests/11',
        'POST /client/garage/requests/11/submit',
        'POST /client/garage/requests/11/items',
        'PATCH /client/garage/request-items/101',
        'DELETE /client/garage/request-items/101',
      ]);
    },
  );

  test('request detail loads current offer and linked Garage order', () async {
    client.responses.addAll([
      {
        'request': {
          ..._requestJson(id: 11, status: 'offer_ready'),
          'currentOfferId': 88,
        },
      },
      {
        'offer': {
          'id': 88,
          'requestId': 11,
          'version': 1,
          'status': 'published',
          'clientCnyRubRateSnapshot': '12.5',
          'options': [
            {
              'id': 501,
              'offerId': 88,
              'requestItemId': 101,
              'manufacturer': 'Toyota',
              'partNumber': '04465-33480',
              'optionType': 'original',
              'clientUnitPriceCny': '100',
              'chinaDeliveryCny': '5',
              'serviceFeeCny': '10',
            },
          ],
        },
      },
      {'request': _requestJson(id: 11, status: 'converted_to_order')},
      {
        'orders': [_orderJson(id: 44)],
      },
    ]);

    final withOffer = await repository.getRequest(11);
    final converted = await repository.getRequest(11);

    expect(withOffer.currentOffer?.id, 88);
    expect(withOffer.currentOffer?.options.single.id, 501);
    expect(converted.order?.id, 44);
    expect(client.calls.map((call) => '${call.method} ${call.path}'), [
      'GET /client/garage/requests/11',
      'GET /client/garage/requests/11/offers/current',
      'GET /client/garage/requests/11',
      'GET /client/garage/orders',
    ]);
  });

  test('Garage conversation supports page, answer and read cursor', () async {
    final message = {
      'id': 71,
      'requestId': 11,
      'senderType': 'employee',
      'senderId': 5,
      'senderName': 'Менеджер',
      'messageType': 'question',
      'requiresResponseFrom': 'client',
      'content': 'Подойдёт оригинал?',
      'createdAt': '2026-07-23T10:00:00.000Z',
    };
    client.responses.addAll([
      {
        'messages': [message],
        'nextCursor': null,
        'unreadCount': 1,
        'lastReadMessageId': 60,
      },
      {
        'message': {
          ...message,
          'id': 72,
          'senderType': 'client',
          'senderName': 'Клиент',
          'messageType': 'answer',
          'requiresResponseFrom': null,
          'replyToMessageId': 71,
          'content': 'Да, нужен оригинал',
        },
      },
      {'lastReadMessageId': 72, 'lastReadAt': '2026-07-23T10:01:00.000Z'},
    ]);

    final page = await repository.getRequestMessages(11, cursor: 60);
    final answer = await repository.sendRequestMessage(
      11,
      content: ' Да, нужен оригинал ',
      messageType: 'answer',
      replyToMessageId: 71,
      resolveQuestion: true,
    );
    final cursor = await repository.markRequestMessagesRead(
      11,
      lastReadMessageId: 72,
    );

    expect(page.unreadCount, 1);
    expect(answer.replyToMessageId, 71);
    expect(cursor.lastReadMessageId, 72);
    expect(client.calls.map((call) => '${call.method} ${call.path}'), [
      'GET /client/garage/requests/11/messages',
      'POST /client/garage/requests/11/messages',
      'POST /client/garage/requests/11/messages/read',
    ]);
    expect(client.calls[0].queryParameters, {'cursor': 60, 'take': 100});
    expect(client.calls[1].data, {
      'content': 'Да, нужен оригинал',
      'messageType': 'answer',
      'replyToMessageId': 71,
      'resolveQuestion': true,
    });
    expect(client.calls[2].data, {'lastReadMessageId': 72});
  });

  test('offer and unpaid order send multi-option quantities', () async {
    client.responses.addAll([
      {
        'offerId': 88,
        'selections': [
          {'requestItemId': 101, 'optionId': 501, 'quantity': 2},
          {'requestItemId': 101, 'optionId': 502, 'quantity': 3},
        ],
        'totals': {'totalCny': '100', 'totalRub': '12500'},
      },
      {
        'order': _orderJson(id: 44),
        'invoice': _invoiceJson(id: 55, orderId: 44),
      },
      {'order': _orderJson(id: 44)},
    ]);

    const selections = [
      GarageOfferSelection(requestItemId: 101, optionId: 501, quantity: 2),
      GarageOfferSelection(requestItemId: 101, optionId: 502, quantity: 3),
    ];
    final calculation = await repository.calculateOffer(11, 88, selections);
    final accepted = await repository.acceptOffer(
      11,
      88,
      selections,
      idempotencyKey: 'accept-1',
    );
    final updated = await repository.updateOrderSelection(44, selections);

    expect(calculation.totalRub, 12500);
    expect(accepted.order.id, 44);
    expect(updated.id, 44);
    expect(
      client.calls[0].path,
      '/client/garage/requests/11/offers/88/calculate',
    );
    expect(client.calls[0].data, {
      'selections': [
        {'requestItemId': 101, 'optionId': 501, 'quantity': 2},
        {'requestItemId': 101, 'optionId': 502, 'quantity': 3},
      ],
    });
    expect(client.calls[1].path, '/client/garage/requests/11/offers/88/accept');
    expect(client.calls[1].data, {
      'selections': [
        {'requestItemId': 101, 'optionId': 501, 'quantity': 2},
        {'requestItemId': 101, 'optionId': 502, 'quantity': 3},
      ],
    });
    expect(client.calls[1].headers, {'Idempotency-Key': 'accept-1'});
    expect(client.calls[2].method, 'PATCH');
    expect(client.calls[2].path, '/client/garage/orders/44/selection');
    expect(client.calls[2].data, {
      'selections': [
        {'requestItemId': 101, 'optionId': 501, 'quantity': 2},
        {'requestItemId': 101, 'optionId': 502, 'quantity': 3},
      ],
    });
  });

  test(
    'order, invoice, Bank QR, receipt and refund use Garage routes',
    () async {
      final order = _orderJson(id: 44);
      final invoice = _invoiceJson(id: 55, orderId: 44);
      client.responses.addAll([
        {
          'orders': [order],
        },
        {'order': order},
        {'invoice': invoice},
        {
          'order': {...order, 'status': 'cancelled'},
        },
        {
          'paymentId': 77,
          'garageInvoiceId': 55,
          'invoiceNumber': 'GI-A-01',
          'amountRub': 12500,
          'sumKopecks': 1250000,
          'purpose': 'Оплата автозапчастей',
          'qrPayload': 'ST00012|Name=2A',
          'status': 'pending',
        },
        {'receiptId': 9, 'paymentId': 77, 'invoiceStatus': 'payment_review'},
        {
          'refundRequest': {
            'id': 8,
            'orderId': 44,
            'reason': 'Деталь не подходит',
            'requestedOrderItemIds': [901],
            'status': 'pending',
          },
        },
      ]);

      expect((await repository.getOrders()).single.id, 44);
      await repository.getOrder(44);
      expect((await repository.getOrderInvoice(44)).id, 55);
      await repository.cancelOrder(44);
      final payment = await repository.startBankQrPayment(
        44,
        idempotencyKey: 'pay-1',
      );
      final receipt = await repository.uploadPaymentReceipt(
        paymentId: 77,
        bytes: Uint8List.fromList([1, 2, 3]),
        fileName: 'receipt.pdf',
        mimeType: 'application/pdf',
      );
      final refund = await repository.requestRefund(
        orderId: 44,
        reason: ' Деталь не подходит ',
        requestedOrderItemIds: [901],
      );

      expect(payment.garageInvoiceId, 55);
      expect(receipt.invoiceStatus, 'payment_review');
      expect(refund.requestedOrderItemIds, [901]);
      expect(client.calls.map((call) => '${call.method} ${call.path}'), [
        'GET /client/garage/orders',
        'GET /client/garage/orders/44',
        'GET /client/garage/orders/44/invoice',
        'POST /client/garage/orders/44/cancel',
        'POST /client/garage/orders/44/payment/bank-qr/start',
        'POST /client/garage/payments/77/receipt',
        'POST /client/garage/orders/44/request-refund',
      ]);
      expect(client.calls[4].headers, {'Idempotency-Key': 'pay-1'});
      expect(client.calls[5].data, isA<FormData>());
      expect(client.calls[6].data, {
        'reason': 'Деталь не подходит',
        'requestedOrderItemIds': [901],
      });
    },
  );
}

class _RemoteCall {
  final String method;
  final String path;
  final Object? data;
  final Map<String, dynamic>? queryParameters;
  final Map<String, String>? headers;

  const _RemoteCall({
    required this.method,
    required this.path,
    this.data,
    this.queryParameters,
    this.headers,
  });
}

class _RecordingGarageRemoteClient implements GarageRemoteClient {
  final Queue<Object?> responses = Queue<Object?>();
  final List<_RemoteCall> calls = [];

  Object? _next() => responses.isEmpty ? null : responses.removeFirst();

  @override
  Future<Object?> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    calls.add(
      _RemoteCall(method: 'GET', path: path, queryParameters: queryParameters),
    );
    return _next();
  }

  @override
  Future<Object?> post(
    String path, {
    Object? data,
    Map<String, String>? headers,
  }) async {
    calls.add(
      _RemoteCall(method: 'POST', path: path, data: data, headers: headers),
    );
    return _next();
  }

  @override
  Future<Object?> patch(String path, {Object? data}) async {
    calls.add(_RemoteCall(method: 'PATCH', path: path, data: data));
    return _next();
  }

  @override
  Future<Object?> delete(String path) async {
    calls.add(_RemoteCall(method: 'DELETE', path: path));
    return _next();
  }
}

Map<String, dynamic> _vehicleJson({required int id}) {
  return {
    'id': id,
    'vinNormalized': 'JTDKN3DU0D1234567',
    'make': 'Toyota',
    'model': 'Prius',
    'modelYear': 2013,
  };
}

Map<String, dynamic> _requestJson({required int id, required String status}) {
  return {
    'id': id,
    'requestNumber': 'GAR-A-01',
    'vehicleId': 7,
    'status': status,
    'items': <Map<String, dynamic>>[],
  };
}

Map<String, dynamic> _itemJson({required int id, required int requestId}) {
  return {
    'id': id,
    'requestId': requestId,
    'orderNumber': 1,
    'partName': 'Колодки',
    'partNumber': '04465-33480',
    'preference': 'original',
    'existUrl': 'https://exist.ru/item',
    'quantity': 2,
  };
}

Map<String, dynamic> _orderJson({required int id}) {
  return {
    'id': id,
    'orderNumber': 'GO-A-01',
    'requestId': 11,
    'requestNumber': 'GAR-A-01',
    'status': 'awaiting_payment',
    'clientCnyRubRateSnapshot': '125',
    'goodsTotalCny': '90',
    'chinaDeliveryTotalCny': '5',
    'serviceFeeTotalCny': '5',
    'discountCny': '0',
    'totalCny': '100',
    'totalRub': '12500',
    'items': <Map<String, dynamic>>[],
  };
}

Map<String, dynamic> _invoiceJson({required int id, required int orderId}) {
  return {
    'id': id,
    'invoiceNumber': 'GI-A-01',
    'orderId': orderId,
    'status': 'unpaid',
    'clientCnyRubRateSnapshot': '125',
    'totalCny': '100',
    'totalRub': '12500',
  };
}
