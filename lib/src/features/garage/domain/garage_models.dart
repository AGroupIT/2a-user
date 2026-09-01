import 'package:flutter/foundation.dart';

import '../../payments/data/client_payment_summary.dart';

@immutable
class GarageAvailability {
  final bool available;
  final String? reason;
  final int? processorAgentId;
  final bool vinLookupConfigured;

  const GarageAvailability({
    required this.available,
    required this.reason,
    required this.processorAgentId,
    required this.vinLookupConfigured,
  });

  factory GarageAvailability.fromJson(Map<String, dynamic> json) {
    return GarageAvailability(
      available: json['available'] == true,
      reason: _nullableString(json['reason']),
      processorAgentId: _nullableInt(json['processorAgentId']),
      vinLookupConfigured: json['vinLookupConfigured'] == true,
    );
  }
}

@immutable
class GarageVinLookupResult {
  final String vinNormalized;
  final String? make;
  final String? model;
  final int? modelYear;
  final String? generation;
  final String? trim;
  final String? bodyType;
  final String? engineCode;
  final String? engineVolume;
  final String? fuelType;
  final String? transmission;
  final String? driveType;
  final Map<String, dynamic> normalizedData;

  GarageVinLookupResult({
    required this.vinNormalized,
    required this.make,
    required this.model,
    required this.modelYear,
    required this.generation,
    required this.trim,
    required this.bodyType,
    required this.engineCode,
    required this.engineVolume,
    required this.fuelType,
    required this.transmission,
    required this.driveType,
    required Map<String, dynamic> normalizedData,
  }) : normalizedData = Map.unmodifiable(normalizedData);

  factory GarageVinLookupResult.fromJson(Map<String, dynamic> json) {
    final rawNormalizedData = _stringKeyedMap(
      json['normalizedData'] ?? json['vinLookupNormalizedData'],
    );
    return GarageVinLookupResult(
      vinNormalized:
          _nullableString(
            json['vinNormalized'] ?? json['vin'],
          )?.toUpperCase() ??
          '',
      make: _nullableString(json['make']),
      model: _nullableString(json['model']),
      modelYear: _nullableInt(json['modelYear'] ?? json['year']),
      generation: _nullableString(json['generation']),
      trim: _nullableString(json['trim']),
      bodyType: _nullableString(json['bodyType']),
      engineCode: _nullableString(json['engineCode']),
      engineVolume: _nullableString(
        json['engineVolume'] ?? json['engineDisplacement'],
      ),
      fuelType: _nullableString(json['fuelType']),
      transmission: _nullableString(json['transmission']),
      driveType: _nullableString(json['driveType']),
      normalizedData: rawNormalizedData.isEmpty
          ? Map<String, dynamic>.from(json)
          : rawNormalizedData,
    );
  }

  bool get isPartial =>
      make == null ||
      model == null ||
      modelYear == null ||
      vinNormalized.isEmpty;
}

@immutable
class GarageVehicleInput {
  final String vin;
  final String make;
  final String model;
  final int modelYear;
  final String? nickname;
  final String? generation;
  final String? trim;
  final String? bodyType;
  final String? engineCode;
  final String? engineVolume;
  final String? fuelType;
  final String? transmission;
  final String? driveType;
  final String? comment;

  const GarageVehicleInput({
    required this.vin,
    required this.make,
    required this.model,
    required this.modelYear,
    this.nickname,
    this.generation,
    this.trim,
    this.bodyType,
    this.engineCode,
    this.engineVolume,
    this.fuelType,
    this.transmission,
    this.driveType,
    this.comment,
  });

  Map<String, dynamic> toJson() {
    return {
      'vin': vin.trim().toUpperCase(),
      'make': make.trim(),
      'model': model.trim(),
      'modelYear': modelYear,
      'nickname': _trimmedOrNull(nickname),
      'generation': _trimmedOrNull(generation),
      'trim': _trimmedOrNull(trim),
      'bodyType': _trimmedOrNull(bodyType),
      'engineCode': _trimmedOrNull(engineCode),
      'engineVolume': _trimmedOrNull(engineVolume),
      'fuelType': _trimmedOrNull(fuelType),
      'transmission': _trimmedOrNull(transmission),
      'driveType': _trimmedOrNull(driveType),
      'comment': _trimmedOrNull(comment),
    };
  }
}

@immutable
class GarageVehicle {
  final int id;
  final int? clientId;
  final String vinNormalized;
  final String? nickname;
  final String make;
  final String model;
  final int modelYear;
  final String? generation;
  final String? trim;
  final String? bodyType;
  final String? engineCode;
  final String? engineVolume;
  final String? fuelType;
  final String? transmission;
  final String? driveType;
  final String? comment;
  final String? vinLookupProvider;
  final String? vinLookupStatus;
  final Map<String, dynamic>? vinLookupNormalizedData;
  final DateTime? vinLookupAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? archivedAt;
  final int activeRequestCount;
  final String? lastActiveStatus;

  GarageVehicle({
    required this.id,
    required this.clientId,
    required this.vinNormalized,
    required this.nickname,
    required this.make,
    required this.model,
    required this.modelYear,
    required this.generation,
    required this.trim,
    required this.bodyType,
    required this.engineCode,
    required this.engineVolume,
    required this.fuelType,
    required this.transmission,
    required this.driveType,
    required this.comment,
    required this.vinLookupProvider,
    required this.vinLookupStatus,
    required Map<String, dynamic>? vinLookupNormalizedData,
    required this.vinLookupAt,
    required this.createdAt,
    required this.updatedAt,
    required this.archivedAt,
    required this.activeRequestCount,
    required this.lastActiveStatus,
  }) : vinLookupNormalizedData = vinLookupNormalizedData == null
           ? null
           : Map.unmodifiable(vinLookupNormalizedData);

