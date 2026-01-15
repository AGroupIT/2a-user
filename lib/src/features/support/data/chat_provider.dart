import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http_parser/http_parser.dart';

import '../../../core/network/api_client.dart';
import '../../../core/services/push_notification_service.dart';
import 'chat_models.dart';

// ==================== Chat Repository ====================

/// Репозиторий для работы с чатом поддержки
class ChatRepository {
  final ApiClient _apiClient;

  ChatRepository(this._apiClient);

  /// Получить или создать диалог с поддержкой
  /// Возвращает диалог с сообщениями
  Future<ChatConversation> getConversation() async {
    try {
      final response = await _apiClient.get('/client/chat');

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        
        // API возвращает conversation и messages отдельно
        final conversationJson = data['conversation'] as Map<String, dynamic>;
        final messagesJson = data['messages'] as List<dynamic>? ?? [];
        
        // Добавляем messages в conversation json для парсинга
        conversationJson['messages'] = messagesJson;
        
        return ChatConversation.fromJson(conversationJson);
      }
      throw Exception('Failed to load conversation');
    } on DioException catch (e) {
      debugPrint('Error getting conversation: $e');
      rethrow;
    }
  }

  /// Отправить сообщение в чат
  Future<ChatMessage> sendMessage(String content, {String contentType = 'text', List<int>? attachmentIds}) async {
    try {
      final response = await _apiClient.post(
        '/client/chat',
        data: {
          'content': content,
          'contentType': contentType,
          if (attachmentIds != null && attachmentIds.isNotEmpty) 'attachmentIds': attachmentIds,
        },
      );

      if (response.statusCode == 201 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        // API возвращает 'message', не 'data'
        return ChatMessage.fromJson(data['message'] as Map<String, dynamic>);
      }
      throw Exception('Failed to send message');
    } on DioException catch (e) {
      debugPrint('Error sending message: $e');
      rethrow;
    }
  }

  /// Загрузить вложение
  Future<ChatAttachment> uploadAttachment(File file, int conversationId) async {
    try {
      final fileName = file.path.split('/').last;
      final mimeType = _getMimeType(fileName);
      
      // Читаем файл в память сразу, чтобы избежать проблем с временными файлами iOS
      final bytes = await file.readAsBytes();
      
      if (bytes.isEmpty) {
        throw Exception('File is empty');
      }
      
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          bytes,
          filename: fileName,
          contentType: mimeType != null ? MediaType.parse(mimeType) : null,
        ),
        'conversationId': conversationId.toString(),
      });

      final response = await _apiClient.post(
        '/support/attachments',
        data: formData,
      );

      if (response.statusCode == 201 && response.data != null) {
        return ChatAttachment.fromJson(response.data as Map<String, dynamic>);
      }
      throw Exception('Failed to upload attachment');
    } on DioException catch (e) {
      debugPrint('Error uploading attachment: $e');
      rethrow;
    }
  }

  /// Загрузить вложение из bytes (для iOS - обход sandbox ограничений)
  Future<ChatAttachment> uploadAttachmentFromBytes(Uint8List bytes, String fileName, int conversationId) async {
    try {
      if (bytes.isEmpty) {
        throw Exception('File is empty');
      }
      
      final mimeType = _getMimeType(fileName);
      
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          bytes,
          filename: fileName,
          contentType: mimeType != null ? MediaType.parse(mimeType) : null,
        ),
        'conversationId': conversationId.toString(),
      });

      final response = await _apiClient.post(
        '/support/attachments',
        data: formData,
      );

      if (response.statusCode == 201 && response.data != null) {
        return ChatAttachment.fromJson(response.data as Map<String, dynamic>);
      }
      throw Exception('Failed to upload attachment');
    } on DioException catch (e) {
      debugPrint('Error uploading attachment from bytes: $e');
      rethrow;
    }
  }

  String? _getMimeType(String fileName) {
    final ext = fileName.toLowerCase().split('.').last;
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'heic':
      case 'heif':
        return 'image/heic';
      case 'pdf':
        return 'application/pdf';
      default:
        return null;
    }
  }

  /// Получить новые сообщения после указанного ID (для polling)
  Future<List<ChatMessage>> getNewMessages(int conversationId, int afterMessageId) async {
    try {
      final response = await _apiClient.get(
        '/client/chat',
        queryParameters: {
          'afterMessageId': afterMessageId.toString(),
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        
        // messages приходят отдельно от conversation
        final messagesJson = data['messages'] as List<dynamic>? ?? [];
        
        // Парсим только новые сообщения
        return messagesJson
            .map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
            .where((m) => m.id > afterMessageId)
            .toList();
      }
      return [];
    } on DioException catch (e) {
      debugPrint('Error polling messages: $e');
      return [];
    }
  }
}

/// Провайдер репозитория чата
final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  final apiClient = ref.read(apiClientProvider);
  return ChatRepository(apiClient);
});

// ==================== Chat State ====================

