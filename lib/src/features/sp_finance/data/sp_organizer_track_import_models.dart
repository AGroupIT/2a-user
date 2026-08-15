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

DateTime? _dateValue(dynamic value) =>
    value is String ? DateTime.tryParse(value) : null;

List<String> _stringList(dynamic value) => value is List
    ? value
          .whereType<String>()
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false)
    : const [];

List<int> _intList(dynamic value) => value is List
    ? value.map(_intValue).where((item) => item > 0).toList(growable: false)
    : const [];

Map<String, dynamic> _mapValue(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : const {};

class SpOrganizerTrackImportCandidate {
  final int id;
  final String trackNumber;
  final String status;
  final String clientCode;
  final String title;
  final int quantity;
  final List<String> photoUrls;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<int> linkedItemIds;
  final List<int> linkedCustomerIds;

  const SpOrganizerTrackImportCandidate({
    required this.id,
    required this.trackNumber,
    required this.status,
    required this.clientCode,
    required this.title,
    required this.quantity,
    this.photoUrls = const [],
    this.createdAt,
    this.updatedAt,
    this.linkedItemIds = const [],
    this.linkedCustomerIds = const [],
  });

  factory SpOrganizerTrackImportCandidate.fromJson(Map<String, dynamic> json) {
    return SpOrganizerTrackImportCandidate(
      id: _intValue(json['id']),
      trackNumber: _stringValue(json['trackNumber']) ?? 'Трек',
      status: _stringValue(json['status']) ?? '',
      clientCode: _stringValue(json['clientCode']) ?? '',
      title: _stringValue(json['title']) ?? 'Товар из трека',
      quantity: _intValue(json['quantity'], 1).clamp(1, 1000000),
      photoUrls: _stringList(json['photoUrls']),
      createdAt: _dateValue(json['createdAt']),
      updatedAt: _dateValue(json['updatedAt']),
      linkedItemIds: _intList(json['linkedItemIds']),
      linkedCustomerIds: _intList(json['linkedCustomerIds']),
    );
  }

  String? get primaryPhotoUrl => photoUrls.isEmpty ? null : photoUrls.first;

  int get linkedCount => linkedItemIds.length;

  bool isLinkedToCustomer(int? customerId) =>
      customerId != null && linkedCustomerIds.contains(customerId);
}

class SpOrganizerTrackImportCandidatePage {
  final List<SpOrganizerTrackImportCandidate> candidates;
  final int page;
  final int limit;
  final int total;
  final int totalPages;

  const SpOrganizerTrackImportCandidatePage({
    this.candidates = const [],
    this.page = 1,
    this.limit = 20,
    this.total = 0,
    this.totalPages = 1,
  });

  factory SpOrganizerTrackImportCandidatePage.fromJson(
    Map<String, dynamic> json,
  ) {
    final pagination = _mapValue(json['pagination']);
    return SpOrganizerTrackImportCandidatePage(
      candidates: json['candidates'] is List
          ? (json['candidates'] as List)
                .whereType<Map>()
                .map(
                  (item) => SpOrganizerTrackImportCandidate.fromJson(
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
