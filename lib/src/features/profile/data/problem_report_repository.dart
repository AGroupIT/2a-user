import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging/client_log_service.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/network_diagnostics.dart';
import '../../../core/services/runtime/app_runtime_info.dart';
import 'profile_provider.dart';

final problemReportRepositoryProvider = Provider<ProblemReportRepository>((
  ref,
) {
  return ProblemReportRepository(ref.read(apiClientProvider));
});

class ProblemReportRepository {
  const ProblemReportRepository(this._api);

  final ApiClient _api;

  Future<int?> send({
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

    try {
      final response = await _api.post<Map<String, dynamic>>(
        '/client/problem-reports',
        data: {
          'description': description.trim(),
          'currentScreen':
              currentScreen ?? ClientLogService.instance.currentScreen,
          'logs': ClientLogService.instance.lastLogs(limit: 100),
          'apiErrors': ClientLogService.instance.lastApiErrors(limit: 20),
          'runtime': {
            ...runtime.toJson(),
            if (diagnostics != null) 'networkDiagnostics': diagnostics.toJson(),
          },
          'agentId': profile.agent?.id,
          'clientCode': clientCode,
        },
      );

      final data = response.data;
      if (data == null) return null;
      final id = data['id'];
      return id is int ? id : null;
    } catch (error) {
      throw ProblemReportSendException(cause: error, diagnostics: diagnostics);
    }
  }
}

class ProblemReportSendException implements Exception {
  const ProblemReportSendException({required this.cause, this.diagnostics});

  final Object cause;
  final NetworkDiagnosticReport? diagnostics;

  @override
  String toString() => cause.toString();
}
