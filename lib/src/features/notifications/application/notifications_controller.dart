import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/push_notification_service.dart';
import '../data/fake_notifications_repository.dart';
import '../domain/notification_item.dart';

/// Состояние уведомлений (для совместимости)
class NotificationsState {
  final List<NotificationItem> items;
  final bool isLoading;
  final String? error;

  const NotificationsState({
    this.items = const [],
    this.isLoading = false,
    this.error,
  });

  NotificationsState copyWith({
    List<NotificationItem>? items,
    bool? isLoading,
    String? error,
  }) {
    return NotificationsState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Провайдер для уведомлений с поддержкой clientCode
/// Riverpod 3.x: family provider с конструктором, принимающим arg
final notificationsControllerProvider = AsyncNotifierProvider.autoDispose
    .family<NotificationsController, List<NotificationItem>, String>(
  NotificationsController.new,
);

/// Контроллер уведомлений
class NotificationsController extends AsyncNotifier<List<NotificationItem>> {
  final String clientCode;
  
  NotificationsController(this.clientCode);

  @override
  Future<List<NotificationItem>> build() async {
    final repo = ref.watch(notificationsRepositoryProvider);
    final items = await repo.fetchNotifications(clientCode: clientCode);
    _updateBadge(items);
    return items;
  }

  void _updateBadge(List<NotificationItem> items) {
    final unreadCount = items.where((n) => !n.isRead).length;
    ref.read(unreadNotificationsCountProvider.notifier).set(unreadCount);

    // Обновляем badge на иконке приложения
    final pushService = ref.read(pushNotificationServiceProvider);
    pushService.updateBadgeCount(unreadCount);
  }

  Future<void> markRead(String id) async {
    final current = state.value;
    if (current == null) return;

    final idx = current.indexWhere((e) => e.id == id);
    if (idx == -1) return;
    if (current[idx].isRead) return;

    final next = List<NotificationItem>.from(current);
    next[idx] = next[idx].copyWith(isRead: true);
    state = AsyncData(next);
    _updateBadge(next);
  }

  Future<void> markAllRead() async {
    final current = state.value;
    if (current == null) return;
    if (current.every((n) => n.isRead)) return;

    final next = <NotificationItem>[
      for (final n in current) n.isRead ? n : n.copyWith(isRead: true),
    ];
    state = AsyncData(next);
    _updateBadge(next);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(notificationsRepositoryProvider);
      final items = await repo.fetchNotifications(clientCode: clientCode);
      _updateBadge(items);
      return items;
    });
  }

  /// Добавить новое уведомление (например, при получении push)
  void addNotification(NotificationItem item) {
    final current = state.value ?? [];
    final next = <NotificationItem>[item, ...current];
    state = AsyncData(next);
    _updateBadge(next);
  }
}

/// Провайдер для подсчёта непрочитанных уведомлений
final unreadCountProvider = Provider.family<int, String>((ref, clientCode) {
  final itemsAsync = ref.watch(notificationsControllerProvider(clientCode));
  return itemsAsync.value?.where((n) => !n.isRead).length ?? 0;
});
