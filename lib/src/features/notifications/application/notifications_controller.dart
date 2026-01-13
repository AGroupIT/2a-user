import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/push_notification_service.dart';
import '../../clients/application/client_codes_controller.dart';
import '../data/notifications_repository.dart';
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

/// Инициализатор push уведомлений для обновления списка
void initializePushNotificationsHandler(WidgetRef ref) {
  PushNotificationService.onFCMMessageReceived = (RemoteMessage message) {
    _handleFCMMessage(ref, message);
  };
}

void _handleFCMMessage(WidgetRef ref, RemoteMessage message) {
  debugPrint('🔔 FCM received in notifications handler: ${message.data}');
  
  // Получаем активный clientCode
  final clientCode = ref.read(activeClientCodeProvider);
  if (clientCode == null) {
    debugPrint('🔔 No active clientCode, skipping notification update');
    return;
  }
  
  // Пробуем создать NotificationItem из FCM данных
  try {
    final data = message.data;
    final notification = message.notification;
    
    // Создаём уведомление из push данных
    final item = NotificationItem(
      id: data['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      type: _parseNotificationType(data['type']),
      title: notification?.title ?? data['title'] ?? 'Новое уведомление',
      message: notification?.body ?? data['message'] ?? '',
      createdAt: DateTime.now(),
      isRead: false,
      route: data['route'],
      relatedId: data['related_id'],
      oldStatus: data['old_status'],
      newStatus: data['new_status'],
    );
    
    // Добавляем в контроллер
    ref.read(notificationsControllerProvider(clientCode).notifier).addNotification(item);
    debugPrint('🔔 Notification added to list: ${item.title}');
  } catch (e) {
    debugPrint('🔔 Error parsing FCM message: $e');
    // Если не удалось распарсить - просто обновляем список
    ref.read(notificationsControllerProvider(clientCode).notifier).refresh();
  }
}

NotificationType _parseNotificationType(String? type) {
  switch (type?.toLowerCase()) {
    case 'track_status':
    case 'trackstatus':
      return NotificationType.trackStatus;
    case 'assembly_status':
    case 'assemblystatus':
      return NotificationType.assemblyStatus;
    case 'photo_report_status':
    case 'photoreportstatus':
      return NotificationType.photoReportStatus;
    case 'question_status':
    case 'questionstatus':
      return NotificationType.questionStatus;
    case 'chat_message':
    case 'chatmessage':
      return NotificationType.chatMessage;
    case 'news':
      return NotificationType.news;
    case 'invoice':
      return NotificationType.invoice;
    default:
      return NotificationType.news; // По умолчанию
  }
}

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

    // Обновляем UI сразу
    final next = List<NotificationItem>.from(current);
    next[idx] = next[idx].copyWith(isRead: true);
    state = AsyncData(next);
    _updateBadge(next);
    
    // Отправляем на сервер
    try {
      final repo = ref.read(notificationsRepositoryProvider);
      final intId = int.tryParse(id);
      if (intId != null) {
        await repo.markAsRead([intId]);
      }
    } catch (e) {
      // Если ошибка - откатываем
      state = AsyncData(current);
      _updateBadge(current);
    }
  }

  Future<void> markAllRead() async {
    final current = state.value;
    if (current == null) return;
    if (current.every((n) => n.isRead)) return;

    // Обновляем UI сразу
    final next = <NotificationItem>[
      for (final n in current) n.isRead ? n : n.copyWith(isRead: true),
    ];
    state = AsyncData(next);
    _updateBadge(next);
    
    // Отправляем на сервер
    try {
      final repo = ref.read(notificationsRepositoryProvider);
      await repo.markAllAsRead();
    } catch (e) {
      // Если ошибка - откатываем
      state = AsyncData(current);
      _updateBadge(current);
    }
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
