import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Типы уведомлений в приложении
enum NotificationType {
  /// Изменение статуса трек-номера
  trackStatus,

  /// Изменение статуса сборки
  assemblyStatus,

  /// Изменение статуса фотоотчёта
  photoReportStatus,

  /// Изменение статуса вопроса (ответ получен)
  questionStatus,

  /// Новое сообщение в чате с поддержкой
  chatMessage,

  /// Новая новость
  news,

  /// Новый счёт на оплату
  invoice,
}

extension NotificationTypeExtension on NotificationType {
  String get displayName {
    switch (this) {
      case NotificationType.trackStatus:
        return 'Статус трека';
      case NotificationType.assemblyStatus:
        return 'Статус сборки';
      case NotificationType.photoReportStatus:
        return 'Фотоотчёт';
      case NotificationType.questionStatus:
        return 'Ответ на вопрос';
      case NotificationType.chatMessage:
        return 'Чат поддержки';
      case NotificationType.news:
        return 'Новости';
      case NotificationType.invoice:
        return 'Счёт';
    }
  }

  IconData get icon {
    switch (this) {
      case NotificationType.trackStatus:
        return Icons.local_shipping_rounded;
      case NotificationType.assemblyStatus:
        return Icons.inventory_2_rounded;
      case NotificationType.photoReportStatus:
        return Icons.photo_camera_rounded;
      case NotificationType.questionStatus:
        return Icons.question_answer_rounded;
      case NotificationType.chatMessage:
        return Icons.chat_bubble_rounded;
      case NotificationType.news:
        return Icons.newspaper_rounded;
      case NotificationType.invoice:
        return Icons.receipt_long_rounded;
    }
  }

  String? get defaultRoute {
    switch (this) {
      case NotificationType.trackStatus:
      case NotificationType.assemblyStatus:
      case NotificationType.photoReportStatus:
      case NotificationType.questionStatus:
        return '/tracks';
      case NotificationType.chatMessage:
        return '/support';
      case NotificationType.news:
        return '/news';
      case NotificationType.invoice:
        return '/invoices';
    }
  }
}

@immutable
class NotificationItem {
  final String id;
  final NotificationType type;
  final String title;
  final String message;
  final DateTime createdAt;
  final bool isRead;
  final String? route;

  /// ID связанного объекта (трек, сборка, вопрос и т.д.)
  final String? relatedId;

  /// Старый статус (для уведомлений об изменении статуса)
  final String? oldStatus;

  /// Новый статус (для уведомлений об изменении статуса)
  final String? newStatus;

