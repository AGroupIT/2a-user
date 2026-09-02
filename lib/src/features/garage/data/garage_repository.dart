import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';

import '../domain/garage_models.dart';
import 'garage_remote_client.dart';

abstract interface class GarageRepository {
  Future<GarageAvailability> getAvailability();

  Future<GarageVinLookupResult> lookupVin(String vin);

  Future<List<GarageVehicle>> getVehicles();

  Future<GarageVehicle> createVehicle(GarageVehicleInput input);

  Future<GarageVehicle> getVehicle(int vehicleId);

  Future<GarageVehicle> updateVehicle(int vehicleId, GarageVehicleInput input);

  Future<void> deleteVehicle(int vehicleId);

  Future<List<GarageRequest>> getRequests({int? vehicleId});

  Future<GarageRequest> createRequest(
    GarageRequestInput input, {
    String? idempotencyKey,
  });

  Future<GarageRequest> getRequest(int requestId);

  Future<GarageOffer?> getCurrentOffer(int requestId);

  Future<GarageMessagePage> getRequestMessages(
    int requestId, {
    int? cursor,
    int take = 100,
  });

  Future<GarageRequestMessage> sendRequestMessage(
    int requestId, {
    required String content,
    required String messageType,
    int? replyToMessageId,
    bool resolveQuestion = false,
    List<int> attachmentIds = const [],
  });

  Future<GarageMessageAttachment> uploadMessageAttachment({
    required int requestId,
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
  });

  Future<GarageMessageReadCursor> markRequestMessagesRead(
    int requestId, {
    required int lastReadMessageId,
  });

  Future<GarageRequest> updateRequest(
    int requestId,
    GarageRequestUpdate update,
  );

  Future<GarageRequest> submitRequest(
    int requestId, {
    required String idempotencyKey,
  });

  Future<GarageRequestItem> addRequestItem(
    int requestId,
    GarageRequestItemInput input,
  );

  Future<GarageRequestItem> updateRequestItem(
    int itemId,
    GarageRequestItemInput input,
  );

  Future<String> uploadRequestItemImage({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
  });

  Future<void> deleteRequestItem(int itemId);

  Future<GarageRequest> cancelRequest(int requestId);

  Future<GarageRequest> cloneRequest(
    int requestId, {
    required String idempotencyKey,
  });

  Future<GarageOfferCalculation> calculateOffer(
    int requestId,
    int offerId,
    List<GarageOfferSelection> selections,
  );

  Future<GarageAcceptResult> acceptOffer(
    int requestId,
    int offerId,
    List<GarageOfferSelection> selections, {
    required String idempotencyKey,
  });

  Future<List<GarageOrder>> getOrders();

  Future<GarageOrder> getOrder(int orderId);

  Future<GarageOrder> updateOrderSelection(
    int orderId,
    List<GarageOfferSelection> selections,
  );

  Future<GarageInvoice> getOrderInvoice(int orderId);

  Future<GarageOrder> cancelOrder(int orderId);

  Future<GarageBankQrPayment> startBankQrPayment(
    int orderId, {
    required String idempotencyKey,
  });

  Future<GarageReceiptUploadResult> uploadPaymentReceipt({
    required int paymentId,
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
  });

  Future<GarageRefundRequest> requestRefund({
    required int orderId,
    required String reason,
    required List<int> requestedOrderItemIds,
  });
}

class RemoteGarageRepository implements GarageRepository {
  final GarageRemoteClient _client;

  const RemoteGarageRepository(this._client);

  @override
  Future<GarageAvailability> getAvailability() async {
    final data = await _client.get('/client/garage/availability');
    return GarageAvailability.fromJson(
      _unwrapMap(data, const ['availability', 'data']),
    );
  }

  @override
  Future<GarageVinLookupResult> lookupVin(String vin) async {
    final normalizedVin = vin.trim().toUpperCase();
    final data = await _client.post(
      '/client/garage/vin/lookup',
      data: {'vin': normalizedVin},
    );
    return GarageVinLookupResult.fromJson(
      _unwrapMap(data, const ['vehicle', 'result', 'data']),
    );
  }

  @override
  Future<List<GarageVehicle>> getVehicles() async {
    final data = await _client.get('/client/garage/vehicles');
    return _unwrapList(data, const [
      'vehicles',
      'data',
    ]).map(GarageVehicle.fromJson).toList(growable: false);
  }

  @override
  Future<GarageVehicle> createVehicle(GarageVehicleInput input) async {
    final data = await _client.post(
      '/client/garage/vehicles',
      data: input.toJson(),
    );
    return GarageVehicle.fromJson(_unwrapMap(data, const ['vehicle', 'data']));
  }