  factory GarageVehicle.fromJson(Map<String, dynamic> json) {
    final lookupData = _stringKeyedMap(json['vinLookupNormalizedData']);
    return GarageVehicle(
      id: _requiredInt(json['id'], 'GarageVehicle.id'),
      clientId: _nullableInt(json['clientId']),
      vinNormalized:
          _nullableString(
            json['vinNormalized'] ?? json['vin'],
          )?.toUpperCase() ??
          '',
      nickname: _nullableString(json['nickname']),
      make: _nullableString(json['make']) ?? '',
      model: _nullableString(json['model']) ?? '',
      modelYear: _nullableInt(json['modelYear'] ?? json['year']) ?? 0,
      generation: _nullableString(json['generation']),
      trim: _nullableString(json['trim']),
      bodyType: _nullableString(json['bodyType']),
      engineCode: _nullableString(json['engineCode']),
      engineVolume: _nullableString(json['engineVolume']),
      fuelType: _nullableString(json['fuelType']),
      transmission: _nullableString(json['transmission']),
      driveType: _nullableString(json['driveType']),
      comment: _nullableString(json['comment']),
      vinLookupProvider: _nullableString(json['vinLookupProvider']),
      vinLookupStatus: _nullableString(json['vinLookupStatus']),
      vinLookupNormalizedData: lookupData.isEmpty ? null : lookupData,
      vinLookupAt: _nullableDate(json['vinLookupAt']),
      createdAt: _nullableDate(json['createdAt']),
      updatedAt: _nullableDate(json['updatedAt']),
      archivedAt: _nullableDate(json['archivedAt']),
      activeRequestCount: _nullableInt(json['activeRequestCount']) ?? 0,
      lastActiveStatus: _nullableString(json['lastActiveStatus']),
    );
  }
}

enum GaragePartPreference {
  original('original'),
  analog('analog'),
  any('any'),
  unknown('unknown');

  final String apiValue;

  const GaragePartPreference(this.apiValue);

  static GaragePartPreference fromApiValue(Object? value) {
    final normalized = value?.toString().trim().toLowerCase();
    return values.firstWhere(
      (item) => item.apiValue == normalized,
      orElse: () => GaragePartPreference.unknown,
    );
  }
}

@immutable
class GarageRequestInput {
  final int vehicleId;
  final int clientCodeId;
  final String? clientComment;

  const GarageRequestInput({
    required this.vehicleId,
    required this.clientCodeId,
    this.clientComment,
  });

  Map<String, dynamic> toJson() {
    return {
      'vehicleId': vehicleId,
      'clientCodeId': clientCodeId,
      'clientComment': _trimmedOrNull(clientComment),
    };
  }
}

@immutable
class GarageRequestUpdate {
  final int? vehicleId;
  final int? clientCodeId;
  final String? clientComment;

  const GarageRequestUpdate({
    this.vehicleId,
    this.clientCodeId,
    required this.clientComment,
  });

  Map<String, dynamic> toJson() {
    return {
      if (vehicleId != null) 'vehicleId': vehicleId,
      if (clientCodeId != null) 'clientCodeId': clientCodeId,
      'clientComment': _trimmedOrNull(clientComment),
    };
  }
}

@immutable
class GarageRequestItemInput {
  final String partName;
  final String partNumber;
  final GaragePartPreference preference;
  final String? russiaAnalogueUrl;
  final String? imageUrl;
  final int quantity;
  final String? side;
  final String? position;
  final String? clientComment;
  final bool isOptional;

  const GarageRequestItemInput({
    required this.partName,
    required this.partNumber,
    required this.preference,
    String? russiaAnalogueUrl,
    this.imageUrl,
    @Deprecated('Use russiaAnalogueUrl') String? existUrl,
    this.quantity = 1,
    this.side,
    this.position,
    this.clientComment,
    this.isOptional = false,
  }) : russiaAnalogueUrl = russiaAnalogueUrl ?? existUrl,
       assert(quantity > 0);

  @Deprecated('Use russiaAnalogueUrl')
  String get existUrl => russiaAnalogueUrl ?? '';

  Map<String, dynamic> toJson() {
    return {
      'partName': partName.trim(),
      'partNumber': partNumber.trim(),
      'preference': preference.apiValue,
      'russiaAnalogueUrl': _trimmedOrNull(russiaAnalogueUrl),
      // Rolling-release compatibility with older backend versions.
      'existUrl': _trimmedOrNull(russiaAnalogueUrl),
      'imageUrl': _trimmedOrNull(imageUrl),
      'quantity': quantity,
      'side': _trimmedOrNull(side),
      'position': _trimmedOrNull(position),
      'clientComment': _trimmedOrNull(clientComment),
      'isOptional': isOptional,
    };
  }
}

@immutable
class GarageRequestItem {
  final int id;
  final int requestId;
  final int orderNumber;
  final String partName;
  final String partNumber;
  final String? partNumberNormalized;
  final GaragePartPreference preference;
  final String? russiaAnalogueUrl;
  final String? imageUrl;
  final int quantity;
  final String? side;
  final String? position;
  final String? clientComment;
  final bool isOptional;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const GarageRequestItem({
    required this.id,
    required this.requestId,
    required this.orderNumber,
    required this.partName,
    required this.partNumber,
    required this.partNumberNormalized,
    required this.preference,
    String? russiaAnalogueUrl,
    this.imageUrl,
    @Deprecated('Use russiaAnalogueUrl') String? existUrl,
    required this.quantity,
    required this.side,
    required this.position,
    required this.clientComment,
    required this.isOptional,
    required this.createdAt,
    required this.updatedAt,
  }) : russiaAnalogueUrl = russiaAnalogueUrl ?? existUrl;

  @Deprecated('Use russiaAnalogueUrl')
  String get existUrl => russiaAnalogueUrl ?? '';

  factory GarageRequestItem.fromJson(Map<String, dynamic> json) {
    return GarageRequestItem(
      id: _requiredInt(json['id'], 'GarageRequestItem.id'),
      requestId: _requiredInt(json['requestId'], 'GarageRequestItem.requestId'),
      orderNumber: _nullableInt(json['orderNumber']) ?? 0,
      partName: _nullableString(json['partName']) ?? '',
      partNumber: _nullableString(json['partNumber']) ?? '',
      partNumberNormalized: _nullableString(json['partNumberNormalized']),
      preference: GaragePartPreference.fromApiValue(json['preference']),
      russiaAnalogueUrl: _nullableString(
        json['russiaAnalogueUrl'] ?? json['existUrl'],
      ),
      imageUrl: _nullableString(json['imageUrl']),
      quantity: _nullableInt(json['quantity']) ?? 1,
      side: _nullableString(json['side']),
      position: _nullableString(json['position']),
      clientComment: _nullableString(json['clientComment']),
      isOptional: json['isOptional'] == true,
      createdAt: _nullableDate(json['createdAt']),
      updatedAt: _nullableDate(json['updatedAt']),
    );
  }
}

@immutable
class GarageRequestStatusChange {
  final int id;
  final String eventType;
  final String? previousStatus;
  final String status;
  final DateTime? changedAt;

  const GarageRequestStatusChange({
    required this.id,
    required this.eventType,
    required this.previousStatus,
    required this.status,
    required this.changedAt,
  });

