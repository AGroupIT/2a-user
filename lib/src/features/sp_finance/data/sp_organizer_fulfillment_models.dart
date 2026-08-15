Map<String, dynamic> _mapValue(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : const {};

List<Map<String, dynamic>> _mapList(dynamic value) => value is List
    ? value
          .whereType<Map>()
          .map(Map<String, dynamic>.from)
          .toList(growable: false)
    : const [];

String? _stringValue(dynamic value) {
  if (value is! String) return null;
  final normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}

int _intValue(dynamic value, [int fallback = 0]) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

double _doubleValue(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.replaceAll(',', '.')) ?? 0;
  return 0;
}

bool _boolValue(dynamic value, [bool fallback = false]) =>
    value is bool ? value : fallback;

DateTime _dateTimeValue(dynamic value) {
  if (value is DateTime) return value;
  if (value is String) {
    final parsed = DateTime.tryParse(value);
    if (parsed != null) return parsed;
  }
  return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
}

double? _nullableDoubleValue(dynamic value) {
  if (value == null) return null;
  return _doubleValue(value);
}

class SpOrganizerFulfillmentItem {
  final int id;
  final String title;

  const SpOrganizerFulfillmentItem({required this.id, required this.title});

  factory SpOrganizerFulfillmentItem.fromJson(Map<String, dynamic> json) {
    return SpOrganizerFulfillmentItem(
      id: _intValue(json['id']),
      title: _stringValue(json['title']) ?? '',
    );
  }
}

class SpOrganizerFulfillmentStatus {
  final String code;
  final String nameRu;
  final String? nameZh;
  final String? color;
  final String? icon;
  final int sortOrder;

  const SpOrganizerFulfillmentStatus({
    required this.code,
    required this.nameRu,
    this.nameZh,
    this.color,
    this.icon,
    this.sortOrder = 1000000,
  });

  String labelFor(String languageCode) {
    if (languageCode == 'zh' && nameZh != null) return nameZh!;
    return nameRu;
  }

  factory SpOrganizerFulfillmentStatus.fromJson(Map<String, dynamic> json) {
    final code = _stringValue(json['code']) ?? 'unknown';
    return SpOrganizerFulfillmentStatus(
      code: code,
      nameRu: _stringValue(json['nameRu']) ?? code,
      nameZh: _stringValue(json['nameZh']),
      color: _stringValue(json['color']),
      icon: _stringValue(json['icon']),
      sortOrder: _intValue(json['sortOrder'], 1000000),
    );
  }
}

class SpOrganizerFulfillmentSummary {
  final int itemsCount;
  final int selfBuyoutRequestsCount;
  final int garageOrderItemsCount;
  final int tracksCount;
  final int photosCount;
  final int photoRequestsCount;
  final int assembliesCount;
  final int invoicesCount;

  const SpOrganizerFulfillmentSummary({
    this.itemsCount = 0,
    this.selfBuyoutRequestsCount = 0,
    this.garageOrderItemsCount = 0,
    this.tracksCount = 0,
    this.photosCount = 0,
    this.photoRequestsCount = 0,
    this.assembliesCount = 0,
    this.invoicesCount = 0,
  });

  bool get hasLinks =>
      selfBuyoutRequestsCount > 0 ||
      garageOrderItemsCount > 0 ||
      tracksCount > 0 ||
      assembliesCount > 0 ||
      invoicesCount > 0;

  factory SpOrganizerFulfillmentSummary.fromJson(Map<String, dynamic> json) {
    return SpOrganizerFulfillmentSummary(
      itemsCount: _intValue(json['itemsCount']),
      selfBuyoutRequestsCount: _intValue(json['selfBuyoutRequestsCount']),
      garageOrderItemsCount: _intValue(json['garageOrderItemsCount']),
      tracksCount: _intValue(json['tracksCount']),
      photosCount: _intValue(json['photosCount']),
      photoRequestsCount: _intValue(json['photoRequestsCount']),
      assembliesCount: _intValue(json['assembliesCount']),
      invoicesCount: _intValue(json['invoicesCount']),
    );
  }
}

