import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../../../core/logging/client_log_service.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/network_diagnostics.dart';
import '../../../core/services/runtime/app_runtime_info.dart';
import '../../auth/data/auth_provider.dart';
import 'problem_report_queue.dart';
import 'profile_provider.dart';

final problemReportRepositoryProvider = Provider<ProblemReportRepository>((
  ref,
) {
  return ProblemReportRepository(
    ref.read(apiClientProvider),
    activeClientId: () {
      final auth = ref.read(authProvider);
      return auth.isLoggedIn ? auth.clientId : null;
    },
  );
});

class ProblemReportRepository {
  ProblemReportRepository(
    this._api, {
    ProblemReportQueue? queue,
    int? Function()? activeClientId,
    Future<AppRuntimeSnapshot> Function()? runtimeSnapshot,
    Future<NetworkDiagnosticReport?> Function(String? clientCode)?
    collectDiagnostics,
    String? Function()? sentryLastEventId,
  }) : _queue = queue ?? ProblemReportQueue(),
       _activeClientId = activeClientId,
       _runtimeSnapshot = runtimeSnapshot ?? AppRuntimeInfo.instance.snapshot,
       _collectDiagnostics =
           collectDiagnostics ??
           ((clientCode) =>
               NetworkDiagnosticsService(_api).collect(clientCode: clientCode)),
       _sentryLastEventId = sentryLastEventId ?? _currentSentryEventId;

  final ApiClient _api;
  final ProblemReportQueue _queue;
  final int? Function()? _activeClientId;
  final Future<AppRuntimeSnapshot> Function() _runtimeSnapshot;
  final Future<NetworkDiagnosticReport?> Function(String? clientCode)
  _collectDiagnostics;
  final String? Function() _sentryLastEventId;
  static const _sendTimeout = Duration(seconds: 12);

  Future<ProblemReportSendResult> send({
    required String description,
    required ClientProfile profile,
    required String? currentScreen,
  }) async {
    _ensureActiveClient(profile.id);
    final clientCode = profile.codes.isNotEmpty
        ? profile.codes.first.code
        : null;
    final runtime = await _runtimeSnapshot();
    final sentryLastEventId = _validatedSentryEventId(_sentryLastEventId());
    NetworkDiagnosticReport? diagnostics;
    try {
      diagnostics = await _collectDiagnostics(clientCode);
    } catch (error, stackTrace) {
      ClientLogService.instance.error(
        'Не удалось собрать диагностику сети',
        error: error,
        stackTrace: stackTrace,
      );
    }

    final payload = <String, dynamic>{
      'idempotencyKey': ProblemReportQueue.createIdempotencyKey(),
      'description': description.trim(),
      'currentScreen': currentScreen ?? ClientLogService.instance.currentScreen,
      'logs': ClientLogService.instance.lastLogs(limit: 100),
      'apiErrors': ClientLogService.instance.lastApiErrors(limit: 20),
      'runtime': {
        ...runtime.toJson(),
        if (sentryLastEventId != null) 'sentryLastEventId': sentryLastEventId,
        if (diagnostics != null) 'networkDiagnostics': diagnostics.toJson(),
      },
      'agentId': profile.agent?.id,
      'clientCode': clientCode,
    };

    try {
      _ensureActiveClient(profile.id);
      final id = await _postPayload(payload);
      unawaited(flushQueuedReports(clientId: profile.id));
      return ProblemReportSendResult.sent(id: id);
    } on ProblemReportAccountChangedException {
      rethrow;
    } catch (error) {
      if (_isPermanentClientFailure(error)) {
        throw ProblemReportSendException(
          cause: error,
          diagnostics: diagnostics,
        );
      }
      try {
        final queuedCount = await _queue.enqueue(
          accountId: profile.id,
          payload: payload,
        );
        ClientLogService.instance.add(
          type: 'problem_report_queued',
          level: 'warning',
          message: 'Отчёт о проблеме сохранён локально до восстановления сети',
          data: {
            'queuedCount': queuedCount,
            'clientCode': clientCode,
            'error': error.toString(),
          },
        );
        return ProblemReportSendResult.queued(queuedCount: queuedCount);
      } catch (queueError) {
        throw ProblemReportSendException(
          cause: error,
          diagnostics: diagnostics,
          queueError: queueError,
        );
      }
    }
  }