  factory GarageRequestStatusChange.fromJson(Map<String, dynamic> json) {
    return GarageRequestStatusChange(
      id: _requiredInt(json['id'], 'GarageRequestStatusChange.id'),
      eventType: _nullableString(json['eventType']) ?? 'status_changed',
      previousStatus: _nullableString(
        json['previousStatus'] ?? json['oldStatus'],
      ),
      status: _nullableString(json['status'] ?? json['newStatus']) ?? 'unknown',
      changedAt: _nullableDate(json['changedAt'] ?? json['createdAt']),
    );
  }
}

@immutable
class GarageRequest {
  final int id;
  final String requestNumber;
  final int vehicleId;
  final int? clientId;
  final int? agentId;
  final int? processorAgentId;
  final int? clientCodeId;
  final int? assignedEmployeeId;
  final String status;
  final bool needsEmployeeResponse;
  final bool needsClientResponse;
  final DateTime? lastMessageAt;
  final DateTime? lastClientMessageAt;
  final DateTime? lastEmployeeMessageAt;
  final Map<String, dynamic>? vehicleSnapshot;
  final String? clientComment;
  final int? currentOfferId;
  final DateTime? submittedAt;
  final DateTime? cancelledAt;
  final String? cancelReason;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<GarageRequestStatusChange> statusHistory;
  final List<GarageRequestItem> items;
  final GarageOffer? currentOffer;
  final GarageOrder? order;

  GarageRequest({
    required this.id,
    required this.requestNumber,
    required this.vehicleId,
    required this.clientId,
    required this.agentId,
    required this.processorAgentId,
    required this.clientCodeId,
    required this.assignedEmployeeId,
    required this.status,
    required this.needsEmployeeResponse,
    required this.needsClientResponse,
    required this.lastMessageAt,
    required this.lastClientMessageAt,
    required this.lastEmployeeMessageAt,
    required Map<String, dynamic>? vehicleSnapshot,
    required this.clientComment,
    required this.currentOfferId,
    required this.submittedAt,
    required this.cancelledAt,
    required this.cancelReason,
    required this.createdAt,
    required this.updatedAt,
    List<GarageRequestStatusChange> statusHistory = const [],
    required List<GarageRequestItem> items,
    this.currentOffer,
    this.order,
  }) : vehicleSnapshot = vehicleSnapshot == null
           ? null
           : Map.unmodifiable(vehicleSnapshot),
       statusHistory = List.unmodifiable(statusHistory),
       items = List.unmodifiable(items);

  factory GarageRequest.fromJson(Map<String, dynamic> json) {
    final snapshot = _stringKeyedMap(
      json['vehicleSnapshot'] ?? json['vehicle'],
    );
    final rawItems = json['items'];
    final rawStatusHistory = json['statusHistory'];
    return GarageRequest(
      id: _requiredInt(json['id'], 'GarageRequest.id'),
      requestNumber: _nullableString(json['requestNumber']) ?? '',
      vehicleId: _requiredInt(json['vehicleId'], 'GarageRequest.vehicleId'),
      clientId: _nullableInt(json['clientId']),
      agentId: _nullableInt(json['agentId']),
      processorAgentId: _nullableInt(json['processorAgentId']),
      clientCodeId: _nullableInt(json['clientCodeId']),
      assignedEmployeeId: _nullableInt(json['assignedEmployeeId']),
      status: _nullableString(json['status']) ?? 'draft',
      needsEmployeeResponse: json['needsEmployeeResponse'] == true,
      needsClientResponse: json['needsClientResponse'] == true,
      lastMessageAt: _nullableDate(json['lastMessageAt']),
      lastClientMessageAt: _nullableDate(json['lastClientMessageAt']),
      lastEmployeeMessageAt: _nullableDate(json['lastEmployeeMessageAt']),
      vehicleSnapshot: snapshot.isEmpty ? null : snapshot,
      clientComment: _nullableString(json['clientComment']),
      currentOfferId: _nullableInt(json['currentOfferId']),
      submittedAt: _nullableDate(json['submittedAt']),
      cancelledAt: _nullableDate(json['cancelledAt']),
      cancelReason: _nullableString(json['cancelReason']),
      createdAt: _nullableDate(json['createdAt']),
      updatedAt: _nullableDate(json['updatedAt']),
      statusHistory: rawStatusHistory is List
          ? rawStatusHistory
                .whereType<Map>()
                .map(
                  (event) => GarageRequestStatusChange.fromJson(
                    _stringKeyedMap(event),
                  ),
                )
                .toList(growable: false)
          : const [],
      items: rawItems is List
          ? rawItems
                .whereType<Map>()
                .map(
                  (item) => GarageRequestItem.fromJson(_stringKeyedMap(item)),
                )
                .toList(growable: false)
          : const [],
      currentOffer: _optionalEntity(
        json['currentOffer'] ?? json['offer'],
        GarageOffer.fromJson,
      ),
      order: _optionalEntity(json['order'], GarageOrder.fromJson),
    );
  }

  GarageRequest copyWith({
    String? status,
    String? clientComment,
    bool clearClientComment = false,
    bool? needsEmployeeResponse,
    bool? needsClientResponse,
    DateTime? submittedAt,
    List<GarageRequestStatusChange>? statusHistory,
    List<GarageRequestItem>? items,
    GarageOffer? currentOffer,
    GarageOrder? order,
  }) {
    return GarageRequest(
      id: id,
      requestNumber: requestNumber,
      vehicleId: vehicleId,
      clientId: clientId,
      agentId: agentId,
      processorAgentId: processorAgentId,
      clientCodeId: clientCodeId,
      assignedEmployeeId: assignedEmployeeId,
      status: status ?? this.status,
      needsEmployeeResponse:
          needsEmployeeResponse ?? this.needsEmployeeResponse,
      needsClientResponse: needsClientResponse ?? this.needsClientResponse,
      lastMessageAt: lastMessageAt,
      lastClientMessageAt: lastClientMessageAt,
      lastEmployeeMessageAt: lastEmployeeMessageAt,
      vehicleSnapshot: vehicleSnapshot,
      clientComment: clearClientComment
          ? null
          : (clientComment ?? this.clientComment),
      currentOfferId: currentOfferId,
      submittedAt: submittedAt ?? this.submittedAt,
      cancelledAt: cancelledAt,
      cancelReason: cancelReason,
      createdAt: createdAt,
      updatedAt: updatedAt,
      statusHistory: statusHistory ?? this.statusHistory,
      items: items ?? this.items,
      currentOffer: currentOffer ?? this.currentOffer,
      order: order ?? this.order,
    );
  }
}

const List<String> canonicalGarageRequestStatusOrder = [
  'draft',
  'new',
  'in_progress',
  'pending_confirmation',
  'unpaid',
  'payment_review',
  'paid',
];