class SpOrganizerSelfBuyoutFulfillment {
  final int itemId;
  final String itemTitle;
  final int requestId;
  final String requestNumber;
  final SpOrganizerFulfillmentStatus status;

  const SpOrganizerSelfBuyoutFulfillment({
    required this.itemId,
    required this.itemTitle,
    required this.requestId,
    required this.requestNumber,
    required this.status,
  });

  factory SpOrganizerSelfBuyoutFulfillment.fromJson(Map<String, dynamic> json) {
    final request = _mapValue(json['request']);
    return SpOrganizerSelfBuyoutFulfillment(
      itemId: _intValue(json['itemId']),
      itemTitle: _stringValue(json['itemTitle']) ?? '',
      requestId: _intValue(request['id']),
      requestNumber: _stringValue(request['requestNumber']) ?? '',
      status: SpOrganizerFulfillmentStatus.fromJson(
        _mapValue(request['status']),
      ),
    );
  }
}

class SpOrganizerGarageFulfillment {
  final int itemId;
  final String itemTitle;
  final int orderItemId;
  final String partName;
  final String orderNumber;
  final SpOrganizerFulfillmentStatus status;

  const SpOrganizerGarageFulfillment({
    required this.itemId,
    required this.itemTitle,
    required this.orderItemId,
    required this.partName,
    required this.orderNumber,
    required this.status,
  });

  factory SpOrganizerGarageFulfillment.fromJson(Map<String, dynamic> json) {
    final orderItem = _mapValue(json['orderItem']);
    final order = _mapValue(orderItem['order']);
    return SpOrganizerGarageFulfillment(
      itemId: _intValue(json['itemId']),
      itemTitle: _stringValue(json['itemTitle']) ?? '',
      orderItemId: _intValue(orderItem['id']),
      partName: _stringValue(orderItem['partNameSnapshot']) ?? '',
      orderNumber: _stringValue(order['orderNumber']) ?? '',
      status: SpOrganizerFulfillmentStatus.fromJson(_mapValue(order['status'])),
    );
  }
}

class SpOrganizerFulfillmentPhoto {
  final int id;
  final String url;
  final DateTime createdAt;

  const SpOrganizerFulfillmentPhoto({
    required this.id,
    required this.url,
    required this.createdAt,
  });

  factory SpOrganizerFulfillmentPhoto.fromJson(Map<String, dynamic> json) {
    return SpOrganizerFulfillmentPhoto(
      id: _intValue(json['id']),
      url: _stringValue(json['url']) ?? '',
      createdAt: _dateTimeValue(json['createdAt']),
    );
  }
}

class SpOrganizerTrackFulfillment {
  final int itemId;
  final String itemTitle;
  final int trackId;
  final String trackNumber;
  final String source;
  final SpOrganizerFulfillmentStatus status;
  final int photosCount;
  final List<SpOrganizerFulfillmentPhoto> photos;
  final int photoRequestsCount;
  final bool warehouseDelivered;

  const SpOrganizerTrackFulfillment({
    required this.itemId,
    required this.itemTitle,
    required this.trackId,
    required this.trackNumber,
    this.source = 'explicit',
    required this.status,
    this.photosCount = 0,
    this.photos = const [],
    this.photoRequestsCount = 0,
    this.warehouseDelivered = false,
  });

  bool get isAutomaticGarageTrack => source == 'garage_product_info';

  factory SpOrganizerTrackFulfillment.fromJson(Map<String, dynamic> json) {
    final track = _mapValue(json['track']);
    final warehouseDelivery = _mapValue(track['warehouseDelivery']);
    return SpOrganizerTrackFulfillment(
      itemId: _intValue(json['itemId']),
      itemTitle: _stringValue(json['itemTitle']) ?? '',
      trackId: _intValue(track['id']),
      trackNumber: _stringValue(track['trackNumber']) ?? '',
      source: _stringValue(json['source']) ?? 'explicit',
      status: SpOrganizerFulfillmentStatus.fromJson(_mapValue(track['status'])),
      photosCount: _intValue(track['photosCount']),
      photos: _mapList(
        track['photos'],
      ).map(SpOrganizerFulfillmentPhoto.fromJson).toList(growable: false),
      photoRequestsCount: _intValue(track['photoRequestsCount']),
      warehouseDelivered: _boolValue(warehouseDelivery['isDelivered']),
    );
  }
}

