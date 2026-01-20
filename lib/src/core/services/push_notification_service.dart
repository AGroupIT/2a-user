import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../firebase_options.dart';
import '../../features/notifications/domain/notification_item.dart';
import 'platform_helper.dart';

/// Проверка платформы (безопасно для Web)
bool get _isMobilePlatform => isMobilePlatformImpl();

/// Проверка iOS (безопасно для Web)
bool get _isIOS => isIOSImpl();

/// Проверка Desktop (безопасно для Web)
bool get _isDesktop => isDesktopImpl();

/// Background message handler (must be top-level)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (kDebugMode) {
    debugPrint('🔔 Background FCM message: ${message.messageId}');
  }
}

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
  static final PushNotificationService _instance = PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();
  
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  static FirebaseMessaging? _messaging;
  static bool _isInitialized = false;

  // Callback для обработки нажатия на уведомление
  void Function(String? route)? onNotificationTap;
  
  // Callback для обработки FCM сообщений
  static Function(RemoteMessage)? onFCMMessageReceived;

  /// Статическая инициализация Firebase (вызывать из main)
  static Future<void> initializeFirebase() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      
      // Firebase Messaging поддерживается на Web, Android, iOS
      if (kIsWeb || _isMobilePlatform) {
        _messaging = FirebaseMessaging.instance;
        
        // Запрос разрешений
        final settings = await _messaging!.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
        
        debugPrint('🔔 FCM Permission: ${settings.authorizationStatus}');
        
        // Background handler
        FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
        
        // Foreground handler
        FirebaseMessaging.onMessage.listen((message) {
          debugPrint('🔔 Foreground FCM: ${message.notification?.title}');
          onFCMMessageReceived?.call(message);
          _showFCMNotification(message);
        });
        
        // Message opened app
        FirebaseMessaging.onMessageOpenedApp.listen((message) {
          debugPrint('🔔 FCM opened app: ${message.notification?.title}');
          // Handle navigation based on message data
        });
      } else {
        debugPrint('🔔 FCM not supported on this platform (Windows/Linux/macOS Desktop)');
      }
      
      debugPrint('🔔 Firebase initialized');
    } catch (e) {
      debugPrint('🔔 Firebase init error: $e');
    }
  }
  
  /// Показать локальное уведомление из FCM
  static Future<void> _showFCMNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;
    
    final plugin = FlutterLocalNotificationsPlugin();
    
    const androidDetails = AndroidNotificationDetails(
      'fcm_channel',
      'Push уведомления',
      channelDescription: 'Уведомления от сервера',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    
    await plugin.show(
      message.hashCode,
      notification.title,
      notification.body,
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: message.data['route'],
    );
  }
  
  /// VAPID Key для Web Push (Firebase Console → Project Settings → Cloud Messaging)
  static const String _vapidKey = 'BN84z0kGwWRFRalLMJ-HlMPVYBp5Tu7QnsGiACoT-ODg7VkwtFV_kdDhFHapsr5BguDgeBs0E6Pe2aY2_0fMshQ';
  
  /// Получить FCM токен
  static Future<String?> getFCMToken() async {
    try {
      // Для Web нужен VAPID ключ
      if (kIsWeb) {
        return await _messaging?.getToken(vapidKey: _vapidKey);
      }
      return await _messaging?.getToken();
    } catch (e) {
      debugPrint('🔔 Error getting FCM token: $e');
      return null;
    }
  }
  
  /// Подписаться на топик
  static Future<void> subscribeToTopic(String topic) async {
    // Topic subscription не поддерживается на Web
    if (kIsWeb) {
      debugPrint('🔔 Topic subscription not supported on Web');
      return;
    }
    try {
      await _messaging?.subscribeToTopic(topic);
      debugPrint('🔔 Subscribed to: $topic');
    } catch (e) {
      debugPrint('🔔 Subscribe error: $e');
    }
  }
  
  /// Отписаться от топика
  static Future<void> unsubscribeFromTopic(String topic) async {
    // Topic unsubscription не поддерживается на Web
    if (kIsWeb) {
      debugPrint('🔔 Topic unsubscription not supported on Web');
      return;
    }
    try {
      await _messaging?.unsubscribeFromTopic(topic);
    } catch (e) {
      debugPrint('🔔 Unsubscribe error: $e');
    }
  }

  /// Инициализация локальных уведомлений
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
    if (_isIOS) {
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
      case NotificationType.paymentChatMessage:
        return _ChannelConfig(
          id: 'payment_chat_channel',
          name: 'Чат по оплате',
          description: 'Уведомления о новых сообщениях в чате по оплате',
        );
      case NotificationType.news:
        return _ChannelConfig(
          id: 'news_channel',
          name: 'Новости',
          description: 'Уведомления о новых новостях',
        );
      case NotificationType.serviceRules:
        return _ChannelConfig(
          id: 'service_rules_channel',
          name: 'Правила оказания услуг',
          description: 'Уведомления о новых правилах оказания услуг',
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

  /// Показать уведомление о новом сообщении в чате по оплате
  Future<void> showPaymentChatMessageNotification({
    required String senderName,
    required String message,
    int? notificationId,
  }) async {
    final item = NotificationItem.paymentChatMessage(
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
    // Badge не поддерживается на Desktop
    if (_isDesktop) {
      return;
    }
    
    // Используем flutter_local_notifications для управления badge
    // На iOS badge управляется через badgeNumber в notification
    // На Android badges управляются через каналы уведомлений
    try {
      if (count <= 0) {
        // Отменяем все уведомления для сброса badge
        await _notifications.cancelAll();
      }
      // Примечание: для установки badge count нужно показать notification с badgeNumber
      // или использовать platform-specific API
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
    if (!_isInitialized) return;
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
