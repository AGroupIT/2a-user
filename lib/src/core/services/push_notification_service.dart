import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_app_badger/flutter_app_badger.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/notifications/domain/notification_item.dart';

/// Провайдер для сервиса push-уведомлений
final pushNotificationServiceProvider = Provider<PushNotificationService>((
  ref,
) {
  return PushNotificationService();
});

/// Простой Notifier для bool состояния
class IsChatScreenOpenNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  
  void set(bool value) => state = value;
}

/// Провайдер для отслеживания открытого экрана чата
final isChatScreenOpenProvider = NotifierProvider<IsChatScreenOpenNotifier, bool>(
  IsChatScreenOpenNotifier.new,
);

/// Простой Notifier для int состояния
class UnreadNotificationsCountNotifier extends Notifier<int> {
  @override
  int build() => 0;
  
  void set(int value) => state = value;
}

/// Провайдер для счётчика непрочитанных уведомлений
final unreadNotificationsCountProvider = NotifierProvider<UnreadNotificationsCountNotifier, int>(
  UnreadNotificationsCountNotifier.new,
);

/// Сервис для управления push-уведомлениями и badge на иконке приложения
class PushNotificationService {
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  // Callback для обработки нажатия на уведомление
  void Function(String? route)? onNotificationTap;

  /// Инициализация сервиса уведомлений
  Future<void> initialize({void Function(String? route)? onTap}) async {
    if (_isInitialized) {
      onNotificationTap = onTap;
      return;
    }

    onNotificationTap = onTap;

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Request permissions on iOS
    if (Platform.isIOS) {
      await _notifications
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    }

    _isInitialized = true;
  }

  void _onNotificationTapped(NotificationResponse response) {
    final payload = response.payload;
    onNotificationTap?.call(payload);
  }

  /// Получить настройки канала для типа уведомления
  _ChannelConfig _getChannelConfig(NotificationType type) {
    switch (type) {
      case NotificationType.trackStatus:
        return _ChannelConfig(
          id: 'track_status_channel',
          name: 'Статусы треков',
          description: 'Уведомления об изменении статусов трек-номеров',
        );
      case NotificationType.assemblyStatus:
        return _ChannelConfig(
          id: 'assembly_status_channel',
          name: 'Статусы сборок',
          description: 'Уведомления об изменении статусов сборок',
        );
      case NotificationType.photoReportStatus:
        return _ChannelConfig(
          id: 'photo_report_channel',
          name: 'Фотоотчёты',
          description: 'Уведомления о готовности фотоотчётов',
        );
      case NotificationType.questionStatus:
        return _ChannelConfig(
          id: 'question_channel',
          name: 'Ответы на вопросы',
          description: 'Уведомления о получении ответов на вопросы',
        );
      case NotificationType.chatMessage:
        return _ChannelConfig(
          id: 'chat_channel',
          name: 'Чат поддержки',
          description: 'Уведомления о новых сообщениях в чате поддержки',
        );
      case NotificationType.news:
        return _ChannelConfig(
          id: 'news_channel',
          name: 'Новости',
          description: 'Уведомления о новых новостях',
        );
      case NotificationType.invoice:
        return _ChannelConfig(
          id: 'invoice_channel',
          name: 'Счета',
          description: 'Уведомления о новых счетах на оплату',
        );
    }
  }

  /// Показать push-уведомление на основе NotificationItem
  Future<void> showNotification(NotificationItem item) async {
    if (!_isInitialized) {
      await initialize();
    }

    final channelConfig = _getChannelConfig(item.type);

    final androidDetails = AndroidNotificationDetails(
      channelConfig.id,
      channelConfig.name,
      channelDescription: channelConfig.description,
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
      color: const Color(0xFFfe3301),
      enableVibration: true,
      playSound: true,
      category: _getCategoryForType(item.type),
      styleInformation: BigTextStyleInformation(
        item.message,
        contentTitle: item.title,
        summaryText: item.type.displayName,
      ),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'default',
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      item.id.hashCode,
      item.title,
      item.message,
      details,
      payload: item.route,
    );
  }

