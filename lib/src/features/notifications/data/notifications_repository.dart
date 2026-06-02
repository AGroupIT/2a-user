import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/cache/stale_data_cache.dart';
import '../../../core/network/api_client.dart';
import '../domain/notification_item.dart';

/// PU-M13: страница уведомлений вместе с метаданными от backend.
/// Backend `/api/notifications` отдаёт `{ notifications, unreadCount,
/// pagination: { page, limit, total, totalPages } }` — фронт раньше брал
/// только `notifications` и считал `unreadCount` локально, что давало
/// неверный badge на >100 уведомлениях (truncate `limit=100`).
class NotificationsPage {
  const NotificationsPage({
    required this.items,
    required this.total,
    required this.unreadCount,
    required this.page,
    required this.limit,
  });

  final List<NotificationItem> items;
  final int total;
  final int unreadCount;
  final int page;
  final int limit;

  bool get hasMore => page * limit < total;
}

/// Репозиторий уведомлений
abstract class NotificationsRepository {
  Future<List<NotificationItem>> fetchNotifications({
    required String clientCode,
  });

  /// PU-M13: page-based fetch с unreadCount от backend.
  Future<NotificationsPage> fetchPage({
    required String clientCode,
    int page = 1,
    int limit = 50,
  });

  Future<void> markAsRead(List<int> ids);

  Future<void> markAllAsRead();

  Future<void> markTypesAsRead(List<String> types);
}

final notificationsRepositoryProvider = Provider<NotificationsRepository>((
  ref,
) {
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
    final page = await fetchPage(clientCode: clientCode, page: 1, limit: 100);
    return page.items;
  }

  @override
  Future<NotificationsPage> fetchPage({
    required String clientCode,
    int page = 1,
    int limit = 50,
  }) async {
    try {
      final queryParams = {'page': page, 'limit': limit};
      final data = await StaleDataCache.getJson(
        ref: _ref,
        cacheKey: StaleDataCache.buildKey('notifications_page', {
          'clientCode': clientCode,
          ...queryParams,
        }),
        label: 'уведомления',
        request: () => _api.get('/notifications', queryParameters: queryParams),
      );

      final notificationsJson = data['notifications'] as List<dynamic>? ?? [];
      final items = notificationsJson
          .map(
            (json) => NotificationItem.fromJson(json as Map<String, dynamic>),
          )
          .toList();

      // unreadCount пишется backend'ом по полному скоупу пользователя,
      // не по странице — поэтому badge корректен даже при pagination.
      final unreadCount = (data['unreadCount'] as num?)?.toInt() ?? 0;
      final paginationRaw = data['pagination'];
      final pagination = paginationRaw is Map<String, dynamic>
          ? paginationRaw
          : const <String, dynamic>{};
      final total = (pagination['total'] as num?)?.toInt() ?? items.length;
      final returnedPage = (pagination['page'] as num?)?.toInt() ?? page;
      final returnedLimit = (pagination['limit'] as num?)?.toInt() ?? limit;

      return NotificationsPage(
        items: items,
        total: total,
        unreadCount: unreadCount,
        page: returnedPage,
        limit: returnedLimit,
      );
    } catch (e) {
      debugPrint('Error loading notifications page: $e');
      rethrow;
    }
  }

  @override
  Future<void> markAsRead(List<int> ids) async {
    try {
      await _api.patch('/notifications', data: {'ids': ids});
    } on DioException catch (e) {
      debugPrint('Error marking notifications as read: $e');
      rethrow;
    }
  }

  @override
  Future<void> markAllAsRead() async {
    try {
      await _api.patch('/notifications', data: {'markAllAsRead': true});
    } on DioException catch (e) {
      debugPrint('Error marking all notifications as read: $e');
      rethrow;
    }
  }

  @override
  Future<void> markTypesAsRead(List<String> types) async {
    if (types.isEmpty) return;
    try {
      await _api.patch('/notifications', data: {'types': types});
    } on DioException catch (e) {
      debugPrint('Error marking notification types as read: $e');
      rethrow;
    }
  }
}