/// Состояние чата
class ChatState {
  final ChatConversation? conversation;
  final List<ChatMessage> messages;
  final bool isLoading;
  final bool isSending;
  final bool isUploading;
  final String? error;
  final int? lastMessageId;
  final List<ChatAttachment> pendingAttachments;

  const ChatState({
    this.conversation,
    this.messages = const [],
    this.isLoading = false,
    this.isSending = false,
    this.isUploading = false,
    this.error,
    this.lastMessageId,
    this.pendingAttachments = const [],
  });

  ChatState copyWith({
    ChatConversation? conversation,
    List<ChatMessage>? messages,
    bool? isLoading,
    bool? isSending,
    bool? isUploading,
    String? error,
    int? lastMessageId,
    List<ChatAttachment>? pendingAttachments,
    bool clearError = false,
  }) {
    return ChatState(
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

// ==================== Chat Controller ====================

/// Контроллер чата
class ChatController extends Notifier<ChatState> {
  late final ChatRepository _repository;

  @override
  ChatState build() {
    _repository = ref.read(chatRepositoryProvider);
    return const ChatState();
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
  Future<bool> sendMessage(String content, {List<int>? attachmentIds}) async {
    final hasContent = content.trim().isNotEmpty;
    final hasAttachments = attachmentIds != null && attachmentIds.isNotEmpty;
    
    if (!hasContent && !hasAttachments) return false;
    
    state = state.copyWith(isSending: true, clearError: true);
    
    try {
      final message = await _repository.sendMessage(
        content.trim(),
        attachmentIds: attachmentIds,
      );
      
      // Добавляем сообщение в список
      final newMessages = [...state.messages, message];
      
      state = state.copyWith(
        messages: newMessages,
        isSending: false,
        lastMessageId: message.id,
        pendingAttachments: [], // Очищаем pending attachments
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

  /// Загрузить файл и добавить к pending attachments
  Future<ChatAttachment?> uploadFile(File file) async {
    if (state.conversation == null) return null;
    
    state = state.copyWith(isUploading: true, clearError: true);
    
    try {
      final attachment = await _repository.uploadAttachment(file, state.conversation!.id);
      
      // Добавляем к pending attachments
      state = state.copyWith(
        isUploading: false,
        pendingAttachments: [...state.pendingAttachments, attachment],
      );
      
      return attachment;
    } catch (e) {
      state = state.copyWith(
        isUploading: false,
        error: 'Не удалось загрузить файл',
      );
      return null;
    }
  }

  /// Загрузить файл из bytes и добавить к pending attachments (для iOS)
  Future<ChatAttachment?> uploadFileFromBytes(Uint8List bytes, String fileName) async {
    if (state.conversation == null) return null;
    
    state = state.copyWith(isUploading: true, clearError: true);
    
    try {
      final attachment = await _repository.uploadAttachmentFromBytes(bytes, fileName, state.conversation!.id);
      
      // Добавляем к pending attachments
      state = state.copyWith(
        isUploading: false,
        pendingAttachments: [...state.pendingAttachments, attachment],
      );
      
      return attachment;
    } catch (e) {
      state = state.copyWith(
        isUploading: false,
        error: 'Не удалось загрузить файл',
      );
      return null;
    }
  }

  /// Удалить pending attachment
  void removePendingAttachment(int attachmentId) {
    state = state.copyWith(
      pendingAttachments: state.pendingAttachments.where((a) => a.id != attachmentId).toList(),
    );
  }

  /// Очистить все pending attachments
  void clearPendingAttachments() {
    state = state.copyWith(pendingAttachments: []);
  }

  /// Проверить новые сообщения (polling)
  Future<void> pollNewMessages() async {
    if (state.conversation == null) return;
    
    // Если нет сообщений, загружаем с нуля
    final lastMessageId = state.lastMessageId ?? 0;
    
    try {
      final newMessages = await _repository.getNewMessages(
        state.conversation!.id,
        lastMessageId,
      );
      
      if (newMessages.isNotEmpty) {
        // Фильтруем дубликаты по id
        final existingIds = state.messages.map((m) => m.id).toSet();
        final uniqueNewMessages = newMessages.where((m) => !existingIds.contains(m.id)).toList();
        
        if (uniqueNewMessages.isNotEmpty) {
          final allMessages = [...state.messages, ...uniqueNewMessages];
          final lastId = allMessages.isNotEmpty ? allMessages.last.id : lastMessageId;
          
          state = state.copyWith(
            messages: allMessages,
            lastMessageId: lastId,
          );
          
          // Показать локальное уведомление для сообщений от поддержки
          // только если экран чата закрыт
          final isChatOpen = ref.read(isChatScreenOpenProvider);
          if (!isChatOpen) {
            for (final msg in uniqueNewMessages) {
              if (msg.isFromSupport) {
                final notificationService = ref.read(pushNotificationServiceProvider);
                await notificationService.showChatMessageNotification(
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
      debugPrint('Error polling messages: $e');
    }
  }

  /// Очистить ошибку
  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

/// Провайдер контроллера чата
final chatControllerProvider = NotifierProvider<ChatController, ChatState>(ChatController.new);
