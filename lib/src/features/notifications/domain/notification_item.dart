import 'dart:convert';

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

  /// Событие по заявке или заказу в Гараже
  garage,
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
      case NotificationType.garage:
        return 'Гараж';
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
      case NotificationType.garage:
        return Icons.directions_car_filled_rounded;
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
        // PU-H1: route в приложении называется /rules (а не /service-rules).
        return '/rules';
      case NotificationType.invoice:
        return '/invoices';
      case NotificationType.garage:
        return '/garage';
    }
  }

  List<String> get backendTypeAliases {
    switch (this) {
      case NotificationType.trackStatus:
        return const [
          'track_status',
          'track_created',
          'track_update',
          'track_status_changed',
          'track_status_change',
          'track_arrived_warehouse',
          'track_shipped',
          'track_delivered',
        ];
      case NotificationType.assemblyStatus:
        return const [
          'assembly_status',
          'assembly_update',
          'assembly_status_changed',
          'assembly_status_change',
          'track_added_to_assembly',
        ];
      case NotificationType.photoReportStatus:
        return const [
          'photo_report_status',
          'photo_report_update',
          'photo_report_ready',
          'photo_request_created',
          'photo_request_completed',
          'photo_request_status_changed',
          'photo_request',
        ];
      case NotificationType.questionStatus:
        return const [
          'question_status',
          'question_answered',
          'question_update',
          'question_status_changed',
        ];
      case NotificationType.chatMessage:
        return const ['chat_message', 'support_message', 'new_message'];
      case NotificationType.paymentChatMessage:
        return const ['payment_chat_message', 'payment_message'];
      case NotificationType.news:
        return const ['news', 'new_news', 'news_created'];
      case NotificationType.serviceRules:
        return const ['service_rule_created', 'service_rule', 'service_rules'];
      case NotificationType.invoice:
        return const [
          'invoice',
          'new_invoice',
          'invoice_created',
          'invoice_status_changed',
          'invoice_paid',
          'invoice_arrival',
        ];
      case NotificationType.garage:
        return const [
          'garage_offer_ready',
          'garage_status_changed',
          'garage_employee_question',
          'garage_employee_message',
          'garage_payment_approved',
          'garage_payment_rejected',
          'garage_purchase_required',
          'garage_offer_accepted',
          'garage_client_question',
          'garage_client_message',
        ];
    }
  }
}

@immutable
class NotificationTapTarget {
  final String? route;
  final String? notificationId;

  const NotificationTapTarget({this.route, this.notificationId});
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

    // data может быть Map или String (JSON строка). FCM-уведомления всегда
    // отдают payload строкой — без декодирования мы теряли newsId/serviceRuleId
    // и роутер не мог построить deep link к конкретной сущности.
    Map<String, dynamic> data = {};
    final rawData = json['data'];
    if (rawData is Map<String, dynamic>) {
      data = rawData;
    } else if (rawData is String && rawData.isNotEmpty) {
      // PU-H2: реально парсим JSON-строку. Если приходит мусор — оставляем
      // пустую Map (route деградирует до общего, без падения).
      try {
        final parsed = jsonDecode(rawData);
        if (parsed is Map<String, dynamic>) {
          data = parsed;
        }
      } catch (_) {
        // Невалидный JSON — оставляем data пустым.
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
    type = _paymentTargetType(data) ?? type;

    // Определяем маршрут
    String? route = _getRouteForType(type, data);

    return NotificationItem(
      id: json['id'].toString(),
      type: type,
      title: title,
      message: body,
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      isRead: json['isRead'] as bool? ?? false,
      route: route,
      relatedId:
          data['trackNumber'] as String? ??
          data['trackCode'] as String? ??
          data['assemblyNumber'] as String? ??
          data['invoiceNumber'] as String? ??
          data['requestNumber'] as String? ??
          data['orderNumber'] as String? ??
          data['trackId']?.toString() ??
          data['assemblyId']?.toString() ??
          data['invoiceId']?.toString() ??
          data['garageRequestId']?.toString() ??
          data['garageOrderId']?.toString() ??
          data['targetId']?.toString(),
      oldStatus: data['oldStatus'] as String? ?? data['old_status'] as String?,
      newStatus:
          data['newStatus'] as String? ??
          data['new_status'] as String? ??
          data['status'] as String?,
    );
  }

  /// Создать уведомление из FCM payload. Backend кладёт id записи уведомления
  /// в `entityId`, поэтому здесь используем его как основной id.
  factory NotificationItem.fromPushData(
    Map<String, dynamic> data, {
    String? title,
    String? body,
  }) {
    final typeStr = _readString(data, const ['type']) ?? '';
    final type = _paymentTargetType(data) ?? _parseNotificationType(typeStr);
    final now = DateTime.now();

    return NotificationItem(
      id: notificationIdFromData(data) ?? now.microsecondsSinceEpoch.toString(),
      type: type,
      title: title ?? _readString(data, const ['title']) ?? 'Новое уведомление',
      message: body ?? _readString(data, const ['message', 'body']) ?? '',
      createdAt: now,
      isRead: false,
      route: _getRouteForType(type, data),
      relatedId: _readString(data, const [
        'trackNumber',
        'trackCode',
        'assemblyNumber',
        'invoiceNumber',
        'trackId',
        'assemblyId',
        'invoiceId',
        'garageRequestId',
        'garageOrderId',
        'targetId',
      ]),
      oldStatus: _readString(data, const ['oldStatus', 'old_status']),
      newStatus: _readString(data, const ['newStatus', 'new_status', 'status']),
    );
  }

  static String? notificationIdFromData(Map<String, dynamic> data) {
    return _readString(data, const [
      'notificationId',
      'notification_id',
      'id',
      'entityId',
      'entity_id',
    ]);
  }

  static String? routeFromPushData(Map<String, dynamic> data) {
    final parsedType = _parseNotificationType(
      _readString(data, const ['type']) ?? '',
    );
    return _getRouteForType(_paymentTargetType(data) ?? parsedType, data);
  }

  static String? tapPayloadFromPushData(Map<String, dynamic> data) {
    final target = NotificationTapTarget(
      route: routeFromPushData(data),
      notificationId: notificationIdFromData(data),
    );
    if (target.route == null && target.notificationId == null) return null;
    return jsonEncode({
      if (target.route != null) 'route': target.route,
      if (target.notificationId != null)
        'notificationId': target.notificationId,
    });
  }

  static NotificationTapTarget tapTargetFromPayload(String? payload) {
    if (payload == null || payload.isEmpty) {
      return const NotificationTapTarget();
    }

    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map<String, dynamic>) {
        return NotificationTapTarget(
          route: decoded['route'] as String?,
          notificationId: decoded['notificationId']?.toString(),
        );
      }
    } catch (_) {
      // Старые payload были просто route-строкой.
    }