const Set<String> canonicalGarageRequestStatuses = {
  ...canonicalGarageRequestStatusOrder,
};

String canonicalGarageRequestStatus(String status, {GarageOrder? order}) {
  final orderStatus = order?.status.trim().toLowerCase();
  final invoiceStatus = order?.invoice?.status.trim().toLowerCase();
  if (order?.paidAt != null ||
      order?.invoice?.paidAt != null ||
      orderStatus == 'paid' ||
      invoiceStatus == 'paid') {
    return 'paid';
  }
  if (orderStatus == 'payment_review' || invoiceStatus == 'payment_review') {
    return 'payment_review';
  }
  if (orderStatus == 'awaiting_payment' ||
      invoiceStatus == 'unpaid' ||
      invoiceStatus == 'awaiting_payment') {
    return 'unpaid';
  }

  return switch (status.trim().toLowerCase()) {
    'submitted' => 'new',
    'in_review' || 'needs_clarification' => 'in_progress',
    'offer_ready' || 'offer_expired' => 'pending_confirmation',
    'converted_to_order' || 'awaiting_payment' => 'unpaid',
    final normalized => normalized,
  };
}

@immutable
class GarageRequestStatusDefinition {
  final String code;
  final String nameRu;
  final String? color;
  final int sortOrder;

  const GarageRequestStatusDefinition({
    required this.code,
    required this.nameRu,
    required this.color,
    required this.sortOrder,
  });
}

@immutable
class GarageMessageAttachment {
  final int id;
  final String fileName;
  final String fileType;
  final int fileSize;
  final String url;
  final String? thumbnailUrl;

  const GarageMessageAttachment({
    required this.id,
    required this.fileName,
    required this.fileType,
    required this.fileSize,
    required this.url,
    this.thumbnailUrl,
  });

  bool get isImage => fileType.startsWith('image/');

  factory GarageMessageAttachment.fromJson(Map<String, dynamic> json) {
    return GarageMessageAttachment(
      id: _requiredInt(json['id'], 'GarageMessageAttachment.id'),
      fileName: _nullableString(json['fileName']) ?? '',
      fileType: _nullableString(json['fileType']) ?? 'application/octet-stream',
      fileSize: _nullableInt(json['fileSize']) ?? 0,
      url: _nullableString(json['url']) ?? '',
      thumbnailUrl: _nullableString(json['thumbnailUrl']),
    );
  }
}

@immutable
class GarageRequestMessage {
  final int id;
  final int requestId;
  final String senderType;
  final int? senderId;
  final String senderName;
  final String messageType;
  final String? requiresResponseFrom;
  final String content;
  final String? contentRu;
  final int? replyToMessageId;
  final DateTime? resolvedAt;
  final int? resolvedByClientId;
  final int? resolvedByEmployeeId;
  final DateTime? createdAt;
  final List<GarageMessageAttachment> attachments;

  GarageRequestMessage({
    required this.id,
    required this.requestId,
    required this.senderType,
    required this.senderId,
    required this.senderName,
    required this.messageType,
    required this.requiresResponseFrom,
    required this.content,
    required this.contentRu,
    required this.replyToMessageId,
    required this.resolvedAt,
    required this.resolvedByClientId,
    required this.resolvedByEmployeeId,
    required this.createdAt,
    List<GarageMessageAttachment> attachments = const [],
  }) : attachments = List.unmodifiable(attachments);

  factory GarageRequestMessage.fromJson(Map<String, dynamic> json) {
    return GarageRequestMessage(
      id: _requiredInt(json['id'], 'GarageRequestMessage.id'),
      requestId: _requiredInt(
        json['requestId'],
        'GarageRequestMessage.requestId',
      ),
      senderType: _nullableString(json['senderType']) ?? 'employee',
      senderId: _nullableInt(json['senderId']),
      senderName: _nullableString(json['senderName']) ?? 'Сотрудник',
      messageType: _nullableString(json['messageType']) ?? 'comment',
      requiresResponseFrom: _nullableString(json['requiresResponseFrom']),
      content: _nullableString(json['content']) ?? '',
      contentRu: _nullableString(json['contentRu']),
      replyToMessageId: _nullableInt(json['replyToMessageId']),
      resolvedAt: _nullableDate(json['resolvedAt']),
      resolvedByClientId: _nullableInt(json['resolvedByClientId']),
      resolvedByEmployeeId: _nullableInt(json['resolvedByEmployeeId']),
      createdAt: _nullableDate(json['createdAt']),
      attachments: json['attachments'] is List
          ? (json['attachments'] as List)
                .whereType<Map>()
                .map(
                  (attachment) => GarageMessageAttachment.fromJson(
                    _stringKeyedMap(attachment),
                  ),
                )
                .toList(growable: false)
          : const [],
    );
  }

  bool get isFromClient => senderType == 'client';

  String get displayContent {
    if (isFromClient) return content;
    return _trimmedOrNull(contentRu) ?? content;
  }

  bool get awaitsClientAnswer =>
      messageType == 'question' &&
      requiresResponseFrom == 'client' &&
      resolvedAt == null;
}

@immutable
class GarageMessagePage {
  final List<GarageRequestMessage> messages;
  final int? nextCursor;
  final int unreadCount;
  final int? lastReadMessageId;

  GarageMessagePage({
    required List<GarageRequestMessage> messages,
    required this.nextCursor,
    required this.unreadCount,
    required this.lastReadMessageId,
  }) : messages = List.unmodifiable(messages);

  factory GarageMessagePage.fromJson(Map<String, dynamic> json) {
    final rawMessages = json['messages'];
    return GarageMessagePage(
      messages: rawMessages is List
          ? rawMessages
                .whereType<Map>()
                .map(
                  (message) =>
                      GarageRequestMessage.fromJson(_stringKeyedMap(message)),
                )
                .toList(growable: false)
          : const [],
      nextCursor: _nullableInt(json['nextCursor']),
      unreadCount: _nullableInt(json['unreadCount']) ?? 0,
      lastReadMessageId: _nullableInt(json['lastReadMessageId']),
    );
  }

  GarageMessagePage append(GarageMessagePage page) {
    final byId = <int, GarageRequestMessage>{
      for (final message in messages) message.id: message,
      for (final message in page.messages) message.id: message,
    };
    final merged = byId.values.toList()
      ..sort((left, right) => left.id.compareTo(right.id));
    return GarageMessagePage(
      messages: merged,
      nextCursor: page.nextCursor,
      unreadCount: page.unreadCount,
      lastReadMessageId: page.lastReadMessageId ?? lastReadMessageId,
    );
  }
}

