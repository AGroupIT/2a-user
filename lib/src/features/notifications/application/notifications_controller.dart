import 'dart:async';

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
void initializePushNotificationsHandler(
  WidgetRef ref, {
  void Function(String route)? onNavigate,
}) {
  PushNotificationService.onFCMMessageReceived = (RemoteMessage message) {
    try {
      _handleFCMMessage(ref, message);
    } catch (e, stackTrace) {
      debugPrint('🔔 FCM foreground handler error: $e');
      debugPrintStack(stackTrace: stackTrace);
    }
  };
  PushNotificationService.onFCMMessageOpened = (RemoteMessage message) {
    return _handleFCMMessageOpened(ref, message, onNavigate);
  };

  final pushService = ref.read(pushNotificationServiceProvider);
  unawaited(
    pushService.initialize(
      onTap: (payload) =>
          _handleLocalNotificationTapped(ref, payload, onNavigate),
    ),
  );
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
    final item = NotificationItem.fromPushData(
      message.data,
      title: message.notification?.title,
      body: message.notification?.body,
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

Future<void> _handleFCMMessageOpened(
  WidgetRef ref,
  RemoteMessage message,
  void Function(String route)? onNavigate,
) async {
  debugPrint('🔔 FCM opened in notifications handler: ${message.data}');
  await _handleNotificationTapTarget(
    ref,
    NotificationTapTarget(
      route: NotificationItem.routeFromPushData(message.data),
      notificationId: NotificationItem.notificationIdFromData(message.data),
    ),
    onNavigate,
  );
}

Future<void> _handleLocalNotificationTapped(
  WidgetRef ref,
  String? payload,
  void Function(String route)? onNavigate,
) async {
  await _handleNotificationTapTarget(
    ref,
    NotificationItem.tapTargetFromPayload(payload),
    onNavigate,
  );
}

Future<void> _handleNotificationTapTarget(
  WidgetRef ref,
  NotificationTapTarget target,
  void Function(String route)? onNavigate,
) async {
  final notificationId = target.notificationId;
  if (notificationId != null && notificationId.isNotEmpty) {
    unawaited(
      ref
          .read(notificationsControllerProvider.notifier)
          .markRead(notificationId)
          .catchError((Object error, StackTrace stackTrace) {
            debugPrint('🔔 Failed to mark notification as read: $error');
            debugPrintStack(stackTrace: stackTrace);
          }),
    );
  }

  final route = target.route;
  if (route != null && route.isNotEmpty) {
    try {
      onNavigate?.call(route);
    } catch (e, stackTrace) {
      debugPrint('🔔 Notification navigation failed: $e');
      debugPrintStack(stackTrace: stackTrace);
    }
  }
}

/// Контроллер уведомлений
class NotificationsController extends AsyncNotifier<List<NotificationItem>> {
  String? _clientCode;
  Timer? _refreshDebounce;
  bool _isRefreshing = false;
  bool _disposeRegistered = false;

  @override
  Future<List<NotificationItem>> build() async {
    if (!_disposeRegistered) {
      ref.onDispose(() => _refreshDebounce?.cancel());
      _disposeRegistered = true;
    }

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
    final intId = int.tryParse(id);
    if (intId == null) return;

    if (current == null) {
      final repo = ref.read(notificationsRepositoryProvider);
      await repo.markAsRead([intId]);
      refreshDebounced();
      return;
    }

    final idx = current.indexWhere((e) => e.id == id);
    if (idx == -1) {
      final repo = ref.read(notificationsRepositoryProvider);
      await repo.markAsRead([intId]);
      refreshDebounced();
      return;
    }
    if (current[idx].isRead) return;

    // Обновляем UI сразу
    final next = List<NotificationItem>.from(current);
    next[idx] = next[idx].copyWith(isRead: true);
    state = AsyncData(next);
    _updateBadge(next);

    // Отправляем на сервер
    try {
      final repo = ref.read(notificationsRepositoryProvider);
      await repo.markAsRead([intId]);
    } catch (e) {
      // Если ошибка - откатываем
      state = AsyncData(current);
      _updateBadge(current);
    }
  }

  Future<void> markTypesRead(Set<NotificationType> types) async {
    if (types.isEmpty) return;
    final aliases = types
        .expand((type) => type.backendTypeAliases)
        .toSet()
        .toList(growable: false);

    final current = state.value;
    if (current != null) {
      final next = <NotificationItem>[
        for (final n in current)
          types.contains(n.type) && !n.isRead ? n.copyWith(isRead: true) : n,
      ];
      state = AsyncData(next);
      _updateBadge(next);
    }

    try {
      final repo = ref.read(notificationsRepositoryProvider);
      await repo.markTypesAsRead(aliases);
      refreshDebounced();
    } catch (e) {
      if (current != null) {
        state = AsyncData(current);
        _updateBadge(current);
      }
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
    if (_isRefreshing) return;

    _isRefreshing = true;
    final previous = state.value;
    try {
      final repo = ref.read(notificationsRepositoryProvider);
      final page = await repo.fetchPage(
        clientCode: _clientCode!,
        page: 1,
        limit: 50,
      );
      _updateBadge(page.items, backendUnread: page.unreadCount);
      state = AsyncData(page.items);
    } catch (error, stackTrace) {
      if (previous == null) {
        state = AsyncError(error, stackTrace);
      } else {
        debugPrint('🔔 Silent notifications refresh skipped: $error');
      }
    } finally {
      _isRefreshing = false;
    }
  }

  void refreshDebounced() {
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(const Duration(milliseconds: 700), () {
      unawaited(refresh());
    });
  }

  /// Добавить новое уведомление (например, при получении push)
  void addNotification(NotificationItem item) {
    final current = state.value ?? [];
    final next = <NotificationItem>[
      item,
      ...current.where((n) => n.id != item.id),
    ];
    state = AsyncData(next);
    _updateBadge(next);
  }
}

/// Провайдер для подсчёта непрочитанных уведомлений
final unreadCountProvider = Provider<int>((ref) {
  final itemsAsync = ref.watch(notificationsControllerProvider);
  return itemsAsync.value?.where((n) => !n.isRead).length ?? 0;
});
