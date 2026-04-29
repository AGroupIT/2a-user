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
final notificationsControllerProvider =
    AsyncNotifierProvider.autoDispose<
      NotificationsController,
      List<NotificationItem>
    >(NotificationsController.new);

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
    ref.read(notificationsControllerProvider.notifier).addNotification(item);
    debugPrint('🔔 Notification added to list: ${item.title}');
  } catch (e) {
    debugPrint('🔔 Error parsing FCM message: $e');
    // Если не удалось распарсить - просто обновляем список
    ref.read(notificationsControllerProvider.notifier).refresh();
  }
}

// PU-H3: синхронизировано со списком backend-типов в lib/notifications.ts
// и с NotificationItem._parseNotificationType. Если backend пришлёт новый
// тип, которого здесь нет, — fallback на trackStatus (как в основном
// парсере), а НЕ на news (раньше дефолт был news, что давало
// «случайные» переходы на /news для незнакомых push-ов, например для
// payment_chat_message и service_rule_created).
NotificationType _parseNotificationType(String? type) {
  switch (type?.toLowerCase()) {
    case 'track_status':
    case 'trackstatus':
    case 'track_created':
    case 'track_update':
    case 'track_status_changed':
      return NotificationType.trackStatus;
    case 'assembly_status':
    case 'assemblystatus':
    case 'assembly_update':
    case 'assembly_status_changed':
      return NotificationType.assemblyStatus;
    case 'photo_report_status':
    case 'photoreportstatus':
    case 'photo_report_update':
    case 'photo_report_ready':
    case 'photo_request':
    case 'photo_request_completed':
    case 'photo_request_status_changed':
      return NotificationType.photoReportStatus;
    case 'question_status':
    case 'questionstatus':
    case 'question_answered':
    case 'question_update':
    case 'question_status_changed':
      return NotificationType.questionStatus;
    case 'chat_message':
    case 'chatmessage':
    case 'support_message':
    case 'new_message':
      return NotificationType.chatMessage;
    case 'payment_chat_message':
    case 'payment_message':
      return NotificationType.paymentChatMessage;
    case 'news':
    case 'news_created':
    case 'new_news':
      return NotificationType.news;
    case 'service_rule_created':
    case 'service_rule':
    case 'service_rules':
      return NotificationType.serviceRules;
    case 'invoice':
    case 'new_invoice':
    case 'invoice_created':
    case 'invoice_status_changed':
    case 'invoice_paid':
      return NotificationType.invoice;
    default:
      // Безопасный fallback — trackStatus, чтобы непонятный push открывал
      // главный список треков, а не утаскивал юзера в /news.
      return NotificationType.trackStatus;
  }
}

/// Контроллер уведомлений
class NotificationsController extends AsyncNotifier<List<NotificationItem>> {
  String? _clientCode;

  @override
  Future<List<NotificationItem>> build() async {
    // В Riverpod 3.x family notifier получает arg через специальный механизм
    // Мы используем workaround через активный clientCode
    _clientCode = ref.watch(activeClientCodeProvider);
    if (_clientCode == null) {
      return [];
    }

    final repo = ref.watch(notificationsRepositoryProvider);
    // PU-M13: используем page-based fetch, чтобы получить unreadCount из
    // backend (работает корректно при >100 уведомлений) и иметь возможность
    // в будущем подключить loadMore.
    final page = await repo.fetchPage(
      clientCode: _clientCode!,
      page: 1,
      limit: 50,
    );
    _updateBadge(page.items, backendUnread: page.unreadCount);
    return page.items;
  }

  void _updateBadge(List<NotificationItem> items, {int? backendUnread}) {
    // PU-M13: предпочитаем unreadCount из backend, fallback на локальный
    // подсчёт, если функция вызвана не из fetch (например, после markRead).
    final unreadCount = backendUnread ?? items.where((n) => !n.isRead).length;
    ref.read(unreadNotificationsCountProvider.notifier).set(unreadCount);

    // Обновляем badge на иконке приложения
    try {
      final pushService = ref.read(pushNotificationServiceProvider);
      pushService.updateBadgeCount(unreadCount);
    } catch (e) {
      debugPrint('🔔 Badge update skipped: $e');
    }
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
    if (_clientCode == null) return;

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(notificationsRepositoryProvider);
      final items = await repo.fetchNotifications(clientCode: _clientCode!);
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
final unreadCountProvider = Provider<int>((ref) {
  final itemsAsync = ref.watch(notificationsControllerProvider);
  return itemsAsync.value?.where((n) => !n.isRead).length ?? 0;
});