@immutable
class GarageMessageReadCursor {
  final int lastReadMessageId;
  final DateTime? lastReadAt;

  const GarageMessageReadCursor({
    required this.lastReadMessageId,
    required this.lastReadAt,
  });

  factory GarageMessageReadCursor.fromJson(Map<String, dynamic> json) {
    return GarageMessageReadCursor(
      lastReadMessageId: _requiredInt(
        json['lastReadMessageId'],
        'GarageMessageReadCursor.lastReadMessageId',
      ),
      lastReadAt: _nullableDate(json['lastReadAt']),
    );
  }
}

@immutable
class GaragePartOption {
  final int id;
  final int offerId;
  final int requestItemId;
  final String manufacturer;
  final String? manufacturerRu;
  final String partNumber;
  final String optionType;
  final String? imageUrl;
  final List<String> imageUrls;
  final String? description;
  final String? descriptionRu;
  final String? supplierUrl;
  final String availabilityStatus;
  final int? estimatedPurchaseDays;
  final double clientUnitPriceCny;
  final double clientUnitPriceRub;
  final double chinaDeliveryCny;
  final double serviceFeeCny;
  final String? employeeComment;
  final String? employeeCommentRu;

  const GaragePartOption({
    required this.id,
    required this.offerId,
    required this.requestItemId,
    required this.manufacturer,
    required this.manufacturerRu,
    required this.partNumber,
    required this.optionType,
    required this.imageUrl,
    this.imageUrls = const [],
    required this.description,
    required this.descriptionRu,
    required this.supplierUrl,
    required this.availabilityStatus,
    required this.estimatedPurchaseDays,
    required this.clientUnitPriceCny,
    required this.clientUnitPriceRub,
    required this.chinaDeliveryCny,
    required this.serviceFeeCny,
    required this.employeeComment,
    required this.employeeCommentRu,
  });

  factory GaragePartOption.fromJson(Map<String, dynamic> json) {
    final imageUrls = _garageImageUrls(json['imageUrls'], json['imageUrl']);
    return GaragePartOption(
      id: _requiredInt(json['id'], 'GaragePartOption.id'),
      offerId: _nullableInt(json['offerId']) ?? 0,
      requestItemId: _requiredInt(
        json['requestItemId'],
        'GaragePartOption.requestItemId',
      ),
      manufacturer: _nullableString(json['manufacturer']) ?? '',
      manufacturerRu: _nullableString(json['manufacturerRu']),
      partNumber: _nullableString(json['partNumber']) ?? '',
      optionType: _nullableString(json['optionType']) ?? '',
      imageUrl: imageUrls.isEmpty ? null : imageUrls.first,
      imageUrls: imageUrls,
      description: _nullableString(json['description']),
      descriptionRu: _nullableString(json['descriptionRu']),
      supplierUrl: _nullableString(json['supplierUrl']),
      availabilityStatus:
          _nullableString(json['availabilityStatus']) ?? 'unknown',
      estimatedPurchaseDays: _nullableInt(json['estimatedPurchaseDays']),
      clientUnitPriceCny:
          _nullableDouble(json['clientUnitPriceCny'] ?? json['unitPriceCny']) ??
          0,
      clientUnitPriceRub: _nullableDouble(json['clientUnitPriceRub']) ?? 0,
      chinaDeliveryCny: _nullableDouble(json['chinaDeliveryCny']) ?? 0,
      serviceFeeCny: _nullableDouble(json['serviceFeeCny']) ?? 0,
      employeeComment: _nullableString(json['employeeComment']),
      employeeCommentRu: _nullableString(json['employeeCommentRu']),
    );
  }

  String get displayManufacturer =>
      _trimmedOrNull(manufacturerRu) ?? manufacturer;

  String? get displayDescription =>
      _trimmedOrNull(descriptionRu) ?? _trimmedOrNull(description);

  String? get displayEmployeeComment =>
      _trimmedOrNull(employeeCommentRu) ?? _trimmedOrNull(employeeComment);
}

@immutable
class GarageOffer {
  final int id;
  final int requestId;
  final int version;
  final String status;
  final double clientCnyRubRateSnapshot;
  final double sharedChinaDeliveryCny;
  final double sharedServiceFeeCny;
  final double discountCny;
  final DateTime? validUntil;
  final DateTime? publishedAt;
  final DateTime? acceptedAt;
  final List<GaragePartOption> options;

  GarageOffer({
    required this.id,
    required this.requestId,
    required this.version,
    required this.status,
    required this.clientCnyRubRateSnapshot,
    required this.sharedChinaDeliveryCny,
    required this.sharedServiceFeeCny,
    required this.discountCny,
    required this.validUntil,
    required this.publishedAt,
    required this.acceptedAt,
    required List<GaragePartOption> options,
  }) : options = List.unmodifiable(options);

  factory GarageOffer.fromJson(Map<String, dynamic> json) {
    final rawOptions = <Object?>[
      if (json['options'] is List) ...(json['options'] as List),
      if (json['items'] is List)
        for (final rawItem in json['items'] as List)
          if (rawItem is Map && rawItem['options'] is List)
            ...(rawItem['options'] as List),
    ];
    return GarageOffer(
      id: _requiredInt(json['id'], 'GarageOffer.id'),
      requestId: _nullableInt(json['requestId']) ?? 0,
      version: _nullableInt(json['version']) ?? 1,
      status: _nullableString(json['status']) ?? 'published',
      clientCnyRubRateSnapshot:
          _nullableDouble(
            json['clientCnyRubRateSnapshot'] ?? json['cnyRubRate'],
          ) ??
          0,
      sharedChinaDeliveryCny:
          _nullableDouble(json['sharedChinaDeliveryCny']) ?? 0,
      sharedServiceFeeCny: _nullableDouble(json['sharedServiceFeeCny']) ?? 0,
      discountCny: _nullableDouble(json['discountCny']) ?? 0,
      validUntil: _nullableDate(json['validUntil']),
      publishedAt: _nullableDate(json['publishedAt']),
      acceptedAt: _nullableDate(json['acceptedAt']),
      options: rawOptions
          .whereType<Map>()
          .map((value) => GaragePartOption.fromJson(_stringKeyedMap(value)))
          .toList(growable: false),
    );
  }

  List<GaragePartOption> optionsFor(int requestItemId) => options
      .where((option) => option.requestItemId == requestItemId)
      .toList(growable: false);

  bool get isExpired =>
      status == 'expired' ||
      (validUntil != null && validUntil!.isBefore(DateTime.now()));
}

@immutable
class GarageOfferSelection {
  final int requestItemId;
  final int optionId;
  final int quantity;

