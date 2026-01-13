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

  /// Новое сообщение в чате по оплате
  paymentChatMessage,

  /// Новая новость
  news,

  /// Новые правила оказания услуг
  serviceRules,

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
      case NotificationType.paymentChatMessage:
        return 'Чат по оплате';
      case NotificationType.news:
        return 'Новости';
      case NotificationType.serviceRules:
        return 'Правила оказания услуг';
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
      case NotificationType.paymentChatMessage:
        return Icons.account_balance_wallet_rounded;
      case NotificationType.news:
        return Icons.newspaper_rounded;
      case NotificationType.serviceRules:
        return Icons.description_rounded;
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
      case NotificationType.paymentChatMessage:
        return '/payment-chat';
      case NotificationType.news:
        return '/news';
      case NotificationType.serviceRules:
        return '/service-rules';
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
    final typeStr = json['type'] as String? ?? '';
    final title = json['title'] as String? ?? '';
    final body = json['body'] as String? ?? '';
    
    // data может быть Map или String (JSON строка)
    Map<String, dynamic> data = {};
    final rawData = json['data'];
    if (rawData is Map<String, dynamic>) {
      data = rawData;
    } else if (rawData is String) {
      // Если data - это строка, пробуем распарсить как JSON
      try {
        // ignore parsing, use empty map
      } catch (_) {
        // ignore
      }
    }
    
    // Определяем тип уведомления (сначала по type, потом по заголовку/телу)
    NotificationType type;
    if (typeStr.isNotEmpty) {
      type = _parseNotificationType(typeStr);
    } else {
      // Пробуем определить по заголовку и телу
      type = _inferTypeFromContent(title, body);
    }
    
    // Если тип всё ещё дефолтный - пробуем уточнить по содержимому
    if (type == NotificationType.trackStatus) {
      final inferredType = _inferTypeFromContent(title, body);
      if (inferredType != NotificationType.trackStatus) {
        type = inferredType;
      }
    }
    
    // Определяем маршрут
    String? route = _getRouteForType(type, data);
    
    return NotificationItem(
      id: json['id'].toString(),
      type: type,
      title: title,
      message: body,
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
    // Приводим к нижнему регистру для универсального сравнения
    final type = typeStr.toLowerCase().trim();
    
    // Трек статусы (включая создание нового трека)
    if (type.contains('track') && (type.contains('status') || type.contains('update') || type.contains('created'))) {
      return NotificationType.trackStatus;
    }
    
    // Сборка статусы
    if (type.contains('assembly') && (type.contains('status') || type.contains('update'))) {
      return NotificationType.assemblyStatus;
    }
    
    // Фотоотчёт
    if (type.contains('photo') || type.contains('фото')) {
      return NotificationType.photoReportStatus;
    }
    
    // Вопрос/ответ
    if (type.contains('question') || type.contains('answer') || type.contains('вопрос') || type.contains('ответ')) {
      return NotificationType.questionStatus;
    }
    
    // Чат / сообщение от поддержки
    if (type.contains('chat') || type.contains('message') || type.contains('support') || 
        type.contains('сообщение') || type.contains('поддержк')) {
      // Различаем чат по оплате и обычный чат поддержки
      if (type.contains('payment') || type.contains('оплат')) {
        return NotificationType.paymentChatMessage;
      }
      return NotificationType.chatMessage;
    }
    
    // Новости
    if (type.contains('news') || type.contains('новост')) {
      return NotificationType.news;
    }
    
    // Правила оказания услуг
    if (type.contains('service') && type.contains('rule') || type.contains('правил')) {
      return NotificationType.serviceRules;
    }
    
    // Счета
    if (type.contains('invoice') || type.contains('счет') || type.contains('счёт') || type.contains('payment')) {
      return NotificationType.invoice;
    }
    
    // Точные совпадения для обратной совместимости
    switch (type) {
      case 'track_created':
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
      case 'photo_request_status_changed':
      case 'photo_request':
        return NotificationType.photoReportStatus;
      case 'question_answered':
      case 'question_update':
      case 'question_status_changed':
        return NotificationType.questionStatus;
      case 'chat_message':
      case 'new_message':
      case 'support_message':
        return NotificationType.chatMessage;
      case 'payment_chat_message':
      case 'payment_message':
        return NotificationType.paymentChatMessage;
      case 'news':
      case 'new_news':
      case 'news_created':
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
        // Если тип не определён - пробуем определить по заголовку/телу в fromJson
        return NotificationType.trackStatus;
    }
  }
  
  /// Определить тип уведомления по содержимому (заголовку и телу)
  static NotificationType _inferTypeFromContent(String title, String body) {
    final combined = '$title $body'.toLowerCase();
    
    // Сообщение от поддержки / чат
    if (combined.contains('сообщение от поддержки') || 
        combined.contains('поддержка') ||
        combined.contains('чат') ||
        combined.contains('support') ||
        combined.contains('message')) {
      return NotificationType.chatMessage;
    }
    
    // Фотоотчёт
    if (combined.contains('фото') || 
        combined.contains('photo') ||
        combined.contains('фотоотчёт') ||
        combined.contains('фотоотчет')) {
      return NotificationType.photoReportStatus;
    }
    
    // Вопрос/ответ
    if (combined.contains('вопрос') || 
        combined.contains('ответ') ||
        combined.contains('question') ||
        combined.contains('answer')) {
      return NotificationType.questionStatus;
    }
    
    // Счёт
    if (combined.contains('счёт') || 
        combined.contains('счет') ||
        combined.contains('invoice') ||
        combined.contains('оплат')) {
      return NotificationType.invoice;
    }
    
    // Сборка
    if (combined.contains('сборк') || 
        combined.contains('assembly') ||
        combined.contains('sb-')) {
      return NotificationType.assemblyStatus;
    }
    
    // Новость
    if (combined.contains('новост') || 
        combined.contains('news')) {
      return NotificationType.news;
    }
    
    // Правила оказания услуг
    if (combined.contains('правил') || 
        combined.contains('service') && combined.contains('rule') ||
        combined.contains('услуг')) {
      return NotificationType.serviceRules;
    }
    
    // По умолчанию - статус трека
    return NotificationType.trackStatus;
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
      case NotificationType.paymentChatMessage:
        return '/payment-chat';
      case NotificationType.news:
        final newsId = data['newsId'];
        if (newsId != null) return '/news/$newsId';
        return '/news';
      case NotificationType.serviceRules:
        final ruleId = data['serviceRuleId'];
        if (ruleId != null) return '/service-rules/$ruleId';
        return '/service-rules';
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

  /// Создать уведомление о новом сообщении в чате по оплате
  factory NotificationItem.paymentChatMessage({
    required String id,
    required String senderName,
    required String messagePreview,
    required DateTime createdAt,
    bool isRead = false,
  }) {
    return NotificationItem(
      id: id,
      type: NotificationType.paymentChatMessage,
      title: senderName,
      message: messagePreview,
      createdAt: createdAt,
      isRead: isRead,
      route: '/payment-chat',
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
