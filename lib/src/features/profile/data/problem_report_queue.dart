import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class QueuedProblemReport {
  const QueuedProblemReport({
    required this.localId,
    required this.queuedAt,
    required this.payload,
  });

  final String localId;
  final DateTime queuedAt;
  final Map<String, dynamic> payload;

  Map<String, dynamic> toJson() {
    return {
      'localId': localId,
      'queuedAt': queuedAt.toIso8601String(),
      'payload': payload,
    };
  }

  static QueuedProblemReport? fromJson(Map<String, dynamic> json) {
    final localId = json['localId'];
    final queuedAt = DateTime.tryParse(json['queuedAt']?.toString() ?? '');
    final payload = json['payload'];
    if (localId is! String || localId.isEmpty) return null;
    if (queuedAt == null) return null;
    if (payload is! Map) return null;
    return QueuedProblemReport(
      localId: localId,
      queuedAt: queuedAt,
      payload: Map<String, dynamic>.from(payload),
    );
  }
}

class ProblemReportQueue {
  static const _key = 'problem_report_queue_v1';
  static const _maxItems = 5;
  static const _prefsTimeout = Duration(seconds: 3);

  Future<int> enqueue(Map<String, dynamic> payload) async {
    final items = await load();
    final queued = QueuedProblemReport(
      localId: 'pr_${DateTime.now().toUtc().microsecondsSinceEpoch}',
      queuedAt: DateTime.now().toUtc(),
      payload: _normalizeMap(payload),
    );
    final next = [...items, queued];
    final trimmed = next.length > _maxItems
        ? next.sublist(next.length - _maxItems)
        : next;
    await _save(trimmed);
    return trimmed.length;
  }

  Future<List<QueuedProblemReport>> load() async {
    final prefs = await SharedPreferences.getInstance().timeout(_prefsTimeout);
    final rawItems = prefs.getStringList(_key) ?? const [];
    final result = <QueuedProblemReport>[];
    for (final raw in rawItems) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is! Map<String, dynamic>) continue;
        final item = QueuedProblemReport.fromJson(decoded);
        if (item != null) result.add(item);
      } catch (_) {
        // Ignore corrupted queue entries: one bad local report must not break
        // the whole offline queue.
      }
    }
    return result;
  }

  Future<int> flush(
    Future<void> Function(Map<String, dynamic> payload) sender,
  ) async {
    final items = await load();
    if (items.isEmpty) return 0;

    final remaining = <QueuedProblemReport>[];
    var sent = 0;
    for (var index = 0; index < items.length; index++) {
      final item = items[index];
      try {
        await sender(item.payload);
        sent++;
      } catch (_) {
        remaining.addAll(items.skip(index));
        break;
      }
    }

    await _save(remaining);
    return sent;
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance().timeout(_prefsTimeout);
    await prefs.remove(_key);
  }

  Future<void> _save(List<QueuedProblemReport> items) async {
    final prefs = await SharedPreferences.getInstance().timeout(_prefsTimeout);
    final rawItems = items.map((item) => jsonEncode(item.toJson())).toList();
    await prefs.setStringList(_key, rawItems);
  }

  Map<String, dynamic> _normalizeMap(Map<String, dynamic> value) {
    return value.map((key, item) => MapEntry(key, _normalizeJsonValue(item)));
  }

  dynamic _normalizeJsonValue(dynamic value) {
    if (value == null || value is String || value is num || value is bool) {
      return value;
    }
    if (value is DateTime) return value.toIso8601String();
    if (value is Uri) return value.toString();
    if (value is Map) {
      return value.map(
        (key, item) => MapEntry(key.toString(), _normalizeJsonValue(item)),
      );
    }
    if (value is Iterable) {
      return value.map(_normalizeJsonValue).toList(growable: false);
    }
    return value.toString();
  }
}
