import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging/client_log_service.dart';
import '../../../core/network/api_client.dart';
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

    final response = await _api.post<Map<String, dynamic>>(
      '/client/problem-reports',
      data: {
        'description': description.trim(),
        'currentScreen':
            currentScreen ?? ClientLogService.instance.currentScreen,
        'logs': ClientLogService.instance.lastLogs(limit: 100),
        'apiErrors': ClientLogService.instance.lastApiErrors(limit: 20),
        'runtime': runtime.toJson(),
        'agentId': profile.agent?.id,
        'clientCode': clientCode,
      },
    );

    final data = response.data;
    if (data == null) return null;
    final id = data['id'];
    return id is int ? id : null;
  }
}