  const GarageOfferSelection({
    required this.requestItemId,
    required this.optionId,
    required this.quantity,
  }) : assert(quantity > 0 && quantity <= 999);

  factory GarageOfferSelection.fromJson(Map<String, dynamic> json) {
    return GarageOfferSelection(
      requestItemId: _requiredInt(
        json['requestItemId'],
        'GarageOfferSelection.requestItemId',
      ),
      optionId: _requiredInt(
        json['optionId'] ?? json['selectedOptionId'],
        'GarageOfferSelection.optionId',
      ),
      quantity: _nullableInt(json['quantity']) ?? 1,
    );
  }

  GarageOfferSelection copyWith({int? quantity}) {
    return GarageOfferSelection(
      requestItemId: requestItemId,
      optionId: optionId,
      quantity: quantity ?? this.quantity,
    );
  }

  Map<String, dynamic> toJson() => {
    'requestItemId': requestItemId,
    'optionId': optionId,
    'quantity': quantity,
  };
}

@immutable
class GarageOfferCalculation {
  final int offerId;
  final List<GarageOfferSelection> selections;
  final double goodsTotalCny;
  final double chinaDeliveryTotalCny;
  final double serviceFeeTotalCny;
  final double discountCny;
  final double totalCny;
  final double cnyRubRate;
  final double totalRub;

  GarageOfferCalculation({
    required this.offerId,
    required List<GarageOfferSelection> selections,
    required this.goodsTotalCny,
    required this.chinaDeliveryTotalCny,
    required this.serviceFeeTotalCny,
    required this.discountCny,
    required this.totalCny,
    required this.cnyRubRate,
    required this.totalRub,
  }) : selections = List.unmodifiable(selections);

  factory GarageOfferCalculation.fromJson(Map<String, dynamic> json) {
    final rawSelections = json['selections'] ?? json['selectedOptionIds'];
    final totals = _stringKeyedMap(json['totals']);
    final selections = <GarageOfferSelection>[];
    if (rawSelections is Map) {
      for (final entry in rawSelections.entries) {
        final requestItemId = int.tryParse(entry.key.toString());
        final rawValue = entry.value;
        final valueMap = _stringKeyedMap(rawValue);
        final optionId = _nullableInt(
          valueMap['optionId'] ?? valueMap['selectedOptionId'] ?? rawValue,
        );
        final quantity = _nullableInt(valueMap['quantity']) ?? 1;
        if (requestItemId != null && optionId != null) {
          selections.add(
            GarageOfferSelection(
              requestItemId: requestItemId,
              optionId: optionId,
              quantity: quantity,
            ),
          );
        }
      }
    } else if (rawSelections is List) {
      for (final value in rawSelections.whereType<Map>()) {
        final selection = _stringKeyedMap(value);
        final requestItemId = _nullableInt(selection['requestItemId']);
        final optionId = _nullableInt(
          selection['optionId'] ?? selection['selectedOptionId'],
        );
        if (requestItemId != null && optionId != null) {
          selections.add(
            GarageOfferSelection(
              requestItemId: requestItemId,
              optionId: optionId,
              quantity: _nullableInt(selection['quantity']) ?? 1,
            ),
          );
        }
      }
    }
    return GarageOfferCalculation(
      offerId: _nullableInt(json['offerId']) ?? 0,
      selections: selections,
      goodsTotalCny:
          _nullableDouble(totals['goodsTotalCny'] ?? json['goodsTotalCny']) ??
          0,
      chinaDeliveryTotalCny:
          _nullableDouble(
            totals['chinaDeliveryTotalCny'] ?? json['chinaDeliveryTotalCny'],
          ) ??
          0,
      serviceFeeTotalCny:
          _nullableDouble(
            totals['serviceFeeTotalCny'] ?? json['serviceFeeTotalCny'],
          ) ??
          0,
      discountCny:
          _nullableDouble(totals['discountCny'] ?? json['discountCny']) ?? 0,
      totalCny: _nullableDouble(totals['totalCny'] ?? json['totalCny']) ?? 0,
      cnyRubRate:
          _nullableDouble(
            totals['clientCnyRubRateSnapshot'] ??
                json['clientCnyRubRateSnapshot'] ??
                json['cnyRubRate'],
          ) ??
          0,
      totalRub: _nullableDouble(totals['totalRub'] ?? json['totalRub']) ?? 0,
    );
  }
}

@immutable
class GarageInvoice {
  final int id;
  final String invoiceNumber;
  final int orderId;
  final String status;
  final double clientCnyRubRateSnapshot;
  final double totalCny;
  final double totalRub;
  final int? activePaymentId;
  final ClientPaymentSummary? paymentSummary;
  final ClientActiveTopUp? activeTopUp;
  final DateTime? issuedAt;
  final DateTime? paidAt;
  final DateTime? cancelledAt;

  const GarageInvoice({
    required this.id,
    required this.invoiceNumber,
    required this.orderId,
    required this.status,
    required this.clientCnyRubRateSnapshot,
    required this.totalCny,
    required this.totalRub,
    required this.activePaymentId,
    this.paymentSummary,
    this.activeTopUp,
    required this.issuedAt,
    required this.paidAt,
    required this.cancelledAt,
  });

  factory GarageInvoice.fromJson(Map<String, dynamic> json) {
    return GarageInvoice(
      id: _requiredInt(json['id'], 'GarageInvoice.id'),
      invoiceNumber: _nullableString(json['invoiceNumber']) ?? '',
      orderId: _requiredInt(json['orderId'], 'GarageInvoice.orderId'),
      status: _nullableString(json['status']) ?? 'unpaid',
      clientCnyRubRateSnapshot:
          _nullableDouble(json['clientCnyRubRateSnapshot']) ?? 0,
      totalCny: _nullableDouble(json['totalCny']) ?? 0,
      totalRub: _nullableDouble(json['totalRub']) ?? 0,
      activePaymentId: _nullableInt(json['activePaymentId']),
      paymentSummary: ClientPaymentSummary.tryParse(json['paymentSummary']),
      activeTopUp: ClientActiveTopUp.tryParse(json['activeTopUp']),
      issuedAt: _nullableDate(json['issuedAt'] ?? json['createdAt']),
      paidAt: _nullableDate(json['paidAt']),
      cancelledAt: _nullableDate(json['cancelledAt']),
    );
  }
}

