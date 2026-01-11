import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../domain/add_tracks_result.dart';

abstract class AddTracksRepository {
  Future<AddTracksResult> addTracks({
    required String clientCode,
    required List<String> trackCodes,
  });
}

final addTracksRepositoryProvider = Provider<AddTracksRepository>((ref) {
  return RealAddTracksRepository(ref);
});

class RealAddTracksRepository implements AddTracksRepository {
  final Ref _ref;

  RealAddTracksRepository(this._ref);

  ApiClient get _api => _ref.read(apiClientProvider);

  @override
  Future<AddTracksResult> addTracks({
    required String clientCode,
    required List<String> trackCodes,
  }) async {
    try {
      final response = await _api.post(
        '/client/tracks',
        data: {'clientCode': clientCode, 'trackNumbers': trackCodes},
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data as Map<String, dynamic>;
        final added = data['added'] as int? ?? 0;
        final skippedList = data['skipped'] as List<dynamic>? ?? [];

        final skipped = skippedList.map((s) {
          if (s is Map<String, dynamic>) {
            return SkippedTrack(
              code: s['code'] as String? ?? '',
              reason: s['reason'] as String? ?? 'Неизвестная причина',
            );
          }
          return SkippedTrack(
            code: s.toString(),
            reason: 'Уже существует в базе',
          );
        }).toList();

        return AddTracksResult(added: added, skipped: skipped);
      }

      throw Exception('Ошибка при добавлении треков: ${response.statusCode}');
    } on DioException catch (e) {
      debugPrint('Error adding tracks: $e');

      if (e.response?.statusCode == 401) {
        throw Exception('Необходимо авторизоваться');
      }
      if (e.response?.statusCode == 403) {
        throw Exception('Нет доступа для добавления треков');
      }
      if (e.response?.statusCode == 404) {
        throw Exception('Код клиента не найден');
      }

      final errorMessage = e.response?.data?['error'] as String?;
      throw Exception(errorMessage ?? 'Ошибка сети при добавлении треков');
    }
  }
}
