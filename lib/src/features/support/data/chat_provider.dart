import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
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
  Future<ChatMessage> sendMessage(String content, {String contentType = 'text'}) async {
    try {
      final response = await _apiClient.post(
        '/client/chat',
        data: {
          'content': content,
          'contentType': contentType,
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
  final String? error;
  final int? lastMessageId;

  const ChatState({
    this.conversation,
    this.messages = const [],
    this.isLoading = false,
    this.isSending = false,
    this.error,
    this.lastMessageId,
  });

  ChatState copyWith({
    ChatConversation? conversation,
    List<ChatMessage>? messages,
    bool? isLoading,
    bool? isSending,
    String? error,
    int? lastMessageId,
    bool clearError = false,
  }) {
    return ChatState(
      conversation: conversation ?? this.conversation,
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
      error: clearError ? null : (error ?? this.error),
      lastMessageId: lastMessageId ?? this.lastMessageId,
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
  Future<bool> sendMessage(String content) async {
    if (content.trim().isEmpty) return false;
    
    state = state.copyWith(isSending: true, clearError: true);
    
    try {
      final message = await _repository.sendMessage(content.trim());
      
      // Добавляем сообщение в список
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

  /// Проверить новые сообщения (polling)
  Future<void> pollNewMessages() async {
    if (state.conversation == null || state.lastMessageId == null) return;
    
    try {
      final newMessages = await _repository.getNewMessages(
        state.conversation!.id,
        state.lastMessageId!,
      );
      
      if (newMessages.isNotEmpty) {
        final allMessages = [...state.messages, ...newMessages];
        final lastId = allMessages.isNotEmpty ? allMessages.last.id : state.lastMessageId;
        
        state = state.copyWith(
          messages: allMessages,
          lastMessageId: lastId,
        );
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
