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

double? _doubleValue(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.replaceAll(',', '.'));
  return null;
}

bool _boolValue(dynamic value) => value is bool && value;

DateTime? _dateValue(dynamic value) =>
    value is String ? DateTime.tryParse(value) : null;

List<String> _stringList(dynamic value) => value is List
    ? value
          .whereType<String>()
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false)
    : const [];

Map<String, dynamic> _mapValue(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : const {};

class SpOrganizerPreviousPurchaseCandidate {
  final int id;
  final int sourcePurchaseId;
  final String sourcePurchaseTitle;
  final String sourcePurchaseCurrency;
  final DateTime? sourcePurchaseCreatedAt;
  final DateTime? sourcePurchaseUpdatedAt;
  final int sourceCustomerId;
  final String sourceCustomerName;
  final String title;
  final String? sourceUrl;
  final String? sellerInfo;
  final String? description;
  final int quantity;
  final String sourceStatus;
  final double? supplierPriceYuan;
  final double? purchasePriceYuan;
  final double? clientPriceYuan;
  final double? costPriceRub;
  final double? clientPriceRub;
  final double? declaredWeightKg;
  final List<String> photoUrls;
  final bool imported;
  final int? importedItemId;
  final int? importedCustomerId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const SpOrganizerPreviousPurchaseCandidate({
    required this.id,
    required this.sourcePurchaseId,
    required this.sourcePurchaseTitle,
    required this.sourcePurchaseCurrency,
    required this.sourceCustomerId,
    required this.sourceCustomerName,
    required this.title,
    required this.quantity,
    required this.sourceStatus,
    this.sourcePurchaseCreatedAt,
    this.sourcePurchaseUpdatedAt,
    this.sourceUrl,
    this.sellerInfo,
    this.description,
    this.supplierPriceYuan,
    this.purchasePriceYuan,
    this.clientPriceYuan,
    this.costPriceRub,
    this.clientPriceRub,
    this.declaredWeightKg,
    this.photoUrls = const [],
    this.imported = false,
    this.importedItemId,
    this.importedCustomerId,
    this.createdAt,
    this.updatedAt,
  });

  factory SpOrganizerPreviousPurchaseCandidate.fromJson(
    Map<String, dynamic> json,
  ) {
    return SpOrganizerPreviousPurchaseCandidate(
      id: _intValue(json['id']),
      sourcePurchaseId: _intValue(json['sourcePurchaseId']),
      sourcePurchaseTitle:
          _stringValue(json['sourcePurchaseTitle']) ?? 'Прошлая закупка',
      sourcePurchaseCurrency:
          _stringValue(json['sourcePurchaseCurrency']) ?? 'CNY',
      sourcePurchaseCreatedAt: _dateValue(json['sourcePurchaseCreatedAt']),
      sourcePurchaseUpdatedAt: _dateValue(json['sourcePurchaseUpdatedAt']),
      sourceCustomerId: _intValue(json['sourceCustomerId']),
      sourceCustomerName:
          _stringValue(json['sourceCustomerName']) ?? 'Участник',
      title: _stringValue(json['title']) ?? 'Товар',
      sourceUrl: _stringValue(json['sourceUrl']),
      sellerInfo: _stringValue(json['sellerInfo']),
      description: _stringValue(json['description']),
      quantity: _intValue(json['quantity'], 1),
      sourceStatus: _stringValue(json['sourceStatus']) ?? 'requested',
      supplierPriceYuan: _doubleValue(json['supplierPriceYuan']),
      purchasePriceYuan: _doubleValue(json['purchasePriceYuan']),
      clientPriceYuan: _doubleValue(json['clientPriceYuan']),
      costPriceRub: _doubleValue(json['costPriceRub']),
      clientPriceRub: _doubleValue(json['clientPriceRub']),
      declaredWeightKg: _doubleValue(json['declaredWeightKg']),
      photoUrls: _stringList(json['photoUrls']),
      imported: _boolValue(json['imported']),
      importedItemId: json['importedItemId'] == null
          ? null
          : _intValue(json['importedItemId']),
      importedCustomerId: json['importedCustomerId'] == null
          ? null
          : _intValue(json['importedCustomerId']),
      createdAt: _dateValue(json['createdAt']),
      updatedAt: _dateValue(json['updatedAt']),
    );
  }

  String? get primaryPhotoUrl => photoUrls.isEmpty ? null : photoUrls.first;
}

class SpOrganizerPreviousPurchaseCandidatePage {
  final List<SpOrganizerPreviousPurchaseCandidate> candidates;
  final int page;
  final int limit;
  final int total;
  final int totalPages;

  const SpOrganizerPreviousPurchaseCandidatePage({
    this.candidates = const [],
    this.page = 1,
    this.limit = 20,
    this.total = 0,
    this.totalPages = 1,
  });

  factory SpOrganizerPreviousPurchaseCandidatePage.fromJson(
    Map<String, dynamic> json,
  ) {
    final pagination = _mapValue(json['pagination']);
    return SpOrganizerPreviousPurchaseCandidatePage(
      candidates: json['candidates'] is List
          ? (json['candidates'] as List)
                .whereType<Map>()
                .map(
                  (item) => SpOrganizerPreviousPurchaseCandidate.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList(growable: false)
          : const [],
      page: _intValue(pagination['page'], 1),
      limit: _intValue(pagination['limit'], 20),
      total: _intValue(pagination['total']),
      totalPages: _intValue(pagination['totalPages'], 1),
    );
  }

  bool get hasMore => page < totalPages;
}
