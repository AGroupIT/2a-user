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

double? _nullableDoubleValue(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.replaceAll(',', '.'));
  return null;
}

bool _boolValue(dynamic value, [bool fallback = false]) =>
    value is bool ? value : fallback;

DateTime? _dateValue(dynamic value) =>
    value is String ? DateTime.tryParse(value) : null;

class SpOrganizerAnalyticsFilter {
  final String period;
  final String audience;
  final String kind;
  final bool selfItemsAsPersonal;
  final DateTime? dateFrom;
  final DateTime? dateTo;

  const SpOrganizerAnalyticsFilter({
    this.period = '90d',
    this.audience = 'all',
    this.kind = 'all',
    this.selfItemsAsPersonal = false,
    this.dateFrom,
    this.dateTo,
  });

  SpOrganizerAnalyticsFilter copyWith({
    String? period,
    String? audience,
    String? kind,
    bool? selfItemsAsPersonal,
    DateTime? dateFrom,
    DateTime? dateTo,
    bool clearDates = false,
  }) {
    return SpOrganizerAnalyticsFilter(
      period: period ?? this.period,
      audience: audience ?? this.audience,
      kind: kind ?? this.kind,
      selfItemsAsPersonal: selfItemsAsPersonal ?? this.selfItemsAsPersonal,
      dateFrom: clearDates ? null : dateFrom ?? this.dateFrom,
      dateTo: clearDates ? null : dateTo ?? this.dateTo,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SpOrganizerAnalyticsFilter &&
      other.period == period &&
      other.audience == audience &&
      other.kind == kind &&
      other.selfItemsAsPersonal == selfItemsAsPersonal &&
      other.dateFrom == dateFrom &&
      other.dateTo == dateTo;

  @override
  int get hashCode => Object.hash(
    period,
    audience,
    kind,
    selfItemsAsPersonal,
    dateFrom,
    dateTo,
  );
}

class SpOrganizerAnalyticsSummary {
  final int purchasesCount;
  final int activePurchasesCount;
  final int completedPurchasesCount;
  final int customersCount;
  final int itemsCount;
  final int purchasedItemsCount;
  final int catalogProductsCount;
  final double turnoverRub;
  final double paidRub;
  final double receivableRub;
  final double costRub;
  final double profitRub;
  final double expensesRub;
  final double totalWeightKg;
  final double averagePurchaseRub;
  final double averageItemRub;
  final double averageDeliveryDays;

  const SpOrganizerAnalyticsSummary({
    this.purchasesCount = 0,
    this.activePurchasesCount = 0,
    this.completedPurchasesCount = 0,
    this.customersCount = 0,
    this.itemsCount = 0,
    this.purchasedItemsCount = 0,
    this.catalogProductsCount = 0,
    this.turnoverRub = 0,
    this.paidRub = 0,
    this.receivableRub = 0,
    this.costRub = 0,
    this.profitRub = 0,
    this.expensesRub = 0,
    this.totalWeightKg = 0,
    this.averagePurchaseRub = 0,
    this.averageItemRub = 0,
    this.averageDeliveryDays = 0,
  });

  factory SpOrganizerAnalyticsSummary.fromJson(Map<String, dynamic> json) {
    return SpOrganizerAnalyticsSummary(
      purchasesCount: _intValue(json['purchasesCount']),
      activePurchasesCount: _intValue(json['activePurchasesCount']),
      completedPurchasesCount: _intValue(json['completedPurchasesCount']),
      customersCount: _intValue(json['customersCount']),
      itemsCount: _intValue(json['itemsCount']),
      purchasedItemsCount: _intValue(json['purchasedItemsCount']),
      catalogProductsCount: _intValue(json['catalogProductsCount']),
      turnoverRub: _doubleValue(json['turnoverRub']),
      paidRub: _doubleValue(json['paidRub']),
      receivableRub: _doubleValue(json['receivableRub']),
      costRub: _doubleValue(json['costRub']),
      profitRub: _doubleValue(json['profitRub']),
      expensesRub: _doubleValue(json['expensesRub']),
      totalWeightKg: _doubleValue(json['totalWeightKg']),
      averagePurchaseRub: _doubleValue(json['averagePurchaseRub']),
      averageItemRub: _doubleValue(json['averageItemRub']),
      averageDeliveryDays: _doubleValue(json['averageDeliveryDays']),
    );
  }
}

class SpOrganizerAnalyticsComparisonSummary {
  final int purchasesCount;
  final int customersCount;
  final int itemsCount;
  final double turnoverRub;
  final double profitRub;
  final double averagePurchaseRub;
  final double averageDeliveryDays;

  const SpOrganizerAnalyticsComparisonSummary({
    this.purchasesCount = 0,
    this.customersCount = 0,
    this.itemsCount = 0,
    this.turnoverRub = 0,
    this.profitRub = 0,
    this.averagePurchaseRub = 0,
    this.averageDeliveryDays = 0,
  });

  factory SpOrganizerAnalyticsComparisonSummary.fromJson(
    Map<String, dynamic> json,
  ) {
    return SpOrganizerAnalyticsComparisonSummary(
      purchasesCount: _intValue(json['purchasesCount']),
      customersCount: _intValue(json['customersCount']),
      itemsCount: _intValue(json['itemsCount']),
      turnoverRub: _doubleValue(json['turnoverRub']),
      profitRub: _doubleValue(json['profitRub']),
      averagePurchaseRub: _doubleValue(json['averagePurchaseRub']),
      averageDeliveryDays: _doubleValue(json['averageDeliveryDays']),
    );
  }
}

class SpOrganizerAnalyticsComparisonChanges {
  final double? purchasesCount;
  final double? customersCount;
  final double? itemsCount;
  final double? turnoverRub;
  final double? profitRub;
  final double? averagePurchaseRub;
  final double? averageDeliveryDays;

  const SpOrganizerAnalyticsComparisonChanges({
    this.purchasesCount,
    this.customersCount,
    this.itemsCount,
    this.turnoverRub,
    this.profitRub,
    this.averagePurchaseRub,
    this.averageDeliveryDays,
  });

  factory SpOrganizerAnalyticsComparisonChanges.fromJson(
    Map<String, dynamic> json,
  ) {
    return SpOrganizerAnalyticsComparisonChanges(
      purchasesCount: _nullableDoubleValue(json['purchasesCount']),
      customersCount: _nullableDoubleValue(json['customersCount']),
      itemsCount: _nullableDoubleValue(json['itemsCount']),
      turnoverRub: _nullableDoubleValue(json['turnoverRub']),
      profitRub: _nullableDoubleValue(json['profitRub']),
      averagePurchaseRub: _nullableDoubleValue(json['averagePurchaseRub']),
      averageDeliveryDays: _nullableDoubleValue(json['averageDeliveryDays']),
    );
  }
}

class SpOrganizerAnalyticsComparison {
  final bool available;
  final DateTime? previousDateFrom;
  final DateTime? previousDateTo;
  final SpOrganizerAnalyticsComparisonSummary? previous;
  final SpOrganizerAnalyticsComparisonChanges? changes;

  const SpOrganizerAnalyticsComparison({
    this.available = false,
    this.previousDateFrom,
    this.previousDateTo,
    this.previous,
    this.changes,
  });

  factory SpOrganizerAnalyticsComparison.fromJson(Map<String, dynamic> json) {
    final previousPeriod = _mapValue(json['previousPeriod']);
    final previous = _mapValue(json['previous']);
    final changes = _mapValue(json['changes']);
    return SpOrganizerAnalyticsComparison(
      available: _boolValue(json['available']),
      previousDateFrom: _dateValue(previousPeriod['dateFrom']),
      previousDateTo: _dateValue(previousPeriod['dateTo']),
      previous: previous.isEmpty
          ? null
          : SpOrganizerAnalyticsComparisonSummary.fromJson(previous),
      changes: changes.isEmpty
          ? null
          : SpOrganizerAnalyticsComparisonChanges.fromJson(changes),
    );
  }
}

class SpOrganizerAnalyticsIntegrations {
  final int buyoutLinkedItemsCount;
  final double buyoutLinkedItemsShare;
  final int trackLinkedItemsCount;
  final double trackLinkedItemsShare;
  final int fulfillmentPurchasesCount;
  final double fulfillmentPurchasesShare;
  final int invoiceLinkedPurchasesCount;
  final double invoiceLinkedPurchasesShare;

  const SpOrganizerAnalyticsIntegrations({
    this.buyoutLinkedItemsCount = 0,
    this.buyoutLinkedItemsShare = 0,
    this.trackLinkedItemsCount = 0,
    this.trackLinkedItemsShare = 0,
    this.fulfillmentPurchasesCount = 0,
    this.fulfillmentPurchasesShare = 0,
    this.invoiceLinkedPurchasesCount = 0,
    this.invoiceLinkedPurchasesShare = 0,
  });

  factory SpOrganizerAnalyticsIntegrations.fromJson(Map<String, dynamic> json) {
    return SpOrganizerAnalyticsIntegrations(
      buyoutLinkedItemsCount: _intValue(json['buyoutLinkedItemsCount']),
      buyoutLinkedItemsShare: _doubleValue(json['buyoutLinkedItemsShare']),
      trackLinkedItemsCount: _intValue(json['trackLinkedItemsCount']),
      trackLinkedItemsShare: _doubleValue(json['trackLinkedItemsShare']),
      fulfillmentPurchasesCount: _intValue(json['fulfillmentPurchasesCount']),
      fulfillmentPurchasesShare: _doubleValue(
        json['fulfillmentPurchasesShare'],
      ),
      invoiceLinkedPurchasesCount: _intValue(
        json['invoiceLinkedPurchasesCount'],
      ),
      invoiceLinkedPurchasesShare: _doubleValue(
        json['invoiceLinkedPurchasesShare'],
      ),
    );
  }
}

class SpOrganizerAnalyticsSeriesPoint {
  final String month;
  final int purchasesCount;
  final int itemsCount;
  final double turnoverRub;
  final double paidRub;
  final double profitRub;

  const SpOrganizerAnalyticsSeriesPoint({
    required this.month,
    this.purchasesCount = 0,
    this.itemsCount = 0,
    this.turnoverRub = 0,
    this.paidRub = 0,
    this.profitRub = 0,
  });

  factory SpOrganizerAnalyticsSeriesPoint.fromJson(Map<String, dynamic> json) {
    return SpOrganizerAnalyticsSeriesPoint(
      month: _stringValue(json['month']) ?? '',
      purchasesCount: _intValue(json['purchasesCount']),
      itemsCount: _intValue(json['itemsCount']),
      turnoverRub: _doubleValue(json['turnoverRub']),
      paidRub: _doubleValue(json['paidRub']),
      profitRub: _doubleValue(json['profitRub']),
    );
  }
}

class SpOrganizerAnalyticsTopPurchase {
  final int id;
  final String title;
  final String kind;
  final String status;
  final DateTime? createdAt;
  final int itemsCount;
  final int customersCount;
  final double turnoverRub;
  final double paidRub;
  final double profitRub;
  final bool has2aFulfillment;

  const SpOrganizerAnalyticsTopPurchase({
    required this.id,
    required this.title,
    required this.kind,
    required this.status,
    this.createdAt,
    this.itemsCount = 0,
    this.customersCount = 0,
    this.turnoverRub = 0,
    this.paidRub = 0,
    this.profitRub = 0,
    this.has2aFulfillment = false,
  });

  factory SpOrganizerAnalyticsTopPurchase.fromJson(Map<String, dynamic> json) {
    return SpOrganizerAnalyticsTopPurchase(
      id: _intValue(json['id']),
      title: _stringValue(json['title']) ?? '',
      kind: _stringValue(json['kind']) ?? 'group',
      status: _stringValue(json['status']) ?? '',
      createdAt: _dateValue(json['createdAt']),
      itemsCount: _intValue(json['itemsCount']),
      customersCount: _intValue(json['customersCount']),
      turnoverRub: _doubleValue(json['turnoverRub']),
      paidRub: _doubleValue(json['paidRub']),
      profitRub: _doubleValue(json['profitRub']),
      has2aFulfillment: _boolValue(json['has2aFulfillment']),
    );
  }
}

class SpOrganizerAnalyticsTopCustomer {
  final int id;
  final String fullName;
  final String displayName;
  final bool isOrganizerSelf;
  final int purchasesCount;
  final int itemsCount;
  final double turnoverRub;
  final double paidRub;
  final double profitRub;

  const SpOrganizerAnalyticsTopCustomer({
    required this.id,
    required this.fullName,
    required this.displayName,
    this.isOrganizerSelf = false,
    this.purchasesCount = 0,
    this.itemsCount = 0,
    this.turnoverRub = 0,
    this.paidRub = 0,
    this.profitRub = 0,
  });

  factory SpOrganizerAnalyticsTopCustomer.fromJson(Map<String, dynamic> json) {
    final fullName = _stringValue(json['fullName']) ?? 'Клиент';
    return SpOrganizerAnalyticsTopCustomer(
      id: _intValue(json['id']),
      fullName: fullName,
      displayName: _stringValue(json['displayName']) ?? fullName,
      isOrganizerSelf: _boolValue(json['isOrganizerSelf']),
      purchasesCount: _intValue(json['purchasesCount']),
      itemsCount: _intValue(json['itemsCount']),
      turnoverRub: _doubleValue(json['turnoverRub']),
      paidRub: _doubleValue(json['paidRub']),
      profitRub: _doubleValue(json['profitRub']),
    );
  }
}

class SpOrganizerAnalyticsTopProduct {
  final int id;
  final String title;
  final String? marketplaceCode;
  final int purchasesCount;
  final int customersCount;
  final int quantity;
  final double turnoverRub;
  final double costRub;
  final double profitRub;

  const SpOrganizerAnalyticsTopProduct({
    required this.id,
    required this.title,
    this.marketplaceCode,
    this.purchasesCount = 0,
    this.customersCount = 0,
    this.quantity = 0,
    this.turnoverRub = 0,
    this.costRub = 0,
    this.profitRub = 0,
  });

  factory SpOrganizerAnalyticsTopProduct.fromJson(Map<String, dynamic> json) {
    return SpOrganizerAnalyticsTopProduct(
      id: _intValue(json['id']),
      title: _stringValue(json['title']) ?? 'Товар',
      marketplaceCode: _stringValue(json['marketplaceCode']),
      purchasesCount: _intValue(json['purchasesCount']),
      customersCount: _intValue(json['customersCount']),
      quantity: _intValue(json['quantity']),
      turnoverRub: _doubleValue(json['turnoverRub']),
      costRub: _doubleValue(json['costRub']),
      profitRub: _doubleValue(json['profitRub']),
    );
  }
}

class SpOrganizerAnalyticsTopMarketplace {
  final String code;
  final int productsCount;
  final int purchasesCount;
  final int quantity;
  final double turnoverRub;
  final double profitRub;

  const SpOrganizerAnalyticsTopMarketplace({
    required this.code,
    this.productsCount = 0,
    this.purchasesCount = 0,
    this.quantity = 0,
    this.turnoverRub = 0,
    this.profitRub = 0,
  });

  factory SpOrganizerAnalyticsTopMarketplace.fromJson(
    Map<String, dynamic> json,
  ) {
    return SpOrganizerAnalyticsTopMarketplace(
      code: _stringValue(json['code']) ?? '',
      productsCount: _intValue(json['productsCount']),
      purchasesCount: _intValue(json['purchasesCount']),
      quantity: _intValue(json['quantity']),
      turnoverRub: _doubleValue(json['turnoverRub']),
      profitRub: _doubleValue(json['profitRub']),
    );
  }
}

class SpOrganizerAnalytics {
  final int contractVersion;
  final String mode;
  final bool persisted;
  final DateTime? asOf;
  final SpOrganizerAnalyticsFilter filter;
  final SpOrganizerAnalyticsSummary summary;
  final SpOrganizerAnalyticsComparison comparison;
  final SpOrganizerAnalyticsIntegrations integrations;
  final List<SpOrganizerAnalyticsSeriesPoint> series;
  final List<SpOrganizerAnalyticsTopPurchase> topPurchases;
  final List<SpOrganizerAnalyticsTopCustomer> topCustomers;
  final List<SpOrganizerAnalyticsTopProduct> topProducts;
  final List<SpOrganizerAnalyticsTopMarketplace> topMarketplaces;
  final Map<String, String> formulas;
  final List<String> warnings;

  const SpOrganizerAnalytics({
    required this.contractVersion,
    required this.mode,
    required this.persisted,
    required this.filter,
    required this.summary,
    required this.integrations,
    this.comparison = const SpOrganizerAnalyticsComparison(),
    this.asOf,
    this.series = const [],
    this.topPurchases = const [],
    this.topCustomers = const [],
    this.topProducts = const [],
    this.topMarketplaces = const [],
    this.formulas = const {},
    this.warnings = const [],
  });

  factory SpOrganizerAnalytics.fromJson(Map<String, dynamic> json) {
    final filter = _mapValue(json['filter']);
    final formulas = _mapValue(
      json['formulas'],
    ).map((key, value) => MapEntry(key, value.toString()));
    return SpOrganizerAnalytics(
      contractVersion: _intValue(json['contractVersion'], 1),
      mode: _stringValue(json['mode']) ?? 'read_only',
      persisted: _boolValue(json['persisted']),
      asOf: _dateValue(json['asOf']),
      filter: SpOrganizerAnalyticsFilter(
        period: _stringValue(filter['period']) ?? '90d',
        audience: _stringValue(filter['audience']) ?? 'all',
        kind: _stringValue(filter['kind']) ?? 'all',
        selfItemsAsPersonal: _boolValue(filter['selfItemsAsPersonal']),
        dateFrom: _dateValue(filter['dateFrom']),
        dateTo: _dateValue(filter['dateTo']),
      ),
      summary: SpOrganizerAnalyticsSummary.fromJson(_mapValue(json['summary'])),
      comparison: SpOrganizerAnalyticsComparison.fromJson(
        _mapValue(json['comparison']),
      ),
      integrations: SpOrganizerAnalyticsIntegrations.fromJson(
        _mapValue(json['integrations']),
      ),
      series: _mapList(
        json['series'],
      ).map(SpOrganizerAnalyticsSeriesPoint.fromJson).toList(growable: false),
      topPurchases: _mapList(
        json['topPurchases'],
      ).map(SpOrganizerAnalyticsTopPurchase.fromJson).toList(growable: false),
      topCustomers: _mapList(
        json['topCustomers'],
      ).map(SpOrganizerAnalyticsTopCustomer.fromJson).toList(growable: false),
      topProducts: _mapList(
        json['topProducts'],
      ).map(SpOrganizerAnalyticsTopProduct.fromJson).toList(growable: false),
      topMarketplaces: _mapList(json['topMarketplaces'])
          .map(SpOrganizerAnalyticsTopMarketplace.fromJson)
          .toList(growable: false),
      formulas: formulas,
      warnings: json['warnings'] is List
          ? (json['warnings'] as List).whereType<String>().toList(
              growable: false,
            )
          : const [],
    );
  }
}
