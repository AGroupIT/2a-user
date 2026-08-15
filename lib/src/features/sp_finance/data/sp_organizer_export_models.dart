Map<String, dynamic> _mapValue(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : const {};

List<Map<String, dynamic>> _mapList(dynamic value) => value is List
    ? value
          .whereType<Map>()
          .map(Map<String, dynamic>.from)
          .toList(growable: false)
    : const [];

String _stringValue(dynamic value, [String fallback = '']) {
  if (value is! String) return fallback;
  final normalized = value.trim();
  return normalized.isEmpty ? fallback : normalized;
}

int _intValue(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

class SpOrganizerExportColumn {
  final String key;
  final String labelRu;
  final String labelZh;
  final String type;

  const SpOrganizerExportColumn({
    required this.key,
    required this.labelRu,
    required this.labelZh,
    required this.type,
  });

  factory SpOrganizerExportColumn.fromJson(Map<String, dynamic> json) {
    return SpOrganizerExportColumn(
      key: _stringValue(json['key']),
      labelRu: _stringValue(json['labelRu']),
      labelZh: _stringValue(json['labelZh']),
      type: _stringValue(json['type'], 'text'),
    );
  }

  String labelFor(String languageCode) =>
      languageCode == 'zh' && labelZh.isNotEmpty ? labelZh : labelRu;
}

class SpOrganizerPurchaseExport {
  final int contractVersion;
  final String mode;
  final bool persisted;
  final String fileName;
  final Map<String, dynamic> purchase;
  final Map<String, dynamic> summary;
  final List<SpOrganizerExportColumn> columns;
  final List<Map<String, dynamic>> rows;
  final int totalRows;
  final List<String> warnings;

  const SpOrganizerPurchaseExport({
    required this.contractVersion,
    required this.mode,
    required this.persisted,
    required this.fileName,
    required this.purchase,
    required this.summary,
    required this.columns,
    required this.rows,
    required this.totalRows,
    this.warnings = const [],
  });

  factory SpOrganizerPurchaseExport.fromJson(Map<String, dynamic> json) {
    final columns = _mapList(json['columns'])
        .map(SpOrganizerExportColumn.fromJson)
        .where((column) {
          return column.key.isNotEmpty && column.labelRu.isNotEmpty;
        })
        .toList(growable: false);
    final rows = _mapList(json['rows']);
    return SpOrganizerPurchaseExport(
      contractVersion: _intValue(json['contractVersion']),
      mode: _stringValue(json['mode'], 'read_only'),
      persisted: json['persisted'] == true,
      fileName: _stringValue(json['fileName'], 'sp_purchase.xlsx'),
      purchase: _mapValue(json['purchase']),
      summary: _mapValue(json['summary']),
      columns: columns,
      rows: rows,
      totalRows: _intValue(json['totalRows']),
      warnings: json['warnings'] is List
          ? (json['warnings'] as List).whereType<String>().toList(
              growable: false,
            )
          : const [],
    );
  }
}
