import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http_parser/http_parser.dart';

import '../../../core/network/api_client.dart';
import '../../../core/services/push_notification_service.dart';
import '../../support/data/chat_models.dart';

// ==================== Payment Chat Repository ====================

/// Простой Notifier для bool состояния (открыт ли экран чата по оплате)
class IsPaymentChatScreenOpenNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  
  void set(bool value) => state = value;
}

/// Провайдер флага открытия экрана чата по оплате
final isPaymentChatScreenOpenProvider = NotifierProvider<IsPaymentChatScreenOpenNotifier, bool>(
  IsPaymentChatScreenOpenNotifier.new,
);

/// Репозиторий для работы с чатом по оплате
class PaymentChatRepository {
  final ApiClient _apiClient;

  PaymentChatRepository(this._apiClient);

  /// Получить или создать диалог по оплате
  /// Возвращает диалог с сообщениями
  Future<ChatConversation> getConversation() async {
    try {
      final response = await _apiClient.get('/client/payment-chat');

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        
        // API возвращает conversation и messages отдельно
        final conversationJson = data['conversation'] as Map<String, dynamic>;
        final messagesJson = data['messages'] as List<dynamic>? ?? [];
        
        // Добавляем messages в conversation json для парсинга
        conversationJson['messages'] = messagesJson;
        
        return ChatConversation.fromJson(conversationJson);
      }
      throw Exception('Failed to load payment conversation');
    } on DioException catch (e) {
      debugPrint('Error getting payment conversation: $e');
      rethrow;
    }
  }

  /// Отправить сообщение в чат по оплате
  Future<ChatMessage> sendMessage(String content, {
    String contentType = 'text',
    Map<String, dynamic>? metadata,
    List<int>? attachmentIds,
  }) async {
    try {
      final response = await _apiClient.post(
        '/client/payment-chat',
        data: {
          'content': content,
          'contentType': contentType,
          if (metadata != null) 'metadata': metadata,
          if (attachmentIds != null && attachmentIds.isNotEmpty) 'attachmentIds': attachmentIds,
        },
      );

      if (response.statusCode == 201 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        return ChatMessage.fromJson(data['message'] as Map<String, dynamic>);
      }
      throw Exception('Failed to send payment message');
    } on DioException catch (e) {
      debugPrint('Error sending payment message: $e');
      rethrow;
    }
  }
  
  /// Загрузить файл в чат (изображение или PDF)
  Future<Map<String, dynamic>?> uploadAttachment(File file, int conversationId) async {
    try {
      final fileName = file.path.split('/').last;
      final extension = fileName.split('.').last.toLowerCase();
      
      // Определяем MIME-тип
      String mimeType;
      String mimeSubtype;
      switch (extension) {
        case 'jpg':
        case 'jpeg':
          mimeType = 'image';
          mimeSubtype = 'jpeg';
          break;
        case 'png':
          mimeType = 'image';
          mimeSubtype = 'png';
          break;
        case 'gif':
          mimeType = 'image';
          mimeSubtype = 'gif';
          break;
        case 'webp':
          mimeType = 'image';
          mimeSubtype = 'webp';
          break;
        case 'pdf':
          mimeType = 'application';
          mimeSubtype = 'pdf';
          break;
        default:
          mimeType = 'application';
          mimeSubtype = 'octet-stream';
      }
      
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          file.path,
          filename: fileName,
          contentType: MediaType(mimeType, mimeSubtype),
        ),
        'conversationId': conversationId.toString(),
      });
      
      final response = await _apiClient.post(
        '/support/attachments',
        data: formData,
        options: Options(
          headers: {'Content-Type': 'multipart/form-data'},
        ),
      );
      
      if (response.statusCode == 201 && response.data != null) {
        return response.data as Map<String, dynamic>;
      }
      return null;
    } on DioException catch (e) {
      debugPrint('Error uploading payment chat attachment: $e');
      return null;
    }
  }

  /// Получить новые сообщения после указанного ID (для polling)
  Future<List<ChatMessage>> getNewMessages(int conversationId, int afterMessageId) async {
    try {
      final response = await _apiClient.get(
        '/client/payment-chat',
        queryParameters: {
          'afterMessageId': afterMessageId.toString(),
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        
        final messagesJson = data['messages'] as List<dynamic>? ?? [];
        
        return messagesJson
            .map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
            .where((m) => m.id > afterMessageId)
            .toList();
      }
      return [];
    } on DioException catch (e) {
      debugPrint('Error polling payment messages: $e');
      return [];
    }
  }
}

/// Провайдер репозитория чата по оплате
final paymentChatRepositoryProvider = Provider<PaymentChatRepository>((ref) {
  final apiClient = ref.read(apiClientProvider);
  return PaymentChatRepository(apiClient);
});

// ==================== Payment Chat State ====================

/// Состояние чата по оплате
class PaymentChatState {
  final ChatConversation? conversation;
  final List<ChatMessage> messages;
  final bool isLoading;
  final bool isSending;
  final bool isUploading;
  final String? error;
  final int? lastMessageId;
  final List<Map<String, dynamic>> pendingAttachments;