  @override
  Future<GarageVehicle> getVehicle(int vehicleId) async {
    final data = await _client.get('/client/garage/vehicles/$vehicleId');
    return GarageVehicle.fromJson(_unwrapMap(data, const ['vehicle', 'data']));
  }

  @override
  Future<GarageVehicle> updateVehicle(
    int vehicleId,
    GarageVehicleInput input,
  ) async {
    final data = await _client.patch(
      '/client/garage/vehicles/$vehicleId',
      data: input.toJson(),
    );
    return GarageVehicle.fromJson(_unwrapMap(data, const ['vehicle', 'data']));
  }

  @override
  Future<void> deleteVehicle(int vehicleId) async {
    await _client.delete('/client/garage/vehicles/$vehicleId');
  }

  @override
  Future<List<GarageRequest>> getRequests({int? vehicleId}) async {
    final data = await _client.get(
      '/client/garage/requests',
      queryParameters: {if (vehicleId != null) 'vehicleId': vehicleId},
    );
    return _unwrapList(data, const [
      'requests',
      'data',
    ]).map(GarageRequest.fromJson).toList(growable: false);
  }

  @override
  Future<GarageRequest> createRequest(
    GarageRequestInput input, {
    String? idempotencyKey,
  }) async {
    final data = await _client.post(
      '/client/garage/requests',
      data: input.toJson(),
      headers: _idempotencyHeaders(idempotencyKey),
    );
    return GarageRequest.fromJson(_unwrapMap(data, const ['request', 'data']));
  }

  @override
  Future<GarageRequest> getRequest(int requestId) async {
    final data = await _client.get('/client/garage/requests/$requestId');
    final request = GarageRequest.fromJson(
      _unwrapMap(data, const ['request', 'data']),
    );
    GarageOffer? currentOffer;
    GarageOrder? linkedOrder;

    if (request.currentOfferId != null) {
      currentOffer = await getCurrentOffer(requestId);
    }
    if ({
      'converted_to_order',
      'unpaid',
      'payment_review',
      'paid',
    }.contains(request.status)) {
      try {
        final orders = await getOrders();
        for (final order in orders) {
          if (order.requestId == requestId) {
            linkedOrder = order;
            break;
          }
        }
      } on DioException catch (error) {
        if (!_isMissingAuxiliaryResource(error)) rethrow;
      }
    }
    return request.copyWith(currentOffer: currentOffer, order: linkedOrder);
  }

  @override
  Future<GarageOffer?> getCurrentOffer(int requestId) async {
    try {
      final data = await _client.get(
        '/client/garage/requests/$requestId/offers/current',
      );
      final root = _stringKeyedMap(data);
      final rawOffer = root['offer'];
      if (rawOffer is! Map) return null;
      return GarageOffer.fromJson(_stringKeyedMap(rawOffer));
    } on DioException catch (error) {
      if (_isMissingAuxiliaryResource(error)) return null;
      rethrow;
    }
  }

  @override
  Future<GarageMessagePage> getRequestMessages(
    int requestId, {
    int? cursor,
    int take = 100,
  }) async {
    final data = await _client.get(
      '/client/garage/requests/$requestId/messages',
      queryParameters: {
        if (cursor != null) 'cursor': cursor,
        'take': take.clamp(1, 100),
        'mode': 'latest',
      },
    );
    return GarageMessagePage.fromJson(_stringKeyedMap(data));
  }

  @override
  Future<GarageRequestMessage> sendRequestMessage(
    int requestId, {
    required String content,
    required String messageType,
    int? replyToMessageId,
    bool resolveQuestion = false,
    List<int> attachmentIds = const [],
  }) async {
    final data = await _client.post(
      '/client/garage/requests/$requestId/messages',
      data: {
        'content': content.trim(),
        'messageType': messageType,
        if (replyToMessageId != null) 'replyToMessageId': replyToMessageId,
        if (resolveQuestion) 'resolveQuestion': true,
        if (attachmentIds.isNotEmpty) 'attachmentIds': attachmentIds,
      },
    );
    return GarageRequestMessage.fromJson(
      _unwrapMap(data, const ['message', 'data']),
    );
  }

  @override
  Future<GarageMessageAttachment> uploadMessageAttachment({
    required int requestId,
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
  }) async {
    final data = await _client.post(
      '/garage/requests/$requestId/attachments',
      data: FormData.fromMap({
        'file': MultipartFile.fromBytes(
          bytes,
          filename: fileName,
          contentType: _mediaType(mimeType),
        ),
      }),
      headers: const {'Content-Type': 'multipart/form-data'},
    );
    return GarageMessageAttachment.fromJson(
      _unwrapMap(data, const ['attachment', 'data']),
    );
  }