@immutable
class GarageOrderItem {
  final int id;
  final int orderId;
  final int requestItemId;
  final int selectedOptionId;
  final String partName;
  final String manufacturer;
  final String? manufacturerRu;
  final String partNumber;
  final String optionType;
  final String? imageUrl;
  final List<String> imageUrls;
  final String? description;
  final String? descriptionRu;
  final int quantity;
  final double clientUnitPriceCny;
  final double clientUnitPriceRub;
  final double lineTotalCny;
  final double lineTotalRub;
  final String purchaseStatus;
  final String? supplierOrderNumber;
  final DateTime? purchasedAt;

  const GarageOrderItem({
    required this.id,
    required this.orderId,
    required this.requestItemId,
    required this.selectedOptionId,
    required this.partName,
    required this.manufacturer,
    required this.manufacturerRu,
    required this.partNumber,
    required this.optionType,
    required this.imageUrl,
    this.imageUrls = const [],
    required this.description,
    required this.descriptionRu,
    required this.quantity,
    required this.clientUnitPriceCny,
    required this.clientUnitPriceRub,
    required this.lineTotalCny,
    required this.lineTotalRub,
    required this.purchaseStatus,
    required this.supplierOrderNumber,
    required this.purchasedAt,
  });

  factory GarageOrderItem.fromJson(Map<String, dynamic> json) {
    final selectedOption = _stringKeyedMap(
      json['selectedOption'] ?? json['option'],
    );
    final imageUrls = _garageImageUrls(
      json['imageUrlsSnapshot'] ??
          json['imageUrls'] ??
          selectedOption['imageUrls'],
      json['imageUrlSnapshot'] ??
          json['imageUrl'] ??
          selectedOption['imageUrl'],
    );
    return GarageOrderItem(
      id: _requiredInt(json['id'], 'GarageOrderItem.id'),
      orderId: _nullableInt(json['orderId']) ?? 0,
      requestItemId: _nullableInt(json['requestItemId']) ?? 0,
      selectedOptionId:
          _nullableInt(json['selectedOptionId'] ?? selectedOption['id']) ?? 0,
      partName:
          _nullableString(json['partNameSnapshot'] ?? json['partName']) ?? '',
      manufacturer:
          _nullableString(
            json['manufacturerSnapshot'] ??
                json['manufacturer'] ??
                selectedOption['manufacturer'],
          ) ??
          '',
      manufacturerRu: _nullableString(
        json['manufacturerRu'] ?? selectedOption['manufacturerRu'],
      ),
      partNumber:
          _nullableString(
            json['partNumberSnapshot'] ??
                json['partNumber'] ??
                selectedOption['partNumber'],
          ) ??
          '',
      optionType:
          _nullableString(
            json['optionTypeSnapshot'] ??
                json['optionType'] ??
                selectedOption['optionType'],
          ) ??
          '',
      imageUrl: imageUrls.isEmpty ? null : imageUrls.first,
      imageUrls: imageUrls,
      description: _nullableString(
        json['descriptionSnapshot'] ??
            json['description'] ??
            selectedOption['description'],
      ),
      descriptionRu: _nullableString(
        json['descriptionRu'] ?? selectedOption['descriptionRu'],
      ),
      quantity: _nullableInt(json['quantitySnapshot'] ?? json['quantity']) ?? 1,
      clientUnitPriceCny:
          _nullableDouble(
            json['clientUnitPriceCnySnapshot'] ?? json['clientUnitPriceCny'],
          ) ??
          0,
      clientUnitPriceRub:
          _nullableDouble(
            json['clientUnitPriceRubSnapshot'] ?? json['clientUnitPriceRub'],
          ) ??
          0,
      lineTotalCny: _nullableDouble(json['lineTotalCny']) ?? 0,
      lineTotalRub: _nullableDouble(json['lineTotalRub']) ?? 0,
      purchaseStatus: _nullableString(json['purchaseStatus']) ?? 'pending',
      supplierOrderNumber: _nullableString(json['supplierOrderNumber']),
      purchasedAt: _nullableDate(json['purchasedAt']),
    );
  }
}

@immutable
class GarageOrder {
  final int id;
  final String orderNumber;
  final int requestId;
  final String? requestNumber;
  final String status;
  final double clientCnyRubRateSnapshot;
  final double goodsTotalCny;
  final double chinaDeliveryTotalCny;
  final double serviceFeeTotalCny;
  final double discountCny;
  final double totalCny;
  final double totalRub;
  final String refundState;
  final double refundedAmountRub;
  final Map<String, dynamic>? vehicleSnapshot;
  final GarageInvoice? invoice;
  final List<GarageOrderItem> items;
  final DateTime? paidAt;
  final DateTime? purchasingStartedAt;
  final DateTime? purchasedAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  GarageOrder({
    required this.id,
    required this.orderNumber,
    required this.requestId,
    required this.requestNumber,
    required this.status,
    required this.clientCnyRubRateSnapshot,
    required this.goodsTotalCny,
    required this.chinaDeliveryTotalCny,
    required this.serviceFeeTotalCny,
    required this.discountCny,
    required this.totalCny,
    required this.totalRub,
    required this.refundState,
    required this.refundedAmountRub,
    required Map<String, dynamic>? vehicleSnapshot,
    required this.invoice,
    required List<GarageOrderItem> items,
    required this.paidAt,
    required this.purchasingStartedAt,
    required this.purchasedAt,
    required this.completedAt,
    required this.cancelledAt,
    required this.createdAt,
    required this.updatedAt,
  }) : vehicleSnapshot = vehicleSnapshot == null
           ? null
           : Map.unmodifiable(vehicleSnapshot),
       items = List.unmodifiable(items);

  factory GarageOrder.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final vehicle = _stringKeyedMap(json['vehicleSnapshot'] ?? json['vehicle']);
    return GarageOrder(
      id: _requiredInt(json['id'], 'GarageOrder.id'),
      orderNumber: _nullableString(json['orderNumber']) ?? '',
      requestId: _requiredInt(json['requestId'], 'GarageOrder.requestId'),
      requestNumber: _nullableString(json['requestNumber']),
      status: _nullableString(json['status']) ?? 'awaiting_payment',
      clientCnyRubRateSnapshot:
          _nullableDouble(json['clientCnyRubRateSnapshot']) ?? 0,
      goodsTotalCny: _nullableDouble(json['goodsTotalCny']) ?? 0,
      chinaDeliveryTotalCny:
          _nullableDouble(json['chinaDeliveryTotalCny']) ?? 0,
      serviceFeeTotalCny: _nullableDouble(json['serviceFeeTotalCny']) ?? 0,
      discountCny: _nullableDouble(json['discountCny']) ?? 0,
      totalCny: _nullableDouble(json['totalCny']) ?? 0,
      totalRub: _nullableDouble(json['totalRub']) ?? 0,
      refundState: canonicalGarageRefundState(
        _nullableString(json['refundState']),
      ),
      refundedAmountRub: _nullableDouble(json['refundedAmountRub']) ?? 0,
      vehicleSnapshot: vehicle.isEmpty ? null : vehicle,
      invoice: _optionalEntity(json['invoice'], GarageInvoice.fromJson),
      items: rawItems is List
          ? rawItems
                .whereType<Map>()
                .map((item) => GarageOrderItem.fromJson(_stringKeyedMap(item)))
                .toList(growable: false)
          : const [],
      paidAt: _nullableDate(json['paidAt']),
      purchasingStartedAt: _nullableDate(json['purchasingStartedAt']),
      purchasedAt: _nullableDate(json['purchasedAt']),
      completedAt: _nullableDate(json['completedAt']),
      cancelledAt: _nullableDate(json['cancelledAt']),
      createdAt: _nullableDate(json['createdAt']),
      updatedAt: _nullableDate(json['updatedAt']),
    );
  }
}

