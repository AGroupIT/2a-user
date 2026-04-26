/// WebSocket delta event for real-time data sync.
///
/// The server sends full objects in deltas — the client does a full replace
/// instead of making an HTTP request.
class DeltaEvent {
  /// Entity type: 'tracks', 'assemblies', 'invoices', etc.
  final String type;

  /// What happened: 'created', 'updated', 'deleted'
  final String action;

  /// Entity ID
  final String id;

  /// Full entity data (null for 'deleted')
  final Map<String, dynamic>? data;

  /// Server timestamp (ISO8601)
  final DateTime timestamp;

  const DeltaEvent({
    required this.type,
    required this.action,
    required this.id,
    this.data,
    required this.timestamp,
  });

  factory DeltaEvent.fromJson(Map<String, dynamic> json) {
    return DeltaEvent(
      type: json['type'] as String? ?? '',
      action: json['action'] as String? ?? '',
      id: json['id']?.toString() ?? '',
      data: json['data'] as Map<String, dynamic>?,
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  bool get isCreated => action == 'created';
  bool get isUpdated => action == 'updated';
  bool get isDeleted => action == 'deleted';
}

/// Batch delta event containing multiple deltas of the same type.
class DeltaBatchEvent {
  final String type;
  final List<DeltaEvent> items;
  final DateTime timestamp;

  const DeltaBatchEvent({
    required this.type,
    required this.items,
    required this.timestamp,
  });

  factory DeltaBatchEvent.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String? ?? '';
    final timestamp = json['timestamp'] != null
        ? DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now()
        : DateTime.now();

    final itemsList = json['items'] as List<dynamic>? ?? [];
    final items = itemsList.map((item) {
      final map = item as Map<String, dynamic>;
      return DeltaEvent(
        type: type,
        action: map['action'] as String? ?? '',
        id: map['id']?.toString() ?? '',
        data: map['data'] as Map<String, dynamic>?,
        timestamp: timestamp,
      );
    }).toList();

    return DeltaBatchEvent(
      type: type,
      items: items,
      timestamp: timestamp,
    );
  }
}
