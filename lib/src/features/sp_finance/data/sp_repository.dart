import 'package:flutter/foundation.dart';
import '../../../core/network/api_client.dart';
import 'sp_models.dart';

class SpRepository {
  final ApiClient _apiClient;

  SpRepository(this._apiClient);

  /// Получить список сборок с СП данными
  Future<List<SpAssembly>> getAssemblies() async {
    try {
      final response = await _apiClient.get('/client/sp/assemblies');

      if (kDebugMode) {
        debugPrint('📦 SP API Response type: ${response.data.runtimeType}');
      }

      final List<dynamic> data = response.data as List<dynamic>;
      if (kDebugMode) {
        debugPrint('📦 SP API returned ${data.length} assemblies');
      }

      final assemblies = <SpAssembly>[];
      for (var i = 0; i < data.length; i++) {
        try {
          final json = data[i] as Map<String, dynamic>;
          if (kDebugMode) {
            debugPrint(
              '📦 Processing assembly ${i + 1}/${data.length}: ID=${json['id']}',
            );
          }
          assemblies.add(SpAssembly.fromJson(json));
        } catch (e, stack) {
          debugPrint('❌ Error parsing assembly $i: $e');
          debugPrint('❌ Assembly data: ${data[i]}');
          debugPrint('❌ Stack: $stack');
          rethrow;
        }
      }

      return assemblies;
    } catch (e, stack) {
      debugPrint('❌ Error in getAssemblies: $e');
      debugPrint('❌ Stack: $stack');
      rethrow;
    }
  }

  /// Обновить настройки сборки СП
  Future<SpAssembly> updateAssembly(
    int assemblyId,
    SpAssemblyUpdate update,
  ) async {
    final response = await _apiClient.patch(
      '/client/sp/assemblies/$assemblyId',
      data: update.toJson(),
    );
    return SpAssembly.fromJson(response.data);
  }

  /// Обновить СП данные трека
  Future<SpTrack> updateTrack(int trackId, SpTrackUpdate update) async {
    final response = await _apiClient.patch(
      '/client/sp/tracks/$trackId',
      data: update.toJson(),
    );
    return SpTrack.fromJson(response.data);
  }

  /// Распределить доставку по весу
  Future<SpAssembly> calculateShipping(int assemblyId) async {
    final response = await _apiClient.post(
      '/client/sp/assemblies/$assemblyId/calculate-shipping',
    );
    return SpAssembly.fromJson(response.data);
  }

  /// Применить курс по умолчанию ко всем трекам
  Future<SpAssembly> applyRate(int assemblyId) async {
    final response = await _apiClient.post(
      '/client/sp/assemblies/$assemblyId/apply-rate',
    );
    return SpAssembly.fromJson(response.data);
  }

  /// Обновить статус оплаты участника СП
  Future<void> updateParticipantPayment(
    int assemblyId,
    String participantName,
    bool isPaid,
  ) async {
    await _apiClient.post(
      '/client/sp/assemblies/$assemblyId/participant-payment',
      data: {'participantName': participantName, 'isPaid': isPaid},
    );
  }
}