String canonicalGarageRefundState(String? value) {
  return switch (value?.trim().toLowerCase()) {
    null || '' || 'none' || 'not_refunded' => 'not_refunded',
    final normalized => normalized,
  };
}

@immutable
class GarageAcceptResult {
  final GarageOrder order;
  final GarageInvoice invoice;

  const GarageAcceptResult({required this.order, required this.invoice});

  factory GarageAcceptResult.fromJson(Map<String, dynamic> json) {
    final order = _stringKeyedMap(json['order'] ?? json['garageOrder']);
    final invoice = _stringKeyedMap(
      json['invoice'] ?? json['garageInvoice'] ?? order['invoice'],
    );
    return GarageAcceptResult(
      order: GarageOrder.fromJson(order),
      invoice: GarageInvoice.fromJson(invoice),
    );
  }
}

@immutable
class GarageBankQrPayment {
  final int paymentId;
  final int garageInvoiceId;
  final String invoiceNumber;
  final double amountRub;
  final int sumKopecks;
  final String purpose;
  final String qrPayload;
  final String status;
  final bool reused;

  const GarageBankQrPayment({
    required this.paymentId,
    required this.garageInvoiceId,
    required this.invoiceNumber,
    required this.amountRub,
    required this.sumKopecks,
    required this.purpose,
    required this.qrPayload,
    required this.status,
    required this.reused,
  });

  factory GarageBankQrPayment.fromJson(Map<String, dynamic> json) {
    return GarageBankQrPayment(
      paymentId: _requiredInt(json['paymentId'], 'GaragePayment.paymentId'),
      garageInvoiceId:
          _nullableInt(json['garageInvoiceId'] ?? json['invoiceId']) ?? 0,
      invoiceNumber: _nullableString(json['invoiceNumber']) ?? '',
      amountRub: _nullableDouble(json['amountRub']) ?? 0,
      sumKopecks: _nullableInt(json['sumKopecks']) ?? 0,
      purpose: _nullableString(json['purpose']) ?? '',
      qrPayload: _nullableString(json['qrPayload']) ?? '',
      status: _nullableString(json['status']) ?? 'pending',
      reused: json['reused'] == true,
    );
  }
}

@immutable
class GarageReceiptUploadResult {
  final int receiptId;
  final int paymentId;
  final String invoiceStatus;

  const GarageReceiptUploadResult({
    required this.receiptId,
    required this.paymentId,
    required this.invoiceStatus,
  });

  factory GarageReceiptUploadResult.fromJson(Map<String, dynamic> json) {
    return GarageReceiptUploadResult(
      receiptId: _requiredInt(json['receiptId'], 'GarageReceipt.receiptId'),
      paymentId: _requiredInt(json['paymentId'], 'GarageReceipt.paymentId'),
      invoiceStatus: _nullableString(json['invoiceStatus']) ?? 'payment_review',
    );
  }
}

@immutable
class GarageRefundRequest {
  final int id;
  final int orderId;
  final String reason;
  final List<int> requestedOrderItemIds;
  final String status;
  final String? reviewComment;
  final DateTime? createdAt;
  final DateTime? reviewedAt;

  GarageRefundRequest({
    required this.id,
    required this.orderId,
    required this.reason,
    required List<int> requestedOrderItemIds,
    required this.status,
    required this.reviewComment,
    required this.createdAt,
    required this.reviewedAt,
  }) : requestedOrderItemIds = List.unmodifiable(requestedOrderItemIds);

  factory GarageRefundRequest.fromJson(Map<String, dynamic> json) {
    final rawIds = json['requestedOrderItemIds'];
    return GarageRefundRequest(
      id: _requiredInt(json['id'], 'GarageRefundRequest.id'),
      orderId: _requiredInt(json['orderId'], 'GarageRefundRequest.orderId'),
      reason: _nullableString(json['reason']) ?? '',
      requestedOrderItemIds: rawIds is List
          ? rawIds.map(_nullableInt).whereType<int>().toList(growable: false)
          : const [],
      status: _nullableString(json['status']) ?? 'pending',
      reviewComment: _nullableString(json['reviewComment']),
      createdAt: _nullableDate(json['createdAt']),
      reviewedAt: _nullableDate(json['reviewedAt']),
    );
  }
}

int _requiredInt(Object? value, String fieldName) {
  final parsed = _nullableInt(value);
  if (parsed == null) {
    throw FormatException('$fieldName is required');
  }
  return parsed;
}

int? _nullableInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

double? _nullableDouble(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}

String? _nullableString(Object? value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

List<String> _garageImageUrls(Object? value, Object? legacyImageUrl) {
  final urls = <String>[];
  if (value is List) {
    for (final item in value) {
      final url = _nullableString(item);
      if (url != null && !urls.contains(url)) urls.add(url);
    }
  }
  final legacy = _nullableString(legacyImageUrl);
  if (legacy != null && !urls.contains(legacy)) urls.insert(0, legacy);
  return List<String>.unmodifiable(urls);
}

String? _trimmedOrNull(String? value) {
  final text = value?.trim();
  return text == null || text.isEmpty ? null : text;
}

DateTime? _nullableDate(Object? value) {
  if (value is DateTime) return value;
  return DateTime.tryParse(value?.toString() ?? '');
}

Map<String, dynamic> _stringKeyedMap(Object? value) {
  if (value is! Map) return const {};
  return {for (final entry in value.entries) entry.key.toString(): entry.value};
}

T? _optionalEntity<T>(Object? value, T Function(Map<String, dynamic>) parser) {
  if (value is! Map) return null;
  final map = _stringKeyedMap(value);
  if (map.isEmpty) return null;
  return parser(map);
}