  static String? _currentSentryEventId() {
    return _validatedSentryEventId(Sentry.lastEventId.toString());
  }

  static String? _validatedSentryEventId(String? value) {
    final normalized = value?.trim().toLowerCase();
    if (normalized == null ||
        !RegExp(r'^[0-9a-f]{32}$').hasMatch(normalized) ||
        normalized == '00000000000000000000000000000000') {
      return null;
    }
    return normalized;
  }

  Future<int> flushQueuedReports({required int clientId}) async {
    try {
      final result = await _queue.flush(
        accountId: clientId,
        sender: (payload) async {
          _ensureActiveClient(clientId);
          try {
            await _postPayload(payload);
            return ProblemReportQueueSendDisposition.sent;
          } catch (error) {
            if (_isPermanentClientFailure(error)) {
              return ProblemReportQueueSendDisposition.discardPermanent;
            }
            rethrow;
          }
        },
      );
      if (result.discarded > 0) {
        ClientLogService.instance.add(
          type: 'problem_report_queue_discarded',
          level: 'warning',
          message: 'Discarded permanently rejected queued problem reports',
          data: {'discarded': result.discarded},
        );
      }
      return result.sent;
    } on ProblemReportAccountChangedException {
      // Expected cancellation during logout/account switch. The per-account
      // queue remains untouched and will retry only for its owner.
      return 0;
    } catch (error, stackTrace) {
      await ClientLogService.instance.captureNonFatal(
        'Не удалось отправить локальную очередь problem reports',
        error: error,
        stackTrace: stackTrace,
      );
      return 0;
    }
  }

  Future<void> clearQueuedReports({required int clientId}) {
    return _queue.clear(accountId: clientId);
  }

  void _ensureActiveClient(int expectedClientId) {
    if (_activeClientId != null && _activeClientId() != expectedClientId) {
      throw const ProblemReportAccountChangedException();
    }
  }

  Future<int?> _postPayload(Map<String, dynamic> payload) async {
    final idempotencyKey = payload['idempotencyKey']?.toString();
    final response = await _api
        .post<Map<String, dynamic>>(
          '/client/problem-reports',
          data: payload,
          options: Options(
            sendTimeout: _sendTimeout,
            receiveTimeout: _sendTimeout,
            headers: {
              if (idempotencyKey != null && idempotencyKey.isNotEmpty)
                'Idempotency-Key': idempotencyKey,
            },
          ),
        )
        .timeout(
          _sendTimeout,
          onTimeout: () {
            _api.resetConnections(
              reason: 'problem_report_timeout',
              force: true,
            );
            throw TimeoutException('Problem report send timeout', _sendTimeout);
          },
        );

    final data = response.data;
    if (data == null) return null;
    final id = data['id'];
    return id is int ? id : null;
  }

  bool _isPermanentClientFailure(Object error) {
    if (error is! DioException) return false;
    final statusCode = error.response?.statusCode;
    if (statusCode == null || statusCode < 400 || statusCode >= 500) {
      return false;
    }
    return statusCode != 401 &&
        statusCode != 408 &&
        statusCode != 425 &&
        statusCode != 426 &&
        statusCode != 429;
  }
}

class ProblemReportAccountChangedException implements Exception {
  const ProblemReportAccountChangedException();
}

class ProblemReportSendResult {
  const ProblemReportSendResult._({
    required this.queued,
    required this.queuedCount,
    this.id,
  });

  final int? id;
  final bool queued;
  final int queuedCount;

  factory ProblemReportSendResult.sent({int? id}) {
    return ProblemReportSendResult._(queued: false, queuedCount: 0, id: id);
  }

  factory ProblemReportSendResult.queued({required int queuedCount}) {
    return ProblemReportSendResult._(queued: true, queuedCount: queuedCount);
  }
}

class ProblemReportSendException implements Exception {
  const ProblemReportSendException({
    required this.cause,
    this.diagnostics,
    this.queueError,
  });

  final Object cause;
  final NetworkDiagnosticReport? diagnostics;
  final Object? queueError;

  @override
  String toString() => cause.toString();
}
