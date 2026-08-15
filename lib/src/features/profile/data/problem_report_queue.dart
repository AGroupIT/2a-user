import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

class QueuedProblemReport {
  const QueuedProblemReport({
    required this.localId,
    required this.accountId,
    required this.queuedAt,
    required this.payload,
  });

  final String localId;
  final int accountId;
  final DateTime queuedAt;
  final Map<String, dynamic> payload;

  Map<String, dynamic> toJson() {
    return {
      'localId': localId,
      'accountId': accountId,
      'queuedAt': queuedAt.toIso8601String(),
      'payload': payload,
    };
  }

  static QueuedProblemReport? fromJson(Map<String, dynamic> json) {
    final localId = json['localId'];
    final accountId = json['accountId'];
    final queuedAt = DateTime.tryParse(json['queuedAt']?.toString() ?? '');
    final payload = json['payload'];
    if (localId is! String || localId.isEmpty) return null;
    if (accountId is! int || accountId <= 0) return null;
    if (queuedAt == null) return null;
    if (payload is! Map) return null;
    return QueuedProblemReport(
      localId: localId,
      accountId: accountId,
      queuedAt: queuedAt,
      payload: Map<String, dynamic>.from(payload),
    );
  }
}

enum ProblemReportQueueSendDisposition { sent, discardPermanent }

class ProblemReportQueueFlushResult {
  const ProblemReportQueueFlushResult({
    required this.sent,
    required this.discarded,
    required this.remaining,
  });

  final int sent;
  final int discarded;
  final int remaining;
}

class ProblemReportQueue {
  static const _legacyKey = 'problem_report_queue_v1';
  static const _keyPrefix = 'problem_report_queue_v2_client_';
  static const _maxItems = 5;
  static const _prefsTimeout = Duration(seconds: 3);
  static final Random _secureRandom = Random.secure();

  static String createIdempotencyKey() {
    final timestamp = DateTime.now().toUtc().microsecondsSinceEpoch;
    final randomHigh = _secureRandom.nextInt(0x100000000);
    final randomLow = _secureRandom.nextInt(0x100000000);
    final randomPart =
        randomHigh.toRadixString(16).padLeft(8, '0') +
        randomLow.toRadixString(16).padLeft(8, '0');
    return 'pr_${timestamp}_$randomPart';
  }

  Future<int> enqueue({
    required int accountId,
    required Map<String, dynamic> payload,
  }) async {
    _validateAccountId(accountId);
    final items = await load(accountId: accountId);
    final normalizedPayload = _normalizeMap(payload);
    final payloadIdempotencyKey = normalizedPayload['idempotencyKey'];
    final localId =
        payloadIdempotencyKey is String &&
            payloadIdempotencyKey.trim().isNotEmpty
        ? payloadIdempotencyKey.trim()
        : createIdempotencyKey();
    normalizedPayload['idempotencyKey'] = localId;
    final queued = QueuedProblemReport(
      localId: localId,
      accountId: accountId,
      queuedAt: DateTime.now().toUtc(),
      payload: normalizedPayload,
    );
    final next = [...items, queued];
    final trimmed = next.length > _maxItems
        ? next.sublist(next.length - _maxItems)
        : next;
    await _save(accountId, trimmed);
    return trimmed.length;
  }

  Future<List<QueuedProblemReport>> load({required int accountId}) async {
    _validateAccountId(accountId);
    final prefs = await SharedPreferences.getInstance().timeout(_prefsTimeout);
    if (prefs.containsKey(_legacyKey)) {
      // V1 had no account owner. Keeping it could submit one client's report
      // with another client's token, so legacy entries are intentionally dropped.
      await prefs.remove(_legacyKey);
    }
    final rawItems = prefs.getStringList(_keyForAccount(accountId)) ?? const [];
    final result = <QueuedProblemReport>[];
    for (final raw in rawItems) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is! Map<String, dynamic>) continue;
        final item = QueuedProblemReport.fromJson(decoded);
        if (item != null && item.accountId == accountId) result.add(item);
      } catch (_) {
        // Ignore corrupted queue entries: one bad local report must not break
        // the whole offline queue.
      }
    }
    return result;
  }

  Future<ProblemReportQueueFlushResult> flush({
    required int accountId,
    required Future<ProblemReportQueueSendDisposition> Function(
      Map<String, dynamic> payload,
    )
    sender,
  }) async {
    final items = await load(accountId: accountId);
    if (items.isEmpty) {
      return const ProblemReportQueueFlushResult(
        sent: 0,
        discarded: 0,
        remaining: 0,
      );
    }

    final remaining = <QueuedProblemReport>[];
    var sent = 0;
    var discarded = 0;
    for (var index = 0; index < items.length; index++) {
      final item = items[index];
      try {
        final disposition = await sender(item.payload);
        switch (disposition) {
          case ProblemReportQueueSendDisposition.sent:
            sent++;
          case ProblemReportQueueSendDisposition.discardPermanent:
            discarded++;
        }
      } catch (_) {
        remaining.addAll(items.skip(index));
        break;
      }
    }

    await _save(accountId, remaining);
    return ProblemReportQueueFlushResult(
      sent: sent,
      discarded: discarded,
      remaining: remaining.length,
    );
  }

  Future<void> clear({required int accountId}) async {
    _validateAccountId(accountId);
    final prefs = await SharedPreferences.getInstance().timeout(_prefsTimeout);
    await prefs.remove(_keyForAccount(accountId));
    await prefs.remove(_legacyKey);
  }

  Future<void> _save(int accountId, List<QueuedProblemReport> items) async {
    final prefs = await SharedPreferences.getInstance().timeout(_prefsTimeout);
    final rawItems = items.map((item) => jsonEncode(item.toJson())).toList();
    await prefs.setStringList(_keyForAccount(accountId), rawItems);
  }

  String _keyForAccount(int accountId) => '$_keyPrefix$accountId';

  void _validateAccountId(int accountId) {
    if (accountId <= 0) {
      throw ArgumentError.value(accountId, 'accountId', 'Must be positive');
    }
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
