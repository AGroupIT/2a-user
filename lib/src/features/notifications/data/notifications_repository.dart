import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../domain/notification_item.dart';

/// Репозиторий уведомлений
abstract class NotificationsRepository {
  Future<List<NotificationItem>> fetchNotifications({
    required String clientCode,
  });
  
  Future<void> markAsRead(List<int> ids);
  
  Future<void> markAllAsRead();
}

final notificationsRepositoryProvider = Provider<NotificationsRepository>((ref) {
  return RealNotificationsRepository(ref);
});

class RealNotificationsRepository implements NotificationsRepository {
  final Ref _ref;
  
  RealNotificationsRepository(this._ref);
  
  ApiClient get _api => _ref.read(apiClientProvider);

  @override
  Future<List<NotificationItem>> fetchNotifications({
    required String clientCode,
  }) async {
    try {
      final response = await _api.get(
        '/notifications',
        queryParameters: {
          'limit': 100,
        },
      );
      
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final notificationsJson = data['notifications'] as List<dynamic>? ?? [];
        
        return notificationsJson
            .map((json) => NotificationItem.fromJson(json as Map<String, dynamic>))
            .toList();
      }
      return [];
    } on DioException catch (e) {
      debugPrint('Error loading notifications: $e');
      rethrow;
    }
  }

  @override
  Future<void> markAsRead(List<int> ids) async {
    try {
      await _api.patch(
        '/notifications',
        data: {
          'ids': ids,
        },
      );
    } on DioException catch (e) {
      debugPrint('Error marking notifications as read: $e');
      rethrow;
    }
  }

  @override
  Future<void> markAllAsRead() async {
    try {
      await _api.patch(
        '/notifications',
        data: {
          'markAllAsRead': true,
        },
      );
    } on DioException catch (e) {
      debugPrint('Error marking all notifications as read: $e');
      rethrow;
    }
  }
}
