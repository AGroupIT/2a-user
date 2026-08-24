import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/services/demo_mode_provider.dart';
import '../domain/assembly_scan_session.dart';

abstract interface class AssemblyScanSessionsRepository {
  Future<List<AssemblyScanSession>> fetchSessions(int assemblyId);

  Future<AssemblyScanSession> fetchSession({
    required int assemblyId,
    required String sessionId,
  });

  Future<AssemblyScanPlaybackToken> createPlaybackToken({
    required int assemblyId,
    required String sessionId,
    required String videoId,
  });
}

class ApiAssemblyScanSessionsRepository
    implements AssemblyScanSessionsRepository {
  final ApiClient _apiClient;

  const ApiAssemblyScanSessionsRepository(this._apiClient);

  @override
  Future<List<AssemblyScanSession>> fetchSessions(int assemblyId) async {
    final response = await _apiClient.get(
      '/client/assemblies/$assemblyId/scan-sessions',
    );
    final body = _responseMap(response.data);
    final rawSessions = body['sessions'];
    if (rawSessions is! List) return const [];

    final sessions = rawSessions
        .whereType<Map>()
        .map(
          (item) =>
              AssemblyScanSession.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
    sessions.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return sessions;
  }

  @override
  Future<AssemblyScanSession> fetchSession({
    required int assemblyId,
    required String sessionId,
  }) async {
    final response = await _apiClient.get(
      '/client/assemblies/$assemblyId/scan-sessions/$sessionId',
    );
    final body = _responseMap(response.data);
    final rawSession = body['session'];
    if (rawSession is! Map) {
      throw const FormatException('Invalid scan session response');
    }
    return AssemblyScanSession.fromJson(Map<String, dynamic>.from(rawSession));
  }

  @override
  Future<AssemblyScanPlaybackToken> createPlaybackToken({
    required int assemblyId,
    required String sessionId,
    required String videoId,
  }) async {
    final response = await _apiClient.post(
      '/client/assemblies/$assemblyId/scan-sessions/$sessionId/playback-token',
      data: {'videoId': videoId},
    );
    final body = _responseMap(response.data);
    final token = AssemblyScanPlaybackToken.fromJson(body);
    if (!token.url.hasScheme || token.url.host.isEmpty) {
      throw const FormatException('Invalid scan playback URL');
    }
    return token;
  }
}

Map<String, dynamic> _responseMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  throw const FormatException('Invalid scan session response');
}

final assemblyScanSessionsRepositoryProvider =
    Provider<AssemblyScanSessionsRepository>((ref) {
      return ApiAssemblyScanSessionsRepository(ref.read(apiClientProvider));
    });

final assemblyScanSessionsProvider =
    FutureProvider.family<List<AssemblyScanSession>, int>((ref, assemblyId) {
      if (ref.watch(demoModeProvider)) return const [];
      return ref
          .read(assemblyScanSessionsRepositoryProvider)
          .fetchSessions(assemblyId);
    });

typedef AssemblyScanSessionKey = ({int assemblyId, String sessionId});

final assemblyScanSessionProvider =
    FutureProvider.family<AssemblyScanSession, AssemblyScanSessionKey>((
      ref,
      key,
    ) {
      return ref
          .read(assemblyScanSessionsRepositoryProvider)
          .fetchSession(assemblyId: key.assemblyId, sessionId: key.sessionId);
    });
