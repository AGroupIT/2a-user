import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging/client_log_service.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/network_diagnostics.dart';
import '../../../core/services/runtime/app_runtime_info.dart';
import 'problem_report_queue.dart';
import 'profile_provider.dart';

final problemReportRepositoryProvider = Provider<ProblemReportRepository>((
  ref,
) {
  return ProblemReportRepository(ref.read(apiClientProvider));
});

class ProblemReportRepository {
  ProblemReportRepository(this._api, {ProblemReportQueue? queue})
    : _queue = queue ?? ProblemReportQueue();

  final ApiClient _api;
  final ProblemReportQueue _queue;
  static const _sendTimeout = Duration(seconds: 12);

  Future<ProblemReportSendResult> send({
    required String description,
    required ClientProfile profile,
    required String? currentScreen,
  }) async {
    final runtime = await AppRuntimeInfo.instance.snapshot();
    final clientCode = profile.codes.isNotEmpty
        ? profile.codes.first.code
        : null;
    NetworkDiagnosticReport? diagnostics;
    try {
      diagnostics = await NetworkDiagnosticsService(
        _api,
      ).collect(clientCode: clientCode);
    } catch (error, stackTrace) {
      ClientLogService.instance.error(
        'Не удалось собрать диагностику сети',
        error: error,
        stackTrace: stackTrace,
      );
    }

    final payload = {
      'description': description.trim(),
      'currentScreen': currentScreen ?? ClientLogService.instance.currentScreen,
      'logs': ClientLogService.instance.lastLogs(limit: 100),
      'apiErrors': ClientLogService.instance.lastApiErrors(limit: 20),
      'runtime': {
        ...runtime.toJson(),
        if (diagnostics != null) 'networkDiagnostics': diagnostics.toJson(),
      },
      'agentId': profile.agent?.id,
      'clientCode': clientCode,
    };

    try {
      final id = await _postPayload(payload);
      unawaited(flushQueuedReports());
      return ProblemReportSendResult.sent(id: id);
    } catch (error) {
      try {
        final queuedCount = await _queue.enqueue(payload);
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

  Future<int> flushQueuedReports() async {
    try {
      return await _queue.flush((payload) async {
        await _postPayload(payload);
      });
    } catch (error, stackTrace) {
      await ClientLogService.instance.captureNonFatal(
        'Не удалось отправить локальную очередь problem reports',
        error: error,
        stackTrace: stackTrace,
      );
      return 0;
    }
  }

  Future<int?> _postPayload(Map<String, dynamic> payload) async {
    final response = await _api
        .post<Map<String, dynamic>>(
          '/client/problem-reports',
          data: payload,
          options: Options(
            sendTimeout: _sendTimeout,
            receiveTimeout: _sendTimeout,
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
