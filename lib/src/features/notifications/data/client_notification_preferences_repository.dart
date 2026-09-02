import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../domain/client_notification_preference.dart';

class ClientNotificationPreferencesRepository {
  final ApiClient _apiClient;

  const ClientNotificationPreferencesRepository(this._apiClient);

  Future<List<ClientNotificationPreferenceItem>> fetch() async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/client/notification-preferences',
    );
    final data = response.data?['data'] as Map<String, dynamic>?;
    final items = data?['items'] as List<dynamic>? ?? const [];
    return items
        .whereType<Map<String, dynamic>>()
        .map(ClientNotificationPreferenceItem.fromJson)
        .where((item) => item.key.isNotEmpty)
        .toList(growable: false);
  }

  Future<ClientNotificationPreferenceItem> update({
    required String key,
    required bool enabled,
  }) async {
    final response = await _apiClient.patch<Map<String, dynamic>>(
      '/client/notification-preferences',
      data: {'key': key, 'enabled': enabled},
    );
    final data = response.data?['data'] as Map<String, dynamic>?;
    if (data == null) {
      throw StateError('Notification preference response has no data');
    }
    return ClientNotificationPreferenceItem.fromJson(data);
  }
}

final clientNotificationPreferencesRepositoryProvider =
    Provider<ClientNotificationPreferencesRepository>((ref) {
      return ClientNotificationPreferencesRepository(
        ref.read(apiClientProvider),
      );
    });
