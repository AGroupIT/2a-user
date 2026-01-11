class SearchResult {
  final int id;
  final String trackCode;
  final String status;
  final String? statusZh;
  final String? statusColor;
  final DateTime updatedAt;
  final String? clientCode;
  final int? clientCodeId;
  final bool isNocode;
  final bool hasQuestion;
  final bool hasPendingQuestion;
  final bool showBindButton;

  const SearchResult({
    required this.id,
    required this.trackCode,
    required this.status,
    this.statusZh,
    this.statusColor,
    required this.updatedAt,
    this.clientCode,
    this.clientCodeId,
    this.isNocode = false,
    this.hasQuestion = false,
    this.hasPendingQuestion = false,
    this.showBindButton = false,
  });

  factory SearchResult.fromJson(Map<String, dynamic> json) {
    return SearchResult(
      id: json['id'] as int,
      trackCode: json['trackNumber'] as String,
      status: json['status'] as String? ?? 'Неизвестно',
      statusZh: json['statusZh'] as String?,
      statusColor: json['statusColor'] as String?,
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ?? DateTime.now(),
      clientCode: json['clientCode'] as String?,
      clientCodeId: json['clientCodeId'] as int?,
      isNocode: json['isNocode'] as bool? ?? false,
      hasQuestion: json['hasQuestion'] as bool? ?? false,
      hasPendingQuestion: json['hasPendingQuestion'] as bool? ?? false,
      showBindButton: json['showBindButton'] as bool? ?? false,
    );
  }
}
