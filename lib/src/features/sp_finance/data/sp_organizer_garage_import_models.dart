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

class SpOrganizerGarageImportCandidate {
  final int id;
  final int orderId;
  final String orderNumber;
  final String orderStatus;
  final DateTime? orderUpdatedAt;
  final String title;
  final String manufacturer;
  final String partNumber;
  final String optionType;
  final int quantity;
  final double? unitPriceCny;
  final double? unitPriceRub;
  final double? lineTotalCny;
  final double? lineTotalRub;
  final String purchaseStatus;
  final String? supplierOrderNumber;
  final String? description;
  final List<String> photoUrls;
  final DateTime? purchasedAt;
  final bool imported;
  final int? importedItemId;
  final int? importedCustomerId;

  const SpOrganizerGarageImportCandidate({
    required this.id,
    required this.orderId,
    required this.orderNumber,
    required this.orderStatus,
    required this.title,
    required this.manufacturer,
    required this.partNumber,
    required this.optionType,
    required this.quantity,
    required this.purchaseStatus,
    this.orderUpdatedAt,
    this.unitPriceCny,
    this.unitPriceRub,
    this.lineTotalCny,
    this.lineTotalRub,
    this.supplierOrderNumber,
    this.description,
    this.photoUrls = const [],
    this.purchasedAt,
    this.imported = false,
    this.importedItemId,
    this.importedCustomerId,
  });

  factory SpOrganizerGarageImportCandidate.fromJson(Map<String, dynamic> json) {
    return SpOrganizerGarageImportCandidate(
      id: _intValue(json['id']),
      orderId: _intValue(json['orderId']),
      orderNumber: _stringValue(json['orderNumber']) ?? 'Garage',
      orderStatus: _stringValue(json['orderStatus']) ?? 'purchased',
      orderUpdatedAt: _dateValue(json['orderUpdatedAt']),
      title: _stringValue(json['title']) ?? 'Позиция Garage',
      manufacturer: _stringValue(json['manufacturer']) ?? '',
      partNumber: _stringValue(json['partNumber']) ?? '',
      optionType: _stringValue(json['optionType']) ?? '',
      quantity: _intValue(json['quantity'], 1),
      unitPriceCny: _doubleValue(json['unitPriceCny']),
      unitPriceRub: _doubleValue(json['unitPriceRub']),
      lineTotalCny: _doubleValue(json['lineTotalCny']),
      lineTotalRub: _doubleValue(json['lineTotalRub']),
      purchaseStatus: _stringValue(json['purchaseStatus']) ?? 'purchased',
      supplierOrderNumber: _stringValue(json['supplierOrderNumber']),
      description: _stringValue(json['description']),
      photoUrls: _stringList(json['photoUrls']),
      purchasedAt: _dateValue(json['purchasedAt']),
      imported: _boolValue(json['imported']),
      importedItemId: json['importedItemId'] == null
          ? null
          : _intValue(json['importedItemId']),
      importedCustomerId: json['importedCustomerId'] == null
          ? null
          : _intValue(json['importedCustomerId']),
    );
  }

  String? get primaryPhotoUrl => photoUrls.isEmpty ? null : photoUrls.first;

  String get partLabel => [
    manufacturer,
    partNumber,
    optionType,
  ].where((value) => value.isNotEmpty).join(' · ');
}

class SpOrganizerGarageImportCandidatePage {
  final List<SpOrganizerGarageImportCandidate> candidates;
  final int page;
  final int limit;
  final int total;
  final int totalPages;

  const SpOrganizerGarageImportCandidatePage({
    this.candidates = const [],
    this.page = 1,
    this.limit = 20,
    this.total = 0,
    this.totalPages = 1,
  });

  factory SpOrganizerGarageImportCandidatePage.fromJson(
    Map<String, dynamic> json,
  ) {
    final pagination = _mapValue(json['pagination']);
    return SpOrganizerGarageImportCandidatePage(
      candidates: json['candidates'] is List
          ? (json['candidates'] as List)
                .whereType<Map>()
                .map(
                  (item) => SpOrganizerGarageImportCandidate.fromJson(
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
