import 'package:twoalogistic_shared/twoalogistic_shared.dart';

/// Helper класс для создания mock данных в тестах
class MockData {
  /// Создать mock ChatMessage
  static ChatMessage createMockMessage({
    int id = 1,
    int conversationId = 1,
    String senderType = 'client',
    int senderId = 1,
    String senderName = 'Test User',
    String contentType = 'text',
    String content = 'Test message',
    Map<String, dynamic>? metadata,
    bool isRead = false,
    bool isEdited = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? readAt,
    List<ChatAttachment>? attachments,
  }) {
    return ChatMessage(
      id: id,
      conversationId: conversationId,
      senderType: senderType,
      senderId: senderId,
      senderName: senderName,
      contentType: contentType,
      content: content,
      metadata: metadata,
      isRead: isRead,
      isEdited: isEdited,
      createdAt: createdAt ?? DateTime.now(),
      updatedAt: updatedAt ?? DateTime.now(),
      readAt: readAt,
      attachments: attachments ?? [],
    );
  }

  /// Создать mock ChatConversation
  static ChatConversation createMockConversation({
    int id = 1,
    int? agentId = 1,
    int clientId = 1,
    String clientName = 'Test Client',
    String status = 'open',
    String priority = 'normal',
    String? subject,
    String? lastMessageText,
    DateTime? lastMessageAt,
    int unreadByClient = 0,
    int unreadBySupport = 0,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<ChatMessage>? messages,
  }) {
    return ChatConversation(
      id: id,
      agentId: agentId ?? 1,
      clientId: clientId,
      clientName: clientName,
      status: status,
      priority: priority,
      subject: subject,
      lastMessageText: lastMessageText,
      lastMessageAt: lastMessageAt,
      unreadByClient: unreadByClient,
      unreadBySupport: unreadBySupport,
      createdAt: createdAt ?? DateTime.now(),
      updatedAt: updatedAt ?? DateTime.now(),
      messages: messages ?? [],
    );
  }

  /// Создать mock ChatAttachment
  static ChatAttachment createMockAttachment({
    int id = 1,
    String fileName = 'test.jpg',
    String fileType = 'image/jpeg',
    int? fileSize = 1024,
    String url = 'https://example.com/test.jpg',
    String? thumbnailUrl,
  }) {
    return ChatAttachment(
      id: id,
      fileName: fileName,
      fileType: fileType,
      fileSize: fileSize,
      url: url,
      thumbnailUrl: thumbnailUrl,
    );
  }

  /// Создать mock ProductInfo
  static ProductInfo createMockProductInfo({
    int? id,
    String? name,
    int quantity = 1,
    String? imageUrl,
    DateTime? createdAt,
  }) {
    return ProductInfo(
      id: id,
      name: name,
      quantity: quantity,
      imageUrl: imageUrl,
      createdAt: createdAt,
    );
  }
}
