import 'chat_message.dart';

/// Диалог (конверсация) чата
class ChatConversation {
  final int id;
  final int agentId;
  final String? agentName;
  final int? clientId;
  final String? clientName;
  final String? clientPhone;
  final String? clientEmail;
  final List<String> clientCodes;
  final String status; // 'open', 'pending', 'resolved', 'closed'
  final String priority; // 'low', 'normal', 'high', 'urgent'
  final String? subject;
  final String? lastMessageText;
  final DateTime? lastMessageAt;
  final int unreadByClient;
  final int unreadBySupport;
  final int messagesCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? closedAt;
  final int? assignedToId;
  final String? assignedToName;
  final int? trackId;
  final int? invoiceId;
  final int activeTasksCount;
  final int activeBlanksCount;
  final String channel; // app | telegram | telegram_group | max
  final String? externalChatId;
  final String? externalUsername;
  final String? externalTitle;
  final List<ChatMessage> messages;

  const ChatConversation({
    required this.id,
    required this.agentId,
    this.agentName,
    this.clientId,
    this.clientName,
    this.clientPhone,
    this.clientEmail,
    this.clientCodes = const [],
    required this.status,
    required this.priority,
    this.subject,
    this.lastMessageText,
    this.lastMessageAt,
    this.unreadByClient = 0,
    this.unreadBySupport = 0,
    this.messagesCount = 0,
    required this.createdAt,
    required this.updatedAt,
    this.closedAt,
    this.assignedToId,
    this.assignedToName,
    this.trackId,
    this.invoiceId,
    this.activeTasksCount = 0,
    this.activeBlanksCount = 0,
    this.channel = 'app',
    this.externalChatId,
    this.externalUsername,
    this.externalTitle,
    this.messages = const [],
  });

  factory ChatConversation.fromJson(Map<String, dynamic> json) {
    return ChatConversation(
      id: json['id'] as int,
      agentId: json['agentId'] as int? ?? 0,
      agentName: json['agentName'] as String?,
      clientId: json['clientId'] as int?,
      clientName: json['clientName'] as String?,
      clientPhone: json['clientPhone'] as String?,
      clientEmail: json['clientEmail'] as String?,
      clientCodes: (json['clientCodes'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      status: json['status'] as String? ?? 'open',
      priority: json['priority'] as String? ?? 'normal',
      subject: json['subject'] as String?,
      lastMessageText: json['lastMessageText'] as String?,
      lastMessageAt: json['lastMessageAt'] != null
          ? DateTime.parse(json['lastMessageAt'].toString())
          : null,
      unreadByClient: json['unreadByClient'] as int? ?? 0,
      unreadBySupport: json['unreadBySupport'] as int? ?? 0,
      messagesCount: json['messagesCount'] as int? ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'].toString())
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'].toString())
          : DateTime.now(),
      closedAt: json['closedAt'] != null
          ? DateTime.parse(json['closedAt'].toString())
          : null,
      assignedToId: json['assignedToId'] as int?,
      assignedToName: json['assignedToName'] as String?,
      trackId: json['trackId'] as int?,
      invoiceId: json['invoiceId'] as int?,
      activeTasksCount: json['activeTasksCount'] as int? ?? 0,
      activeBlanksCount: json['activeBlanksCount'] as int? ?? 0,
      channel: json['channel'] as String? ?? 'app',
      externalChatId: json['externalChatId'] as String?,
      externalUsername: json['externalUsername'] as String?,
      externalTitle: json['externalTitle'] as String?,
      messages: (json['messages'] as List<dynamic>?)
              ?.map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'agentId': agentId,
      'agentName': agentName,
      'clientId': clientId,
      'clientName': clientName,
      'clientPhone': clientPhone,
      'clientEmail': clientEmail,
      'clientCodes': clientCodes,
      'status': status,
      'priority': priority,
      'subject': subject,
      'lastMessageText': lastMessageText,
      'lastMessageAt': lastMessageAt?.toIso8601String(),
      'unreadByClient': unreadByClient,
      'unreadBySupport': unreadBySupport,
      'messagesCount': messagesCount,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'closedAt': closedAt?.toIso8601String(),
      'assignedToId': assignedToId,
      'assignedToName': assignedToName,
      'trackId': trackId,
      'invoiceId': invoiceId,
      'activeTasksCount': activeTasksCount,
      'activeBlanksCount': activeBlanksCount,
      'messages': messages.map((e) => e.toJson()).toList(),
    };
  }

  ChatConversation copyWith({
    int? id,
    int? agentId,
    String? agentName,
    int? clientId,
    String? clientName,
    String? clientPhone,
    String? clientEmail,
    List<String>? clientCodes,
    String? status,
    String? priority,
    String? subject,
    String? lastMessageText,
    DateTime? lastMessageAt,
    int? unreadByClient,
    int? unreadBySupport,
    int? messagesCount,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? closedAt,
    int? assignedToId,
    String? assignedToName,
    int? trackId,
    int? invoiceId,
    int? activeTasksCount,
    int? activeBlanksCount,
    String? channel,
    String? externalChatId,
    String? externalUsername,
    String? externalTitle,
    List<ChatMessage>? messages,
  }) {
    return ChatConversation(
      id: id ?? this.id,
      agentId: agentId ?? this.agentId,
      agentName: agentName ?? this.agentName,
      clientId: clientId ?? this.clientId,
      clientName: clientName ?? this.clientName,
      clientPhone: clientPhone ?? this.clientPhone,
      clientEmail: clientEmail ?? this.clientEmail,
      clientCodes: clientCodes ?? this.clientCodes,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      subject: subject ?? this.subject,
      lastMessageText: lastMessageText ?? this.lastMessageText,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      unreadByClient: unreadByClient ?? this.unreadByClient,
      unreadBySupport: unreadBySupport ?? this.unreadBySupport,
      messagesCount: messagesCount ?? this.messagesCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      closedAt: closedAt ?? this.closedAt,
      assignedToId: assignedToId ?? this.assignedToId,
      assignedToName: assignedToName ?? this.assignedToName,
      trackId: trackId ?? this.trackId,
      invoiceId: invoiceId ?? this.invoiceId,
      activeTasksCount: activeTasksCount ?? this.activeTasksCount,
      activeBlanksCount: activeBlanksCount ?? this.activeBlanksCount,
      channel: channel ?? this.channel,
      externalChatId: externalChatId ?? this.externalChatId,
      externalUsername: externalUsername ?? this.externalUsername,
      externalTitle: externalTitle ?? this.externalTitle,
      messages: messages ?? this.messages,
    );
  }

  // Helper getters
  bool get isOpen => status == 'open';
  bool get isClosed => status == 'closed';
  bool get isPending => status == 'pending';
  bool get isResolved => status == 'resolved';
  bool get hasUnreadMessages => unreadByClient > 0 || unreadBySupport > 0;
}
