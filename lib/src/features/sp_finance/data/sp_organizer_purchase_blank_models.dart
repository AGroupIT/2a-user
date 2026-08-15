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

class SpOrganizerPurchaseBlankCandidate {
  final int id;
  final int blankId;
  final String blankStatus;
  final DateTime? blankCreatedAt;
  final DateTime? blankUpdatedAt;
  final int orderNumber;
  final String title;
  final String? sourceUrl;
  final String? characteristics;
  final int quantity;
  final double? unitPriceYuan;
  final double? totalPriceYuan;
  final double? itemTotalYuan;
  final String? trackNumber;
  final List<String> photoUrls;
  final bool imported;
  final int? importedItemId;
  final int? importedCustomerId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const SpOrganizerPurchaseBlankCandidate({
    required this.id,
    required this.blankId,
    required this.blankStatus,
    required this.orderNumber,
    required this.title,
    required this.quantity,
    this.blankCreatedAt,
    this.blankUpdatedAt,
    this.sourceUrl,
    this.characteristics,
    this.unitPriceYuan,
    this.totalPriceYuan,
    this.itemTotalYuan,
    this.trackNumber,
    this.photoUrls = const [],
    this.imported = false,
    this.importedItemId,
    this.importedCustomerId,
    this.createdAt,
    this.updatedAt,
  });

  factory SpOrganizerPurchaseBlankCandidate.fromJson(
    Map<String, dynamic> json,
  ) {
    return SpOrganizerPurchaseBlankCandidate(
      id: _intValue(json['id']),
      blankId: _intValue(json['blankId']),
      blankStatus: _stringValue(json['blankStatus']) ?? 'new_blank',
      blankCreatedAt: _dateValue(json['blankCreatedAt']),
      blankUpdatedAt: _dateValue(json['blankUpdatedAt']),
      orderNumber: _intValue(json['orderNumber']),
      title: _stringValue(json['title']) ?? 'Товар из бланка',
      sourceUrl: _stringValue(json['sourceUrl']),
      characteristics: _stringValue(json['characteristics']),
      quantity: _intValue(json['quantity'], 1),
      unitPriceYuan: _doubleValue(json['unitPriceYuan']),
      totalPriceYuan: _doubleValue(json['totalPriceYuan']),
      itemTotalYuan: _doubleValue(json['itemTotalYuan']),
      trackNumber: _stringValue(json['trackNumber']),
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

class SpOrganizerPurchaseBlankCandidatePage {
  final List<SpOrganizerPurchaseBlankCandidate> candidates;
  final int page;
  final int limit;
  final int total;
  final int totalPages;

  const SpOrganizerPurchaseBlankCandidatePage({
    this.candidates = const [],
    this.page = 1,
    this.limit = 20,
    this.total = 0,
    this.totalPages = 1,
  });

  factory SpOrganizerPurchaseBlankCandidatePage.fromJson(
    Map<String, dynamic> json,
  ) {
    final pagination = _mapValue(json['pagination']);
    return SpOrganizerPurchaseBlankCandidatePage(
      candidates: json['candidates'] is List
          ? (json['candidates'] as List)
                .whereType<Map>()
                .map(
                  (item) => SpOrganizerPurchaseBlankCandidate.fromJson(
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