class SpOrganizerAssemblyFulfillment {
  final int id;
  final String number;
  final String? name;
  final String source;
  final SpOrganizerFulfillmentStatus status;
  final int tracksCount;
  final int invoicesCount;

  const SpOrganizerAssemblyFulfillment({
    required this.id,
    required this.number,
    this.name,
    required this.source,
    required this.status,
    this.tracksCount = 0,
    this.invoicesCount = 0,
  });

  factory SpOrganizerAssemblyFulfillment.fromJson(Map<String, dynamic> json) {
    return SpOrganizerAssemblyFulfillment(
      id: _intValue(json['id']),
      number: _stringValue(json['number']) ?? '',
      name: _stringValue(json['name']),
      source: _stringValue(json['source']) ?? 'explicit',
      status: SpOrganizerFulfillmentStatus.fromJson(_mapValue(json['status'])),
      tracksCount: _intValue(json['tracksCount']),
      invoicesCount: _intValue(json['invoicesCount']),
    );
  }
}

class SpOrganizerInvoiceFulfillment {
  final int id;
  final String invoiceNumber;
  final String source;
  final SpOrganizerFulfillmentStatus status;
  final double totalCostRub;
  final double totalCostCny;

  const SpOrganizerInvoiceFulfillment({
    required this.id,
    required this.invoiceNumber,
    required this.source,
    required this.status,
    this.totalCostRub = 0,
    this.totalCostCny = 0,
  });

  factory SpOrganizerInvoiceFulfillment.fromJson(Map<String, dynamic> json) {
    return SpOrganizerInvoiceFulfillment(
      id: _intValue(json['id']),
      invoiceNumber: _stringValue(json['invoiceNumber']) ?? '',
      source: _stringValue(json['source']) ?? 'explicit',
      status: SpOrganizerFulfillmentStatus.fromJson(_mapValue(json['status'])),
      totalCostRub: _doubleValue(json['totalCostRUB']),
      totalCostCny: _doubleValue(json['totalCostCNY']),
    );
  }
}

class SpOrganizerFulfillmentOverview {
  final int contractVersion;
  final String mode;
  final bool persisted;
  final int purchaseId;
  final List<SpOrganizerFulfillmentItem> items;
  final SpOrganizerFulfillmentSummary summary;
  final List<SpOrganizerSelfBuyoutFulfillment> selfBuyoutRequests;
  final List<SpOrganizerGarageFulfillment> garageOrderItems;
  final List<SpOrganizerTrackFulfillment> tracks;
  final List<SpOrganizerAssemblyFulfillment> assemblies;
  final List<SpOrganizerInvoiceFulfillment> invoices;
  final List<String> warnings;

  const SpOrganizerFulfillmentOverview({
    required this.contractVersion,
    required this.mode,
    required this.persisted,
    required this.purchaseId,
    required this.summary,
    this.items = const [],
    this.selfBuyoutRequests = const [],
    this.garageOrderItems = const [],
    this.tracks = const [],
    this.assemblies = const [],
    this.invoices = const [],
    this.warnings = const [],
  });