    return NotificationTapTarget(route: payload);
  }

  /// Парсинг типа уведомления из строки API
  static NotificationType _parseNotificationType(String typeStr) {
    // Приводим к нижнему регистру для универсального сравнения
    final type = typeStr.toLowerCase().trim();

    if (type == 'garage' || type.startsWith('garage_')) {
      return NotificationType.garage;
    }

    // Трек статусы (включая создание нового трека)
    if (type.contains('track') &&
        (type.contains('status') ||
            type.contains('update') ||
            type.contains('created'))) {
      return NotificationType.trackStatus;
    }

    // Сборка статусы
    if (type.contains('assembly') &&
        (type.contains('status') || type.contains('update'))) {
      return NotificationType.assemblyStatus;
    }

    // Фотоотчёт
    if (type.contains('photo') || type.contains('фото')) {
      return NotificationType.photoReportStatus;
    }

    // Вопрос/ответ
    if (type.contains('question') ||
        type.contains('answer') ||
        type.contains('вопрос') ||
        type.contains('ответ')) {
      return NotificationType.questionStatus;
    }

    // Чат / сообщение от поддержки
    if (type.contains('chat') ||
        type.contains('message') ||
        type.contains('support') ||
        type.contains('сообщение') ||
        type.contains('поддержк')) {
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
    if (type.contains('service') && type.contains('rule') ||
        type.contains('правил')) {
      return NotificationType.serviceRules;
    }

    // Счета
    if (type.contains('invoice') ||
        type.contains('счет') ||
        type.contains('счёт') ||
        type.contains('payment')) {
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
      case 'garage':
        return NotificationType.garage;
      default:
        // Если тип не определён - пробуем определить по заголовку/телу в fromJson
        return NotificationType.trackStatus;
    }
  }

  /// Определить тип уведомления по содержимому (заголовку и телу)
  static NotificationType _inferTypeFromContent(String title, String body) {
    final combined = '$title $body'.toLowerCase();

    if (combined.contains('гараж') || combined.contains('garage')) {
      return NotificationType.garage;
    }

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
    if (combined.contains('новост') || combined.contains('news')) {
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
  static String? _getRouteForType(
    NotificationType type,
    Map<String, dynamic> data,
  ) {
    final explicitRoute = _readString(data, const ['route']);
    if (explicitRoute != null && explicitRoute.isNotEmpty) {
      return explicitRoute;
    }

    // Nocode-дайджест → на страницу поиска с запросом NOCODE
    if (data['type'] == 'nocode_daily_digest') {
      return '/search?q=NOCODE';
    }
    final rawType =
        _readString(data, const [
          'type',
          'notification_type',
          'template',
        ])?.toLowerCase() ??
        '';
    final trackId = _readString(data, const ['trackId', 'track_id']);
    final trackCode = _readString(data, const [
      'trackCode',
      'trackNumber',
      'track_number',
    ]);
    final assemblyId = _readString(data, const ['assemblyId', 'assembly_id']);
    final clientCode = _readString(data, const ['clientCode', 'client_code']);
    final invoiceId = _readString(data, const [
      'invoiceId',
      'invoice_id',
      'invoiceNumber',
      'invoice_number',
    ]);
    final garageRequestId = _readString(data, const [
      'garageRequestId',
      'garage_request_id',
      'requestId',
    ]);
    final garageOrderId = _readString(data, const [
      'garageOrderId',
      'garage_order_id',
      'orderId',
    ]);
    final targetType = _readString(data, const [
      'targetType',
      'target_type',
    ])?.toLowerCase();
    final targetId = _readString(data, const ['targetId', 'target_id']);
    final routeId = _readString(data, const ['routeId', 'route_id']);
    final clientCodeQuery = <String, String>{
      if (clientCode != null) 'clientCode': clientCode,
    };

    switch (type) {
      case NotificationType.trackStatus:
      case NotificationType.assemblyStatus:
      case NotificationType.photoReportStatus:
      case NotificationType.questionStatus:
        // PU-H1: NOCODE digest (сводка незарегистрированных треков) ведёт
        // на /search-nocode, если backend пометил тип в data.
        final isNocodeDigest =
            data['kind'] == 'nocode_digest' ||
            data['notification_type'] == 'nocode_digest';
        if (isNocodeDigest) {
          return '/search-nocode';
        }
        final shouldOpenAssembly =
            type == NotificationType.assemblyStatus ||
            rawType.contains('assembly');
        if (shouldOpenAssembly && assemblyId != null) {
          return _route('/tracks', {
            ...clientCodeQuery,
            'assemblyId': assemblyId,
          });
        }
        if (trackId != null) {
          return _route('/tracks', {
            ...clientCodeQuery,
            'trackId': trackId,
            if (trackCode != null) 'trackCode': trackCode,
          });
        }
        if (trackCode != null) {
          return _route('/tracks', {
            ...clientCodeQuery,
            'trackCode': trackCode,
          });
        }
        if (assemblyId != null) {
          return _route('/tracks', {
            ...clientCodeQuery,
            'assemblyId': assemblyId,
          });
        }
        return '/tracks';
      case NotificationType.chatMessage:
        return '/support';
      case NotificationType.paymentChatMessage:
        return '/payment-chat';
      case NotificationType.news:
        // /news/:slug в роутере принимает любую строку — id тоже подойдёт.
        final newsId = _readString(data, const ['newsId', 'news_id']);
        if (newsId != null) return '/news/$newsId';
        return '/news';
      case NotificationType.serviceRules:
        // PU-H1: route называется /rules (не /service-rules).
        final ruleId = _readString(data, const [
          'serviceRuleId',
          'service_rule_id',
          'ruleId',
          'rule_id',
        ]);
        if (ruleId != null) return '/rules/$ruleId';
        return '/rules';
      case NotificationType.invoice:
        final resolvedInvoiceId =
            invoiceId ??
            (targetType == 'invoice' ? (routeId ?? targetId) : null);
        if (resolvedInvoiceId != null) {
          return _route('/invoices', {
            ...clientCodeQuery,
            'invoiceId': resolvedInvoiceId,
          });
        }
        return '/invoices';
      case NotificationType.garage:
        if (targetType == 'garage_invoice') {
          final resolvedOrderId = routeId ?? garageOrderId;
          if (resolvedOrderId != null) {
            return '/garage/orders/$resolvedOrderId';
          }
        }
        if (garageRequestId != null) {
          return '/garage/requests/$garageRequestId';
        }
        if (garageOrderId != null) {
          return '/garage/orders/$garageOrderId';
        }
        return '/garage';
    }
  }

  static String _route(String path, Map<String, String> queryParameters) {
    return Uri(path: path, queryParameters: queryParameters).toString();
  }

  static String? _readString(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value == null) continue;
      final text = value.toString();
      if (text.isNotEmpty) return text;
    }
    return null;
  }

  static NotificationType? _paymentTargetType(Map<String, dynamic> data) {
    return switch (_readString(data, const [
      'targetType',
      'target_type',
    ])?.toLowerCase()) {
      'invoice' => NotificationType.invoice,
      'garage_invoice' => NotificationType.garage,
      _ => null,
    };
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