  @override
  Future<GarageMessageReadCursor> markRequestMessagesRead(
    int requestId, {
    required int lastReadMessageId,
  }) async {
    final data = await _client.post(
      '/client/garage/requests/$requestId/messages/read',
      data: {'lastReadMessageId': lastReadMessageId},
    );
    return GarageMessageReadCursor.fromJson(_stringKeyedMap(data));
  }

  @override
  Future<GarageRequest> updateRequest(
    int requestId,
    GarageRequestUpdate update,
  ) async {
    final data = await _client.patch(
      '/client/garage/requests/$requestId',
      data: update.toJson(),
    );
    return GarageRequest.fromJson(_unwrapMap(data, const ['request', 'data']));
  }

  @override
  Future<GarageRequest> submitRequest(
    int requestId, {
    required String idempotencyKey,
  }) async {
    final data = await _client.post(
      '/client/garage/requests/$requestId/submit',
      data: const <String, dynamic>{},
      headers: _idempotencyHeaders(idempotencyKey),
    );
    return GarageRequest.fromJson(_unwrapMap(data, const ['request', 'data']));
  }

  @override
  Future<GarageRequestItem> addRequestItem(
    int requestId,
    GarageRequestItemInput input,
  ) async {
    final data = await _client.post(
      '/client/garage/requests/$requestId/items',
      data: input.toJson(),
    );
    return GarageRequestItem.fromJson(_unwrapMap(data, const ['item', 'data']));
  }

  @override
  Future<GarageRequestItem> updateRequestItem(
    int itemId,
    GarageRequestItemInput input,
  ) async {
    final data = await _client.patch(
      '/client/garage/request-items/$itemId',
      data: input.toJson(),
    );
    return GarageRequestItem.fromJson(_unwrapMap(data, const ['item', 'data']));
  }

  @override
  Future<String> uploadRequestItemImage({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
  }) async {
    final data = await _client.post(
      '/client/garage/request-items/image',
      data: FormData.fromMap({
        'file': MultipartFile.fromBytes(
          bytes,
          filename: fileName,
          contentType: _mediaType(mimeType),
        ),
      }),
      headers: const {'Content-Type': 'multipart/form-data'},
    );
    final payload = _unwrapMap(data, const ['data']);
    final url = payload['url']?.toString().trim();
    if (url == null || url.isEmpty) {
      throw const FormatException('Garage item image URL is missing');
    }
    return url;
  }

  @override
  Future<void> deleteRequestItem(int itemId) async {
    await _client.delete('/client/garage/request-items/$itemId');
  }

  @override
  Future<GarageRequest> cancelRequest(int requestId) async {
    final data = await _client.post(
      '/client/garage/requests/$requestId/cancel',
      data: const <String, dynamic>{},
    );
    return GarageRequest.fromJson(_unwrapMap(data, const ['request', 'data']));
  }

  @override
  Future<GarageRequest> cloneRequest(
    int requestId, {
    required String idempotencyKey,
  }) async {
    final data = await _client.post(
      '/client/garage/requests/$requestId/clone',
      data: const <String, dynamic>{},
      headers: _idempotencyHeaders(idempotencyKey),
    );
    return GarageRequest.fromJson(_unwrapMap(data, const ['request', 'data']));
  }

  @override
  Future<GarageOfferCalculation> calculateOffer(
    int requestId,
    int offerId,
    List<GarageOfferSelection> selections,
  ) async {
    final data = await _client.post(
      '/client/garage/requests/$requestId/offers/$offerId/calculate',
      data: {'selections': _selectionPayload(selections)},
    );
    return GarageOfferCalculation.fromJson(
      _unwrapMap(data, const ['calculation', 'quote', 'data']),
    );
  }

  @override
  Future<GarageAcceptResult> acceptOffer(
    int requestId,
    int offerId,
    List<GarageOfferSelection> selections, {
    required String idempotencyKey,
  }) async {
    final data = await _client.post(
      '/client/garage/requests/$requestId/offers/$offerId/accept',
      data: {'selections': _selectionPayload(selections)},
      headers: _idempotencyHeaders(idempotencyKey),
    );
    return GarageAcceptResult.fromJson(
      _unwrapMap(data, const ['result', 'data']),
    );
  }

  @override
  Future<List<GarageOrder>> getOrders() async {
    final data = await _client.get('/client/garage/orders');
    return _unwrapList(data, const [
      'orders',
      'data',
    ]).map(GarageOrder.fromJson).toList(growable: false);
  }

  @override
  Future<GarageOrder> getOrder(int orderId) async {
    final data = await _client.get('/client/garage/orders/$orderId');
    return GarageOrder.fromJson(_unwrapMap(data, const ['order', 'data']));
  }