  const NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.createdAt,
    required this.isRead,
    this.route,
    this.relatedId,
    this.oldStatus,
    this.newStatus,
  });

  NotificationItem copyWith({bool? isRead}) {
    return NotificationItem(
      id: id,
      type: type,
      title: title,
      message: message,
      createdAt: createdAt,
      isRead: isRead ?? this.isRead,
      route: route,
      relatedId: relatedId,
      oldStatus: oldStatus,
      newStatus: newStatus,
    );
  }

  /// Парсинг из JSON (API response)
  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    final typeStr = json['type'] as String? ?? 'track_update';
    final data = json['data'] as Map<String, dynamic>? ?? {};
    
    // Определяем тип уведомления
    final type = _parseNotificationType(typeStr);
    
    // Определяем маршрут
    String? route = _getRouteForType(type, data);
    
    return NotificationItem(
      id: json['id'].toString(),
      type: type,
      title: json['title'] as String? ?? '',
      message: json['body'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
      isRead: json['isRead'] as bool? ?? false,
      route: route,
      relatedId: data['trackNumber'] as String? ?? 
                 data['assemblyNumber'] as String? ?? 
                 data['invoiceNumber'] as String? ??
                 data['trackId']?.toString() ??
                 data['assemblyId']?.toString() ??
                 data['invoiceId']?.toString(),
      oldStatus: data['oldStatus'] as String?,
      newStatus: data['newStatus'] as String? ?? data['status'] as String?,
    );
  }
  
  /// Парсинг типа уведомления из строки API
  static NotificationType _parseNotificationType(String typeStr) {
    switch (typeStr) {
      case 'track_update':
      case 'track_status_changed':
      case 'track_status_change':
        return NotificationType.trackStatus;
      case 'assembly_update':
      case 'assembly_status_changed':
      case 'assembly_status_change':
        return NotificationType.assemblyStatus;
      case 'photo_report_update':
      case 'photo_report_ready':
      case 'photo_request_completed':
        return NotificationType.photoReportStatus;
      case 'question_answered':
      case 'question_update':
        return NotificationType.questionStatus;
      case 'chat_message':
      case 'new_message':
        return NotificationType.chatMessage;
      case 'news':
      case 'new_news':
        return NotificationType.news;
      case 'invoice':
      case 'new_invoice':
      case 'invoice_created':
        return NotificationType.invoice;
      default:
        return NotificationType.trackStatus;
    }
  }
  
  /// Получить маршрут для типа уведомления
  static String? _getRouteForType(NotificationType type, Map<String, dynamic> data) {
    switch (type) {
      case NotificationType.trackStatus:
      case NotificationType.assemblyStatus:
      case NotificationType.photoReportStatus:
      case NotificationType.questionStatus:
        return '/tracks';
      case NotificationType.chatMessage:
        return '/support';
      case NotificationType.news:
        final newsId = data['newsId'];
        if (newsId != null) return '/news/$newsId';
        return '/news';
      case NotificationType.invoice:
        return '/invoices';
    }
  }

  /// Создать уведомление об изменении статуса трека
  factory NotificationItem.trackStatusChange({
    required String id,
    required String trackNumber,
    required String oldStatus,
    required String newStatus,
    required DateTime createdAt,
    bool isRead = false,
  }) {
    return NotificationItem(
      id: id,
      type: NotificationType.trackStatus,
      title: 'Статус трека изменён',
      message: '$trackNumber: $oldStatus → $newStatus',
      createdAt: createdAt,
      isRead: isRead,
      route: '/tracks',
      relatedId: trackNumber,
      oldStatus: oldStatus,
      newStatus: newStatus,
    );
  }

  /// Создать уведомление об изменении статуса сборки
  factory NotificationItem.assemblyStatusChange({
    required String id,
    required String assemblyId,
    required String oldStatus,
    required String newStatus,
    required DateTime createdAt,
    bool isRead = false,
  }) {
    return NotificationItem(
      id: id,
      type: NotificationType.assemblyStatus,
      title: 'Статус сборки изменён',
      message: 'Сборка $assemblyId: $oldStatus → $newStatus',
      createdAt: createdAt,
      isRead: isRead,
      route: '/tracks',
      relatedId: assemblyId,
      oldStatus: oldStatus,
      newStatus: newStatus,
    );
  }

  /// Создать уведомление об изменении статуса фотоотчёта
  factory NotificationItem.photoReportStatusChange({
    required String id,
    required String trackNumber,
    required String status,
    required DateTime createdAt,
    bool isRead = false,
  }) {
    return NotificationItem(
      id: id,
      type: NotificationType.photoReportStatus,
      title: 'Фотоотчёт готов',
      message: '$trackNumber: $status',
      createdAt: createdAt,
      isRead: isRead,
      route: '/tracks',
      relatedId: trackNumber,
      newStatus: status,
    );
  }

  /// Создать уведомление об ответе на вопрос
  factory NotificationItem.questionAnswered({
    required String id,
    required String trackNumber,
    required String answer,
    required DateTime createdAt,
    bool isRead = false,
  }) {
    return NotificationItem(
      id: id,
      type: NotificationType.questionStatus,
      title: 'Ответ на вопрос',
      message: '$trackNumber: $answer',
      createdAt: createdAt,
      isRead: isRead,
      route: '/tracks',
      relatedId: trackNumber,
    );
  }

  /// Создать уведомление о новом сообщении в чате
  factory NotificationItem.chatMessage({
    required String id,
    required String senderName,
    required String messagePreview,
    required DateTime createdAt,
    bool isRead = false,
  }) {
    return NotificationItem(
      id: id,
      type: NotificationType.chatMessage,
      title: senderName,
      message: messagePreview,
      createdAt: createdAt,
      isRead: isRead,
      route: '/support',
    );
  }

  /// Создать уведомление о новой новости
  factory NotificationItem.news({
    required String id,
    required String newsTitle,
    required String newsPreview,
    required String newsId,
    required DateTime createdAt,
    bool isRead = false,
  }) {
    return NotificationItem(
      id: id,
      type: NotificationType.news,
      title: newsTitle,
      message: newsPreview,
      createdAt: createdAt,
      isRead: isRead,
      route: '/news/$newsId',
      relatedId: newsId,
    );
  }

  /// Создать уведомление о новом счёте
  factory NotificationItem.invoice({
    required String id,
    required String invoiceNumber,
    required String amount,
    required DateTime createdAt,
    bool isRead = false,
  }) {
    return NotificationItem(
      id: id,
      type: NotificationType.invoice,
      title: 'Новый счёт',
      message: '$invoiceNumber на сумму $amount',
      createdAt: createdAt,
      isRead: isRead,
      route: '/invoices',
      relatedId: invoiceNumber,
    );
  }
}