  const PaymentChatState({
    this.conversation,
    this.messages = const [],
    this.isLoading = false,
    this.isSending = false,
    this.isUploading = false,
    this.error,
    this.lastMessageId,
    this.pendingAttachments = const [],
  });

  PaymentChatState copyWith({
    ChatConversation? conversation,
    List<ChatMessage>? messages,
    bool? isLoading,
    bool? isSending,
    bool? isUploading,
    String? error,
    int? lastMessageId,
    List<Map<String, dynamic>>? pendingAttachments,
    bool clearError = false,
  }) {
    return PaymentChatState(
      conversation: conversation ?? this.conversation,
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
      isUploading: isUploading ?? this.isUploading,
      error: clearError ? null : (error ?? this.error),
      lastMessageId: lastMessageId ?? this.lastMessageId,
      pendingAttachments: pendingAttachments ?? this.pendingAttachments,
    );
  }
}

// ==================== Payment Chat Controller ====================

/// Контроллер чата по оплате
class PaymentChatController extends Notifier<PaymentChatState> {
  late final PaymentChatRepository _repository;

  @override
  PaymentChatState build() {
    _repository = ref.read(paymentChatRepositoryProvider);
    return const PaymentChatState();
  }

  /// Загрузить диалог
  Future<void> loadConversation() async {
    state = state.copyWith(isLoading: true, clearError: true);
    
    try {
      final conversation = await _repository.getConversation();
      final messages = conversation.messages;
      final lastId = messages.isNotEmpty ? messages.last.id : null;
      
      state = state.copyWith(
        conversation: conversation,
        messages: messages,
        isLoading: false,
        lastMessageId: lastId,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Не удалось загрузить чат: $e',
      );
    }
  }

  /// Отправить сообщение
  Future<bool> sendMessage(String content, {
    Map<String, dynamic>? metadata,
    List<int>? attachmentIds,
  }) async {
    if (content.trim().isEmpty && (attachmentIds == null || attachmentIds.isEmpty)) return false;
    
    state = state.copyWith(isSending: true, clearError: true);
    
    try {
      final message = await _repository.sendMessage(
        content.trim(),
        metadata: metadata,
        attachmentIds: attachmentIds,
      );
      
      final newMessages = [...state.messages, message];
      
      state = state.copyWith(
        messages: newMessages,
        isSending: false,
        lastMessageId: message.id,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isSending: false,
        error: 'Не удалось отправить сообщение',
      );
      return false;
    }
  }
  
  /// Загрузить файл на сервер
  Future<Map<String, dynamic>?> uploadFile(File file, int conversationId) async {
    state = state.copyWith(isUploading: true, clearError: true);
    
    try {
      final result = await _repository.uploadAttachment(file, conversationId);
      
      if (result != null) {
        // Добавляем в pending attachments
        state = state.copyWith(
          isUploading: false,
          pendingAttachments: [...state.pendingAttachments, result],
        );
        return result;
      }
      
      state = state.copyWith(
        isUploading: false,
        error: 'Не удалось загрузить файл',
      );
      return null;
    } catch (e) {
      state = state.copyWith(
        isUploading: false,
        error: 'Ошибка при загрузке файла: $e',
      );
      return null;
    }
  }
  
  /// Удалить pending attachment
  void removePendingAttachment(String id) {
    state = state.copyWith(
      pendingAttachments: state.pendingAttachments.where((a) => a['id'] != id).toList(),
    );
  }
  
  /// Очистить все pending attachments
  void clearPendingAttachments() {
    state = state.copyWith(pendingAttachments: []);
  }

  /// Проверить новые сообщения (polling)
  Future<void> pollNewMessages() async {
    if (state.conversation == null) return;
    
    final lastMessageId = state.lastMessageId ?? 0;
    
    try {
      final newMessages = await _repository.getNewMessages(
        state.conversation!.id,
        lastMessageId,
      );
      
      if (newMessages.isNotEmpty) {
        final existingIds = state.messages.map((m) => m.id).toSet();
        final uniqueNewMessages = newMessages.where((m) => !existingIds.contains(m.id)).toList();
        
        if (uniqueNewMessages.isNotEmpty) {
          final allMessages = [...state.messages, ...uniqueNewMessages];
          final lastId = allMessages.isNotEmpty ? allMessages.last.id : lastMessageId;
          
          state = state.copyWith(
            messages: allMessages,
            lastMessageId: lastId,
          );
          
          // Показать локальное уведомление для сообщений от бухгалтерии
          final isChatOpen = ref.read(isPaymentChatScreenOpenProvider);
          if (!isChatOpen) {
            for (final msg in uniqueNewMessages) {
              if (msg.isFromSupport) {
                final notificationService = ref.read(pushNotificationServiceProvider);
                await notificationService.showPaymentChatMessageNotification(
                  senderName: msg.senderName,
                  message: msg.content,
                  notificationId: msg.id,
                );
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error polling payment messages: $e');
    }
  }

  /// Очистить ошибку
  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

/// Провайдер контроллера чата по оплате
final paymentChatControllerProvider = NotifierProvider<PaymentChatController, PaymentChatState>(PaymentChatController.new);