  @override
  Future<GarageOrder> updateOrderSelection(
    int orderId,
    List<GarageOfferSelection> selections,
  ) async {
    final data = await _client.patch(
      '/client/garage/orders/$orderId/selection',
      data: {'selections': _selectionPayload(selections)},
    );
    return GarageOrder.fromJson(_unwrapMap(data, const ['order', 'data']));
  }

  @override
  Future<GarageInvoice> getOrderInvoice(int orderId) async {
    final data = await _client.get('/client/garage/orders/$orderId/invoice');
    return GarageInvoice.fromJson(_unwrapMap(data, const ['invoice', 'data']));
  }

  @override
  Future<GarageOrder> cancelOrder(int orderId) async {
    final data = await _client.post(
      '/client/garage/orders/$orderId/cancel',
      data: const <String, dynamic>{},
    );
    return GarageOrder.fromJson(_unwrapMap(data, const ['order', 'data']));
  }

  @override
  Future<GarageBankQrPayment> startBankQrPayment(
    int orderId, {
    required String idempotencyKey,
  }) async {
    final data = await _client.post(
      '/client/garage/orders/$orderId/payment/bank-qr/start',
      data: const <String, dynamic>{},
      headers: _idempotencyHeaders(idempotencyKey),
    );
    return GarageBankQrPayment.fromJson(
      _unwrapMap(data, const ['payment', 'data']),
    );
  }

  @override
  Future<GarageReceiptUploadResult> uploadPaymentReceipt({
    required int paymentId,
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
  }) async {
    final mediaType = _mediaType(mimeType);
    final data = await _client.post(
      '/client/garage/payments/$paymentId/receipt',
      data: FormData.fromMap({
        'file': MultipartFile.fromBytes(
          bytes,
          filename: fileName,
          contentType: mediaType,
        ),
      }),
      headers: const {'Content-Type': 'multipart/form-data'},
    );
    return GarageReceiptUploadResult.fromJson(
      _unwrapMap(data, const ['receipt', 'data']),
    );
  }

  @override
  Future<GarageRefundRequest> requestRefund({
    required int orderId,
    required String reason,
    required List<int> requestedOrderItemIds,
  }) async {
    final data = await _client.post(
      '/client/garage/orders/$orderId/request-refund',
      data: {
        'reason': reason.trim(),
        'requestedOrderItemIds': requestedOrderItemIds,
      },
    );
    return GarageRefundRequest.fromJson(
      _unwrapMap(data, const ['refundRequest', 'request', 'data']),
    );
  }
}

Map<String, String>? _idempotencyHeaders(String? value) {
  final normalized = value?.trim();
  if (normalized == null || normalized.isEmpty) return null;
  return {'Idempotency-Key': normalized};
}

List<Map<String, dynamic>> _selectionPayload(
  List<GarageOfferSelection> selections,
) {
  return selections
      .map((selection) => selection.toJson())
      .toList(growable: false);
}

MediaType _mediaType(String value) {
  final parts = value.trim().split('/');
  if (parts.length == 2 && parts.every((part) => part.isNotEmpty)) {
    return MediaType(parts[0], parts[1]);
  }
  return MediaType('application', 'octet-stream');
}

bool _isMissingAuxiliaryResource(DioException error) {
  final statusCode = error.response?.statusCode;
  return statusCode == 404 || statusCode == 409;
}

Map<String, dynamic> _unwrapMap(Object? value, List<String> preferredKeys) {
  final root = _stringKeyedMap(value);
  for (final key in preferredKeys) {
    final nested = root[key];
    if (nested is Map) {
      final nestedMap = _stringKeyedMap(nested);
      for (final nestedKey in preferredKeys) {
        final entity = nestedMap[nestedKey];
        if (entity is Map) return _stringKeyedMap(entity);
      }
      return nestedMap;
    }
  }
  return root;
}

List<Map<String, dynamic>> _unwrapList(
  Object? value,
  List<String> preferredKeys,
) {
  Object? candidate = value;
  if (value is Map) {
    final root = _stringKeyedMap(value);
    for (final key in preferredKeys) {
      if (root[key] is List) {
        candidate = root[key];
        break;
      }
      if (root[key] is Map) {
        final nested = _stringKeyedMap(root[key]);
        Object? nestedList;
        for (final nestedKey in [...preferredKeys, 'items', 'results']) {
          if (nested[nestedKey] is List) {
            nestedList = nested[nestedKey];
            break;
          }
        }
        if (nestedList is List) {
          candidate = nestedList;
          break;
        }
      }
    }
  }
  if (candidate is! List) return const [];
  return candidate
      .whereType<Map>()
      .map(_stringKeyedMap)
      .toList(growable: false);
}

Map<String, dynamic> _stringKeyedMap(Object? value) {
  if (value is! Map) return const {};
  return {for (final entry in value.entries) entry.key.toString(): entry.value};
}
