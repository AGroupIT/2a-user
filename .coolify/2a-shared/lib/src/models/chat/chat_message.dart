import 'chat_attachment.dart';

/// Сообщение чата
class ChatMessage {
  final int id;
  final int conversationId; // Может отсутствовать в API ответе для сообщений внутри conversation
  final String senderType; // 'client' or 'employee'
  final int senderId;
  final String senderName;
  final String contentType; // 'text', 'image', 'file', 'track_info', 'invoice_info', 'system'
  final String content;
  final Map<String, dynamic>? metadata;
  final bool isRead;
  final bool isEdited;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? readAt;
  final int? replyToMessageId;
  final List<ChatAttachment> attachments;

  /// Статус доставки во внешний канал (telegram/max/vk).
  /// null — сообщение во внутреннем канале 'app' (доставка не применима).
  /// 'pending' — попытка в процессе.
  /// 'sent' — успешно доставлено, externalMessageId сохранён.
  /// 'failed' — ошибка, детали в deliveryError, UI показывает кнопку Retry.
  final String? deliveryStatus;
  final String? deliveryError;
  final int deliveryAttempts;
  final DateTime? lastDeliveryAttemptAt;

  const ChatMessage({
    required this.id,
    this.conversationId = 0,
    required this.senderType,
    required this.senderId,
    required this.senderName,
    required this.contentType,
    required this.content,
    this.metadata,
    required this.isRead,
    required this.isEdited,
    required this.createdAt,
    required this.updatedAt,
    this.readAt,
    this.replyToMessageId,
    this.attachments = const [],
    this.deliveryStatus,
    this.deliveryError,
    this.deliveryAttempts = 0,
    this.lastDeliveryAttemptAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as int,
      conversationId: (json['conversationId'] ?? json['conversation_id']) as int? ?? 0,
      senderType: (json['senderType'] ?? json['sender_type']) as String? ?? 'client',
      senderId: (json['senderId'] ?? json['sender_id']) as int? ?? 0,
      senderName: (json['senderName'] ?? json['sender_name']) as String? ?? 'Неизвестный',
      contentType: (json['contentType'] ?? json['content_type']) as String? ?? 'text',
      content: json['content'] as String? ?? '',
      metadata: json['metadata'] as Map<String, dynamic>?,
      isRead: (json['isRead'] ?? json['is_read']) as bool? ?? false,
      isEdited: (json['isEdited'] ?? json['is_edited']) as bool? ?? false,
      createdAt: (json['createdAt'] ?? json['created_at']) != null
          ? DateTime.parse((json['createdAt'] ?? json['created_at']).toString())
          : DateTime.now(),
      updatedAt: (json['updatedAt'] ?? json['updated_at']) != null
          ? DateTime.parse((json['updatedAt'] ?? json['updated_at']).toString())
          : DateTime.now(),
      readAt: (json['readAt'] ?? json['read_at']) != null
          ? DateTime.parse((json['readAt'] ?? json['read_at']).toString())
          : null,
      replyToMessageId: (json['replyToMessageId'] ?? json['reply_to_message_id']) as int?,
      attachments: (json['attachments'] as List<dynamic>?)
              ?.map((a) => ChatAttachment.fromJson(a as Map<String, dynamic>))
              .toList() ??
          [],
      deliveryStatus: (json['deliveryStatus'] ?? json['delivery_status']) as String?,
      deliveryError: (json['deliveryError'] ?? json['delivery_error']) as String?,
      deliveryAttempts: (json['deliveryAttempts'] ?? json['delivery_attempts']) as int? ?? 0,
      lastDeliveryAttemptAt:
          (json['lastDeliveryAttemptAt'] ?? json['last_delivery_attempt_at']) != null
              ? DateTime.parse(
                  (json['lastDeliveryAttemptAt'] ?? json['last_delivery_attempt_at']).toString())
              : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversationId': conversationId,
      'senderType': senderType,
      'senderId': senderId,
      'senderName': senderName,
      'contentType': contentType,
      'content': content,
      'metadata': metadata,
      'isRead': isRead,
      'isEdited': isEdited,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'readAt': readAt?.toIso8601String(),
      'replyToMessageId': replyToMessageId,
      'attachments': attachments.map((e) => e.toJson()).toList(),
      'deliveryStatus': deliveryStatus,
      'deliveryError': deliveryError,
      'deliveryAttempts': deliveryAttempts,
      'lastDeliveryAttemptAt': lastDeliveryAttemptAt?.toIso8601String(),
    };
  }

  ChatMessage copyWith({
    int? id,
    int? conversationId,
    String? senderType,
    int? senderId,
    String? senderName,
    String? contentType,
    String? content,
    Map<String, dynamic>? metadata,
    bool? isRead,
    bool? isEdited,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? readAt,
    int? replyToMessageId,
    List<ChatAttachment>? attachments,
    String? deliveryStatus,
    String? deliveryError,
    int? deliveryAttempts,
    DateTime? lastDeliveryAttemptAt,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderType: senderType ?? this.senderType,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      contentType: contentType ?? this.contentType,
      content: content ?? this.content,
      metadata: metadata ?? this.metadata,
      isRead: isRead ?? this.isRead,
      isEdited: isEdited ?? this.isEdited,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      readAt: readAt ?? this.readAt,
      replyToMessageId: replyToMessageId ?? this.replyToMessageId,
      attachments: attachments ?? this.attachments,
      deliveryStatus: deliveryStatus ?? this.deliveryStatus,
      deliveryError: deliveryError ?? this.deliveryError,
      deliveryAttempts: deliveryAttempts ?? this.deliveryAttempts,
      lastDeliveryAttemptAt: lastDeliveryAttemptAt ?? this.lastDeliveryAttemptAt,
    );
  }

  // Helper getters
  bool get isFromClient => senderType == 'client';
  bool get isFromSupport => senderType == 'employee';
  bool get isSystemMessage => contentType == 'system';
  bool get hasAttachments => attachments.isNotEmpty;
  bool get isDeliveryPending => deliveryStatus == 'pending';
  bool get isDeliverySent => deliveryStatus == 'sent';
  bool get isDeliveryFailed => deliveryStatus == 'failed';
}