  AndroidNotificationCategory _getCategoryForType(NotificationType type) {
    switch (type) {
      case NotificationType.chatMessage:
        return AndroidNotificationCategory.message;
      case NotificationType.trackStatus:
      case NotificationType.assemblyStatus:
        return AndroidNotificationCategory.status;
      case NotificationType.news:
        return AndroidNotificationCategory.recommendation;
      default:
        return AndroidNotificationCategory.event;
    }
  }

  /// Показать уведомление о новом сообщении в чате
  Future<void> showChatMessageNotification({
    required String senderName,
    required String message,
    int? notificationId,
  }) async {
    final item = NotificationItem.chatMessage(
      id:
          notificationId?.toString() ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      senderName: senderName,
      messagePreview: message,
      createdAt: DateTime.now(),
    );
    await showNotification(item);
  }

  /// Показать уведомление об изменении статуса трека
  Future<void> showTrackStatusNotification({
    required String trackNumber,
    required String oldStatus,
    required String newStatus,
  }) async {
    final item = NotificationItem.trackStatusChange(
      id: 'track_${DateTime.now().millisecondsSinceEpoch}',
      trackNumber: trackNumber,
      oldStatus: oldStatus,
      newStatus: newStatus,
      createdAt: DateTime.now(),
    );
    await showNotification(item);
  }

  /// Показать уведомление об изменении статуса сборки
  Future<void> showAssemblyStatusNotification({
    required String assemblyId,
    required String oldStatus,
    required String newStatus,
  }) async {
    final item = NotificationItem.assemblyStatusChange(
      id: 'asm_${DateTime.now().millisecondsSinceEpoch}',
      assemblyId: assemblyId,
      oldStatus: oldStatus,
      newStatus: newStatus,
      createdAt: DateTime.now(),
    );
    await showNotification(item);
  }

  /// Показать уведомление о фотоотчёте
  Future<void> showPhotoReportNotification({
    required String trackNumber,
    required String status,
  }) async {
    final item = NotificationItem.photoReportStatusChange(
      id: 'photo_${DateTime.now().millisecondsSinceEpoch}',
      trackNumber: trackNumber,
      status: status,
      createdAt: DateTime.now(),
    );
    await showNotification(item);
  }

  /// Показать уведомление об ответе на вопрос
  Future<void> showQuestionAnsweredNotification({
    required String trackNumber,
    required String answer,
  }) async {
    final item = NotificationItem.questionAnswered(
      id: 'question_${DateTime.now().millisecondsSinceEpoch}',
      trackNumber: trackNumber,
      answer: answer,
      createdAt: DateTime.now(),
    );
    await showNotification(item);
  }

  /// Показать уведомление о новой новости
  Future<void> showNewsNotification({
    required String newsId,
    required String title,
    required String preview,
  }) async {
    final item = NotificationItem.news(
      id: 'news_${DateTime.now().millisecondsSinceEpoch}',
      newsTitle: title,
      newsPreview: preview,
      newsId: newsId,
      createdAt: DateTime.now(),
    );
    await showNotification(item);
  }

  /// Показать уведомление о новом счёте
  Future<void> showInvoiceNotification({
    required String invoiceNumber,
    required String amount,
  }) async {
    final item = NotificationItem.invoice(
      id: 'invoice_${DateTime.now().millisecondsSinceEpoch}',
      invoiceNumber: invoiceNumber,
      amount: amount,
      createdAt: DateTime.now(),
    );
    await showNotification(item);
  }

  /// Обновить badge на иконке приложения
  Future<void> updateBadgeCount(int count) async {
    try {
      final isSupported = await FlutterAppBadger.isAppBadgeSupported();
      if (!isSupported) return;

      if (count > 0) {
        await FlutterAppBadger.updateBadgeCount(count);
      } else {
        await FlutterAppBadger.removeBadge();
      }
    } catch (e) {
      debugPrint('Error updating badge: $e');
    }
  }

  /// Очистить badge
  Future<void> clearBadge() async {
    await updateBadgeCount(0);
  }

  /// Отменить все уведомления
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
    await clearBadge();
  }

  /// Отменить конкретное уведомление
  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }
}

class _ChannelConfig {
  final String id;
  final String name;
  final String description;

  const _ChannelConfig({
    required this.id,
    required this.name,
    required this.description,
  });
}