  factory SpOrganizerFulfillmentOverview.fromJson(Map<String, dynamic> json) {
    return SpOrganizerFulfillmentOverview(
      contractVersion: _intValue(json['contractVersion'], 1),
      mode: _stringValue(json['mode']) ?? 'read_only',
      persisted: _boolValue(json['persisted']),
      purchaseId: _intValue(json['purchaseId']),
      items: _mapList(
        json['items'],
      ).map(SpOrganizerFulfillmentItem.fromJson).toList(growable: false),
      summary: SpOrganizerFulfillmentSummary.fromJson(
        _mapValue(json['summary']),
      ),
      selfBuyoutRequests: _mapList(
        json['selfBuyoutRequests'],
      ).map(SpOrganizerSelfBuyoutFulfillment.fromJson).toList(growable: false),
      garageOrderItems: _mapList(
        json['garageOrderItems'],
      ).map(SpOrganizerGarageFulfillment.fromJson).toList(growable: false),
      tracks: _mapList(
        json['tracks'],
      ).map(SpOrganizerTrackFulfillment.fromJson).toList(growable: false),
      assemblies: _mapList(
        json['assemblies'],
      ).map(SpOrganizerAssemblyFulfillment.fromJson).toList(growable: false),
      invoices: _mapList(
        json['invoices'],
      ).map(SpOrganizerInvoiceFulfillment.fromJson).toList(growable: false),
      warnings: json['warnings'] is List
          ? (json['warnings'] as List).whereType<String>().toList(
              growable: false,
            )
          : const [],
    );
  }
}

enum SpOrganizerFulfillmentLinkKind {
  selfBuyout('self-buyout', true),
  garage('garage', true),
  track('track', true),
  assembly('assembly', false),
  invoice('invoice', false);

  final String apiValue;
  final bool itemScoped;

  const SpOrganizerFulfillmentLinkKind(this.apiValue, this.itemScoped);

  static SpOrganizerFulfillmentLinkKind fromApiValue(String value) {
    return values.firstWhere(
      (kind) => kind.apiValue == value,
      orElse: () => SpOrganizerFulfillmentLinkKind.track,
    );
  }
}

class SpOrganizerFulfillmentCandidate {
  final int id;
  final String title;
  final String? subtitle;
  final SpOrganizerFulfillmentStatus status;
  final bool linked;
  final bool legacyLinked;
  final double? amountRub;
  final double? amountCny;

  const SpOrganizerFulfillmentCandidate({
    required this.id,
    required this.title,
    required this.status,
    this.subtitle,
    this.linked = false,
    this.legacyLinked = false,
    this.amountRub,
    this.amountCny,
  });

  factory SpOrganizerFulfillmentCandidate.fromJson(Map<String, dynamic> json) {
    return SpOrganizerFulfillmentCandidate(
      id: _intValue(json['id']),
      title: _stringValue(json['title']) ?? '',
      subtitle: _stringValue(json['subtitle']),
      status: SpOrganizerFulfillmentStatus.fromJson(_mapValue(json['status'])),
      linked: _boolValue(json['linked']),
      legacyLinked: _boolValue(json['legacyLinked']),
      amountRub: _nullableDoubleValue(json['amountRub']),
      amountCny: _nullableDoubleValue(json['amountCny']),
    );
  }
}

class SpOrganizerFulfillmentCandidatePage {
  final SpOrganizerFulfillmentLinkKind kind;
  final List<SpOrganizerFulfillmentCandidate> candidates;
  final int total;
  final int page;
  final int limit;
  final int totalPages;

  const SpOrganizerFulfillmentCandidatePage({
    required this.kind,
    this.candidates = const [],
    this.total = 0,
    this.page = 1,
    this.limit = 20,
    this.totalPages = 0,
  });

  bool get hasMore => page < totalPages;

  factory SpOrganizerFulfillmentCandidatePage.fromJson(
    Map<String, dynamic> json,
  ) {
    final pagination = _mapValue(json['pagination']);
    return SpOrganizerFulfillmentCandidatePage(
      kind: SpOrganizerFulfillmentLinkKind.fromApiValue(
        _stringValue(json['kind']) ?? 'track',
      ),
      candidates: _mapList(
        json['candidates'],
      ).map(SpOrganizerFulfillmentCandidate.fromJson).toList(growable: false),
      total: _intValue(pagination['total']),
      page: _intValue(pagination['page'], 1),
      limit: _intValue(pagination['limit'], 20),
      totalPages: _intValue(pagination['totalPages']),
    );
  }
}
