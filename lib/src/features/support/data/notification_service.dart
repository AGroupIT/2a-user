import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

class NotificationService {
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
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
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
    }

    _isInitialized = true;
  }

  void _onNotificationTapped(NotificationResponse response) {
    // Handle notification tap - can navigate to chat screen
    // This would be handled by the router
  }

  Future<void> showChatMessageNotification({
    required String senderName,
    required String message,
    int? notificationId,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    // Truncate message if too long
    final truncatedMessage = message.length > 100 
        ? '${message.substring(0, 100)}...' 
        : message;

    final androidDetails = AndroidNotificationDetails(
      'support_chat_channel',
      'Чат поддержки',
      channelDescription: 'Уведомления о новых сообщениях в чате поддержки',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
      color: const Color(0xFFfe3301),
      enableVibration: true,
      playSound: true,
      category: AndroidNotificationCategory.message,
      styleInformation: BigTextStyleInformation(
        truncatedMessage,
        contentTitle: senderName,
        summaryText: 'Чат поддержки 2A',
      ),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'default',
      badgeNumber: 1,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      notificationId ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
      senderName,
      truncatedMessage,
      details,
      payload: 'chat_message',
    );
  }

  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }
}
