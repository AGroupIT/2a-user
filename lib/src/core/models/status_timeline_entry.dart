import 'dart:convert';

class StatusTimelineEntry {
  final String statusCode;
  final String? description;
  final DateTime? createdAt;
  final String? createdByName;

  const StatusTimelineEntry({
    required this.statusCode,
    this.description,
    this.createdAt,
    this.createdByName,
  });

  factory StatusTimelineEntry.fromStatusHistoryJson(Map<String, dynamic> json) {
    return StatusTimelineEntry(
      statusCode: json['status']?.toString() ?? '',
      description: json['comment']?.toString(),
      createdAt: _parseDate(json['createdAt']),
      createdByName:
          json['createdByName']?.toString() ?? json['createdBy']?.toString(),
    );
  }

  factory StatusTimelineEntry.fromEventJson(Map<String, dynamic> json) {
    final newValue = json['newValue'];
    return StatusTimelineEntry(
      statusCode:
          _extractStatusCode(newValue) ?? json['status']?.toString() ?? '',
      description: json['description']?.toString(),
      createdAt: _parseDate(json['createdAt']),
      createdByName: json['createdByName']?.toString(),
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  static String? _extractStatusCode(dynamic value) {
    if (value == null) return null;
    if (value is Map) {
      return value['status']?.toString() ?? value['code']?.toString();
    }
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return null;
      if (trimmed.startsWith('{')) {
        try {
          final decoded = jsonDecode(trimmed);
          if (decoded is Map) {
            return decoded['status']?.toString() ?? decoded['code']?.toString();
          }
        } catch (_) {
          return trimmed;
        }
      }
      return trimmed;
    }
    return value.toString();
  }
}
