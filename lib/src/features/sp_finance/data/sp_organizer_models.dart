import 'sp_v2_models.dart';

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
  if (value is String) {
    return double.tryParse(value.replaceAll(',', '.')) ?? 0;
  }
  return 0;
}

bool _boolValue(dynamic value, [bool fallback = false]) =>
    value is bool ? value : fallback;

DateTime? _dateValue(dynamic value) =>
    value is String ? DateTime.tryParse(value) : null;

Map<String, dynamic> _mapValue(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : const {};

List<Map<String, dynamic>> _mapList(dynamic value) => value is List
    ? value
          .whereType<Map>()
          .map(Map<String, dynamic>.from)
          .toList(growable: false)
    : const [];

class SpOrganizerActionCapability {
  final bool available;
  final bool canCreate;
  final String? reason;

  const SpOrganizerActionCapability({
    required this.available,
    required this.canCreate,
    this.reason,
  });

  factory SpOrganizerActionCapability.fromJson(Map<String, dynamic> json) {
    return SpOrganizerActionCapability(
      available: _boolValue(json['available']),
      canCreate: _boolValue(json['canCreate']),
      reason: _stringValue(json['reason']),
    );
  }

  static const unavailable = SpOrganizerActionCapability(
    available: false,
    canCreate: false,
    reason: 'feature_disabled',
  );
}

class SpOrganizerCapabilities {
  final int contractVersion;
  final bool organizerV2;
  final bool purchaseKinds;
  final bool participants;
  final bool products;
  final bool purchaseBlankImport;
  final bool previousPurchaseImport;
  final bool calculationProfiles;
  final bool fulfillmentOverview;
  final bool selfBuyoutLinks;
  final SpOrganizerActionCapability selfBuyout;
  final bool garageImport;
  final bool trackLinks;
  final bool trackImport;
  final bool assemblyLinks;
  final bool invoiceLinks;
  final bool analytics;
  final bool bulkOperations;
  final bool purchaseExport;
  final bool customersDirectory;

  const SpOrganizerCapabilities({
    required this.contractVersion,
    required this.organizerV2,
    required this.purchaseKinds,
    required this.participants,
    required this.products,
    this.purchaseBlankImport = false,
    this.previousPurchaseImport = false,
    required this.calculationProfiles,
    required this.fulfillmentOverview,
    required this.selfBuyoutLinks,
    required this.selfBuyout,
    required this.garageImport,
    required this.trackLinks,
    this.trackImport = false,
    required this.assemblyLinks,
    required this.invoiceLinks,
    required this.analytics,
    this.bulkOperations = false,
    this.purchaseExport = false,
    this.customersDirectory = false,
  });

  factory SpOrganizerCapabilities.fromJson(Map<String, dynamic> json) {
    return SpOrganizerCapabilities(
      contractVersion: _intValue(json['contractVersion'], 1),
      organizerV2: _boolValue(json['organizerV2']),
      purchaseKinds: _boolValue(json['purchaseKinds']),
      participants: _boolValue(json['participants']),
      products: _boolValue(json['products']),
      purchaseBlankImport: _boolValue(json['purchaseBlankImport']),
      previousPurchaseImport: _boolValue(json['previousPurchaseImport']),
      calculationProfiles: _boolValue(json['calculationProfiles']),
      fulfillmentOverview: _boolValue(json['fulfillmentOverview']),
      selfBuyoutLinks: _boolValue(json['selfBuyoutLinks']),
      selfBuyout: json['selfBuyout'] is Map
          ? SpOrganizerActionCapability.fromJson(_mapValue(json['selfBuyout']))
          : SpOrganizerActionCapability.unavailable,
      garageImport: _boolValue(json['garageImport']),
      trackLinks: _boolValue(json['trackLinks']),
      trackImport: _boolValue(json['trackImport']),
      assemblyLinks: _boolValue(json['assemblyLinks']),
      invoiceLinks: _boolValue(json['invoiceLinks']),
      analytics: _boolValue(json['analytics']),
      bulkOperations: _boolValue(json['bulkOperations']),
      purchaseExport: _boolValue(json['purchaseExport']),
      customersDirectory: _boolValue(json['customersDirectory']),
    );
  }

  bool get hasOrganizerTools =>
      organizerV2 && (customersDirectory || products || analytics);
  bool get hasFulfillmentLinkActions =>
      selfBuyoutLinks ||
      garageImport ||
      trackLinks ||
      assemblyLinks ||
      invoiceLinks;

  static const unavailable = SpOrganizerCapabilities(
    contractVersion: 1,
    organizerV2: false,
    purchaseKinds: false,
    participants: false,
    products: false,
    purchaseBlankImport: false,
    previousPurchaseImport: false,
    calculationProfiles: false,
    fulfillmentOverview: false,
    selfBuyoutLinks: false,
    selfBuyout: SpOrganizerActionCapability.unavailable,
    garageImport: false,
    trackLinks: false,
    trackImport: false,
    assemblyLinks: false,
    invoiceLinks: false,
    analytics: false,
    bulkOperations: false,
    purchaseExport: false,
    customersDirectory: false,
  );
}

class SpOrganizerProductMedia {
  final int id;
  final String url;
  final String? thumbnailUrl;
  final String? fileName;
  final String? mimeType;
  final int sortOrder;

  const SpOrganizerProductMedia({
    required this.id,
    required this.url,
    this.thumbnailUrl,
    this.fileName,
    this.mimeType,
    this.sortOrder = 0,
  });

  factory SpOrganizerProductMedia.fromJson(Map<String, dynamic> json) {
    return SpOrganizerProductMedia(
      id: _intValue(json['id']),
      url: _stringValue(json['url']) ?? '',
      thumbnailUrl: _stringValue(json['thumbnailUrl']),
      fileName: _stringValue(json['fileName']),
      mimeType: _stringValue(json['mimeType']),
      sortOrder: _intValue(json['sortOrder']),
    );
  }
}

class SpOrganizerProduct {
  final int id;
  final String title;
  final String? sourceUrl;
  final String? marketplaceCode;
  final String? barcode;
  final String? qrImageUrl;
  final String? description;
  final DateTime? archivedAt;
  final String? archivedReason;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final SpOrganizerProductMedia? primaryMedia;
  final List<SpOrganizerProductMedia> media;
  final int itemsCount;

  const SpOrganizerProduct({
    required this.id,
    required this.title,
    this.sourceUrl,
    this.marketplaceCode,
    this.barcode,
    this.qrImageUrl,
    this.description,
    this.archivedAt,
    this.archivedReason,
    this.createdAt,
    this.updatedAt,
    this.primaryMedia,
    this.media = const [],
    this.itemsCount = 0,
  });

  bool get isArchived => archivedAt != null;

  String? get imageUrl {
    final primary = primaryMedia?.thumbnailUrl ?? primaryMedia?.url;
    if (primary != null && primary.isNotEmpty) return primary;
    if (media.isEmpty) return null;
    return media.first.thumbnailUrl ?? media.first.url;
  }

  factory SpOrganizerProduct.fromJson(Map<String, dynamic> json) {
    final count = _mapValue(json['_count']);
    return SpOrganizerProduct(
      id: _intValue(json['id']),
      title: _stringValue(json['title']) ?? 'Товар',
      sourceUrl: _stringValue(json['sourceUrl']),
      marketplaceCode: _stringValue(json['marketplaceCode']),
      barcode: _stringValue(json['barcode']),
      qrImageUrl: _stringValue(json['qrImageUrl']),
      description: _stringValue(json['description']),
      archivedAt: _dateValue(json['archivedAt']),
      archivedReason: _stringValue(json['archivedReason']),
      createdAt: _dateValue(json['createdAt']),
      updatedAt: _dateValue(json['updatedAt']),
      primaryMedia: json['primaryMedia'] is Map
          ? SpOrganizerProductMedia.fromJson(_mapValue(json['primaryMedia']))
          : null,
      media: _mapList(
        json['media'],
      ).map(SpOrganizerProductMedia.fromJson).toList(growable: false),
      itemsCount: _intValue(count['items']),
    );
  }
}

class SpOrganizerProductPage {
  final List<SpOrganizerProduct> items;
  final int total;
  final int page;
  final int limit;
  final int totalPages;
  final String sortBy;
  final String sortDirection;

  const SpOrganizerProductPage({
    this.items = const [],
    this.total = 0,
    this.page = 1,
    this.limit = 40,
    this.totalPages = 0,
    this.sortBy = 'updatedAt',
    this.sortDirection = 'desc',
  });

  bool get hasMore => page < totalPages;

  factory SpOrganizerProductPage.fromJson(Map<String, dynamic> json) {
    return SpOrganizerProductPage(
      items: _mapList(
        json['items'],
      ).map(SpOrganizerProduct.fromJson).toList(growable: false),
      total: _intValue(json['total']),
      page: _intValue(json['page'], 1),
      limit: _intValue(json['limit'], 40),
      totalPages: _intValue(json['totalPages']),
      sortBy: _stringValue(json['sortBy']) ?? 'updatedAt',
      sortDirection: _stringValue(json['sortDirection']) ?? 'desc',
    );
  }
}

class SpOrganizerProductUsageSummary {
  final int itemsCount;
  final int purchasesCount;
  final int customersCount;
  final int totalQuantity;
  final double totalWeightKg;
  final double turnoverRub;
  final double costRub;
  final double profitRub;
  final double averageClientPriceRub;
  final double averageCostRub;

  const SpOrganizerProductUsageSummary({
    this.itemsCount = 0,
    this.purchasesCount = 0,
    this.customersCount = 0,
    this.totalQuantity = 0,
    this.totalWeightKg = 0,
    this.turnoverRub = 0,
    this.costRub = 0,
    this.profitRub = 0,
    this.averageClientPriceRub = 0,
    this.averageCostRub = 0,
  });

  factory SpOrganizerProductUsageSummary.fromJson(Map<String, dynamic> json) {
    return SpOrganizerProductUsageSummary(
      itemsCount: _intValue(json['itemsCount']),
      purchasesCount: _intValue(json['purchasesCount']),
      customersCount: _intValue(json['customersCount']),
      totalQuantity: _intValue(json['totalQuantity']),
      totalWeightKg: _doubleValue(json['totalWeightKg']),
      turnoverRub: _doubleValue(json['turnoverRub']),
      costRub: _doubleValue(json['costRub']),
      profitRub: _doubleValue(json['profitRub']),
      averageClientPriceRub: _doubleValue(json['averageClientPriceRub']),
      averageCostRub: _doubleValue(json['averageCostRub']),
    );
  }
}

class SpOrganizerProductHistoryPurchase {
  final int id;
  final String title;
  final String kind;
  final String status;
  final String statusLabel;
  final String currency;
  final double purchaseRate;
  final DateTime? startedAt;
  final DateTime? dispatchedFromChinaAt;
  final DateTime? completedAt;
  final DateTime? createdAt;

  const SpOrganizerProductHistoryPurchase({
    required this.id,
    required this.title,
    required this.kind,
    required this.status,
    required this.statusLabel,
    required this.currency,
    this.purchaseRate = 0,
    this.startedAt,
    this.dispatchedFromChinaAt,
    this.completedAt,
    this.createdAt,
  });

  factory SpOrganizerProductHistoryPurchase.fromJson(
    Map<String, dynamic> json,
  ) {
    return SpOrganizerProductHistoryPurchase(
      id: _intValue(json['id']),
      title: _stringValue(json['title']) ?? 'СП',
      kind: _stringValue(json['kind']) ?? 'group',
      status: _stringValue(json['status']) ?? '',
      statusLabel:
          _stringValue(json['statusLabel']) ??
          _stringValue(json['status']) ??
          '',
      currency: (_stringValue(json['currency']) ?? 'CNY').toUpperCase(),
      purchaseRate: _doubleValue(json['purchaseRate']),
      startedAt: _dateValue(json['startedAt']),
      dispatchedFromChinaAt: _dateValue(json['dispatchedFromChinaAt']),
      completedAt: _dateValue(json['completedAt']),
      createdAt: _dateValue(json['createdAt']),
    );
  }
}

class SpOrganizerProductHistoryCustomer {
  final int id;
  final String fullName;
  final String displayName;
  final bool isOrganizerSelf;

  const SpOrganizerProductHistoryCustomer({
    required this.id,
    required this.fullName,
    required this.displayName,
    required this.isOrganizerSelf,
  });

  factory SpOrganizerProductHistoryCustomer.fromJson(
    Map<String, dynamic> json,
  ) {
    final fullName = _stringValue(json['fullName']) ?? 'Клиент';
    final isOrganizerSelf = _boolValue(json['isOrganizerSelf']);
    return SpOrganizerProductHistoryCustomer(
      id: _intValue(json['id']),
      fullName: fullName,
      displayName:
          _stringValue(json['displayName']) ??
          (isOrganizerSelf ? 'Я' : fullName),
      isOrganizerSelf: isOrganizerSelf,
    );
  }
}

class SpOrganizerProductHistoryItem {
  final int id;
  final String title;
  final int quantity;
  final String status;
  final String statusLabel;
  final double purchasePriceYuan;
  final double clientPriceYuan;
  final double purchaseRate;
  final double costPriceRub;
  final double clientPriceRub;
  final double organizerMarginRub;
  final double actualWeightKg;
  final DateTime? archivedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final SpOrganizerProductHistoryPurchase purchase;
  final SpOrganizerProductHistoryCustomer customer;

  const SpOrganizerProductHistoryItem({
    required this.id,
    required this.title,
    required this.quantity,
    required this.status,
    required this.statusLabel,
    required this.purchase,
    required this.customer,
    this.purchasePriceYuan = 0,
    this.clientPriceYuan = 0,
    this.purchaseRate = 0,
    this.costPriceRub = 0,
    this.clientPriceRub = 0,
    this.organizerMarginRub = 0,
    this.actualWeightKg = 0,
    this.archivedAt,
    this.createdAt,
    this.updatedAt,
  });

  bool get isArchived => archivedAt != null;

  factory SpOrganizerProductHistoryItem.fromJson(Map<String, dynamic> json) {
    return SpOrganizerProductHistoryItem(
      id: _intValue(json['id']),
      title: _stringValue(json['title']) ?? 'Товар',
      quantity: _intValue(json['quantity'], 1),
      status: _stringValue(json['status']) ?? '',
      statusLabel:
          _stringValue(json['statusLabel']) ??
          _stringValue(json['status']) ??
          '',
      purchasePriceYuan: _doubleValue(json['purchasePriceYuan']),
      clientPriceYuan: _doubleValue(json['clientPriceYuan']),
      purchaseRate: _doubleValue(json['purchaseRate']),
      costPriceRub: _doubleValue(json['costPriceRub']),
      clientPriceRub: _doubleValue(json['clientPriceRub']),
      organizerMarginRub: _doubleValue(json['organizerMarginRub']),
      actualWeightKg: _doubleValue(json['actualWeightKg']),
      archivedAt: _dateValue(json['archivedAt']),
      createdAt: _dateValue(json['createdAt']),
      updatedAt: _dateValue(json['updatedAt']),
      purchase: SpOrganizerProductHistoryPurchase.fromJson(
        _mapValue(json['purchase']),
      ),
      customer: SpOrganizerProductHistoryCustomer.fromJson(
        _mapValue(json['customer']),
      ),
    );
  }
}

class SpOrganizerProductHistoryPage {
  final List<SpOrganizerProductHistoryItem> items;
  final int total;
  final int page;
  final int limit;
  final int totalPages;

  const SpOrganizerProductHistoryPage({
    this.items = const [],
    this.total = 0,
    this.page = 1,
    this.limit = 20,
    this.totalPages = 0,
  });

  bool get hasMore => page < totalPages;

  factory SpOrganizerProductHistoryPage.fromJson(Map<String, dynamic> json) {
    return SpOrganizerProductHistoryPage(
      items: _mapList(
        json['items'],
      ).map(SpOrganizerProductHistoryItem.fromJson).toList(growable: false),
      total: _intValue(json['total']),
      page: _intValue(json['page'], 1),
      limit: _intValue(json['limit'], 20),
      totalPages: _intValue(json['totalPages']),
    );
  }
}

class SpOrganizerProductHistoryStatus {
  final String code;
  final String nameRu;
  final String? nameZh;
  final String? color;
  final String? icon;
  final int sortOrder;

  const SpOrganizerProductHistoryStatus({
    required this.code,
    required this.nameRu,
    this.nameZh,
    this.color,
    this.icon,
    this.sortOrder = 0,
  });

  factory SpOrganizerProductHistoryStatus.fromJson(Map<String, dynamic> json) {
    return SpOrganizerProductHistoryStatus(
      code: _stringValue(json['code']) ?? '',
      nameRu: _stringValue(json['nameRu']) ?? _stringValue(json['code']) ?? '',
      nameZh: _stringValue(json['nameZh']),
      color: _stringValue(json['color']),
      icon: _stringValue(json['icon']),
      sortOrder: _intValue(json['sortOrder']),
    );
  }
}

class SpOrganizerProductDetail {
  final SpOrganizerProduct product;
  final SpOrganizerProductUsageSummary summary;
  final SpOrganizerProductHistoryPage history;
  final List<SpOrganizerProductHistoryStatus> statusOptions;

  const SpOrganizerProductDetail({
    required this.product,
    required this.summary,
    required this.history,
    this.statusOptions = const [],
  });

  factory SpOrganizerProductDetail.fromJson(Map<String, dynamic> json) {
    final filterOptions = _mapValue(json['filterOptions']);
    return SpOrganizerProductDetail(
      product: SpOrganizerProduct.fromJson(_mapValue(json['product'])),
      summary: SpOrganizerProductUsageSummary.fromJson(
        _mapValue(json['summary']),
      ),
      history: SpOrganizerProductHistoryPage.fromJson(
        _mapValue(json['history']),
      ),
      statusOptions: _mapList(
        filterOptions['statuses'],
      ).map(SpOrganizerProductHistoryStatus.fromJson).toList(growable: false),
    );
  }
}

class SpOrganizerProductDetailQuery {
  final int productId;
  final String query;
  final String? status;
  final String scope;
  final int page;
  final int limit;
  final String sortBy;
  final String sortDirection;

  const SpOrganizerProductDetailQuery({
    required this.productId,
    this.query = '',
    this.status,
    this.scope = 'all',
    this.page = 1,
    this.limit = 20,
    this.sortBy = 'createdAt',
    this.sortDirection = 'desc',
  });

  SpOrganizerProductDetailQuery copyWith({
    String? query,
    Object? status = _queryValueNotSet,
    String? scope,
    int? page,
    int? limit,
    String? sortBy,
    String? sortDirection,
  }) {
    return SpOrganizerProductDetailQuery(
      productId: productId,
      query: query ?? this.query,
      status: identical(status, _queryValueNotSet)
          ? this.status
          : status as String?,
      scope: scope ?? this.scope,
      page: page ?? this.page,
      limit: limit ?? this.limit,
      sortBy: sortBy ?? this.sortBy,
      sortDirection: sortDirection ?? this.sortDirection,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is SpOrganizerProductDetailQuery &&
        other.productId == productId &&
        other.query == query &&
        other.status == status &&
        other.scope == scope &&
        other.page == page &&
        other.limit == limit &&
        other.sortBy == sortBy &&
        other.sortDirection == sortDirection;
  }

  @override
  int get hashCode => Object.hash(
    productId,
    query,
    status,
    scope,
    page,
    limit,
    sortBy,
    sortDirection,
  );
}

const _queryValueNotSet = Object();

class SpOrganizerProductInput {
  final String title;
  final String? sourceUrl;
  final String? marketplaceCode;
  final String? barcode;
  final String? qrImageUrl;
  final String? description;
  final List<String> mediaUrls;

  const SpOrganizerProductInput({
    required this.title,
    this.sourceUrl,
    this.marketplaceCode,
    this.barcode,
    this.qrImageUrl,
    this.description,
    this.mediaUrls = const [],
  });

  Map<String, dynamic> toJson() => toCreateJson();

  Map<String, dynamic> toCreateJson() => {
    'title': title,
    if (sourceUrl != null && sourceUrl!.trim().isNotEmpty)
      'sourceUrl': sourceUrl,
    if (marketplaceCode != null && marketplaceCode!.trim().isNotEmpty)
      'marketplaceCode': marketplaceCode,
    if (barcode != null && barcode!.trim().isNotEmpty) 'barcode': barcode,
    if (qrImageUrl != null && qrImageUrl!.trim().isNotEmpty)
      'qrImageUrl': qrImageUrl,
    if (description != null && description!.trim().isNotEmpty)
      'description': description,
    if (mediaUrls.isNotEmpty) 'mediaUrls': mediaUrls,
  };

  Map<String, dynamic> toUpdateJson() => {
    'title': title,
    'sourceUrl': _nullableText(sourceUrl),
    'marketplaceCode': _nullableText(marketplaceCode),
    'barcode': _nullableText(barcode),
    'description': _nullableText(description),
    if (qrImageUrl != null) 'qrImageUrl': _nullableText(qrImageUrl),
    if (mediaUrls.isNotEmpty) 'mediaUrls': mediaUrls,
  };

  static String? _nullableText(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}

class SpOrganizerParticipantCustomer {
  final int id;
  final String fullName;
  final String displayName;
  final bool isOrganizerSelf;
  final String? phone;
  final String? city;

  const SpOrganizerParticipantCustomer({
    required this.id,
    required this.fullName,
    required this.displayName,
    required this.isOrganizerSelf,
    this.phone,
    this.city,
  });

  factory SpOrganizerParticipantCustomer.fromJson(Map<String, dynamic> json) {
    final fullName = _stringValue(json['fullName']) ?? 'Клиент';
    final isOrganizerSelf = _boolValue(json['isOrganizerSelf']);
    return SpOrganizerParticipantCustomer(
      id: _intValue(json['id']),
      fullName: fullName,
      displayName:
          _stringValue(json['displayName']) ??
          (isOrganizerSelf ? 'Я' : fullName),
      isOrganizerSelf: isOrganizerSelf,
      phone: _stringValue(json['phone']),
      city: _stringValue(json['city']),
    );
  }
}

class SpOrganizerParticipant {
  final int? id;
  final int spPurchaseId;
  final int spCustomerId;
  final int displayOrder;
  final String? note;
  final DateTime? archivedAt;
  final String? archivedReason;
  final bool legacyDerived;
  final SpOrganizerParticipantCustomer customer;

  const SpOrganizerParticipant({
    required this.id,
    required this.spPurchaseId,
    required this.spCustomerId,
    required this.displayOrder,
    this.note,
    this.archivedAt,
    this.archivedReason,
    required this.legacyDerived,
    required this.customer,
  });

  bool get isArchived => archivedAt != null;

  factory SpOrganizerParticipant.fromJson(Map<String, dynamic> json) {
    return SpOrganizerParticipant(
      id: json['id'] == null ? null : _intValue(json['id']),
      spPurchaseId: _intValue(json['spPurchaseId']),
      spCustomerId: _intValue(json['spCustomerId']),
      displayOrder: _intValue(json['displayOrder']),
      note: _stringValue(json['note']),
      archivedAt: _dateValue(json['archivedAt']),
      archivedReason: _stringValue(json['archivedReason']),
      legacyDerived: _boolValue(json['legacyDerived']),
      customer: SpOrganizerParticipantCustomer.fromJson(
        _mapValue(json['customer']),
      ),
    );
  }
}

class SpOrganizerParticipantList {
  final List<SpOrganizerParticipant> participants;
  final String source;

  const SpOrganizerParticipantList({
    this.participants = const [],
    this.source = 'legacy',
  });

  factory SpOrganizerParticipantList.fromJson(Map<String, dynamic> json) {
    return SpOrganizerParticipantList(
      participants: _mapList(
        json['participants'],
      ).map(SpOrganizerParticipant.fromJson).toList(growable: false),
      source: _stringValue(json['source']) ?? 'legacy',
    );
  }
}

SpV2Customer spOrganizerCustomerAsLegacy(
  SpOrganizerParticipantCustomer customer,
) {
  return SpV2Customer(
    id: customer.id,
    fullName: customer.displayName,
    phone: customer.phone,
    city: customer.city,
  );
}
