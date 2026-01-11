/// Модели для чата поддержки

/// Сообщение чата
class ChatMessage {
  final int id;
  final int conversationId;
  final String senderType; // 'client' or 'employee'
  final int senderId;
  final String senderName;
  final String contentType; // 'text', 'image', 'file', etc.
  final String content;
  final Map<String, dynamic>? metadata;
  final bool isRead;
  final bool isEdited;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? readAt;
  final List<ChatAttachment> attachments;

  const ChatMessage({
    required this.id,
    required this.conversationId,
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
    this.attachments = const [],
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as int,
      conversationId: json['conversationId'] as int,
      senderType: json['senderType'] as String? ?? 'client',
      senderId: json['senderId'] as int? ?? 0,
      senderName: json['senderName'] as String? ?? 'Неизвестный',
      contentType: json['contentType'] as String? ?? 'text',
      content: json['content'] as String? ?? '',
      metadata: json['metadata'] as Map<String, dynamic>?,
      isRead: json['isRead'] as bool? ?? false,
      isEdited: json['isEdited'] as bool? ?? false,
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt'].toString()) 
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null 
          ? DateTime.parse(json['updatedAt'].toString()) 
          : DateTime.now(),
      readAt: json['readAt'] != null 
          ? DateTime.parse(json['readAt'].toString()) 
          : null,
      attachments: (json['attachments'] as List<dynamic>?)
          ?.map((a) => ChatAttachment.fromJson(a as Map<String, dynamic>))
          .toList() ?? [],
    );
  }

  bool get isFromClient => senderType == 'client';
  bool get isFromSupport => senderType == 'employee';
}

/// Вложение к сообщению
class ChatAttachment {
  final int id;
  final String fileName;
  final String fileType;
  final int? fileSize;
  final String url;
  final String? thumbnailUrl;

  const ChatAttachment({
    required this.id,
    required this.fileName,
    required this.fileType,
    this.fileSize,
    required this.url,
    this.thumbnailUrl,
  });

  factory ChatAttachment.fromJson(Map<String, dynamic> json) {
    return ChatAttachment(
      id: json['id'] as int,
      fileName: json['fileName'] as String? ?? '',
      fileType: json['fileType'] as String? ?? '',
      fileSize: json['fileSize'] as int?,
      url: json['url'] as String? ?? '',
      thumbnailUrl: json['thumbnailUrl'] as String?,
    );
  }
}

/// Диалог поддержки
class ChatConversation {
  final int id;
  final int agentId;
  final int clientId;
  final String clientName;
  final String status;
  final String priority;
  final String? subject;
  final String? lastMessageText;
  final DateTime? lastMessageAt;
  final int unreadByClient;
  final int unreadBySupport;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ChatMessage> messages;

  const ChatConversation({
    required this.id,
    required this.agentId,
    required this.clientId,
    required this.clientName,
    required this.status,
    required this.priority,
    this.subject,
    this.lastMessageText,
    this.lastMessageAt,
    required this.unreadByClient,
    required this.unreadBySupport,
    required this.createdAt,
    required this.updatedAt,
    this.messages = const [],
  });

  factory ChatConversation.fromJson(Map<String, dynamic> json) {
    return ChatConversation(
      id: json['id'] as int,
      agentId: json['agentId'] as int? ?? 0,
      clientId: json['clientId'] as int? ?? 0,
      clientName: json['clientName'] as String? ?? 'Клиент',
      status: json['status'] as String? ?? 'open',
      priority: json['priority'] as String? ?? 'normal',
      subject: json['subject'] as String?,
      lastMessageText: json['lastMessageText'] as String?,
      lastMessageAt: json['lastMessageAt'] != null
          ? DateTime.parse(json['lastMessageAt'].toString())
          : null,
      unreadByClient: json['unreadByClient'] as int? ?? 0,
      unreadBySupport: json['unreadBySupport'] as int? ?? 0,
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt'].toString()) 
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null 
          ? DateTime.parse(json['updatedAt'].toString()) 
          : DateTime.now(),
      messages: (json['messages'] as List<dynamic>?)
          ?.map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
          .toList() ?? [],
    );
  }
}
