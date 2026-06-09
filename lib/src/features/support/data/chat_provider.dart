import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http_parser/http_parser.dart';
import 'package:twoalogistic_shared/twoalogistic_shared.dart';

import '../../../core/logging/client_log_service.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/push_notification_service.dart';
import '../../../core/services/websocket_provider.dart';
import '../../../core/utils/error_utils.dart';

// ==================== Chat Repository ====================

String _supportChatUserErrorMessage(
  Object error, {
  required String fallbackTitle,
}) {
  final errorInfo = ErrorUtils.getErrorInfo(error);
  final title = ErrorUtils.isNetworkError(error)
      ? errorInfo.titleRu
      : fallbackTitle;
  return '$title\n\n${errorInfo.messageRu}';
}

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
  Future<ChatMessage> sendMessage(
    String content, {
    String contentType = 'text',
    List<int>? attachmentIds,
  }) async {
    try {
      final response = await _apiClient.post(
        '/client/chat',
        data: {
          'content': content,
          'contentType': contentType,
          if (attachmentIds != null && attachmentIds.isNotEmpty)
            'attachmentIds': attachmentIds,
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
  Future<ChatAttachment> uploadAttachmentFromBytes(
    Uint8List bytes,
    String fileName,
    int conversationId,
  ) async {
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
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'ppt':
        return 'application/vnd.ms-powerpoint';
      case 'pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      case 'csv':
        return 'text/csv';
      case 'txt':
        return 'text/plain';
      case 'rtf':
        return 'application/rtf';
      case 'zip':
        return 'application/zip';
      case 'rar':
        return 'application/x-rar-compressed';
      case '7z':
        return 'application/x-7z-compressed';
      default:
        return null;
    }
  }

  /// Получить новые сообщения после указанного ID (для polling)
  Future<List<ChatMessage>> getNewMessages(
    int conversationId,
    int afterMessageId,
  ) async {
    try {
      final response = await _apiClient.get(
        '/client/chat',
        queryParameters: {'afterMessageId': afterMessageId.toString()},
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
  ChatRepository get _repository => ref.read(chatRepositoryProvider);
  late WebSocketService _wsService;
  StreamSubscription<Map<String, dynamic>>? _messageSubscription;
  StreamSubscription<Map<String, dynamic>>? _messageEditedSubscription;
  StreamSubscription<Map<String, dynamic>>? _messageDeletedSubscription;
  Timer? _fallbackPollingTimer;
  bool _isRealtimeActive = false;

  @override
  ChatState build() {
    _wsService = ref.watch(webSocketServiceProvider);
    _listenToWebSocket();

    // Cleanup при dispose
    ref.onDispose(() {
      _messageSubscription?.cancel();
      _messageEditedSubscription?.cancel();
      _messageDeletedSubscription?.cancel();
      _fallbackPollingTimer?.cancel();
      if (state.conversation != null) {
        _wsService.leaveConversation(state.conversation!.id);
        _wsService.sendPresence(state.conversation!.id, false);
      }
    });

    return const ChatState();
  }

  /// Слушать WebSocket события
  void _listenToWebSocket() {
    // Слушаем статус подключения для fallback
    ref.listen<AsyncValue<SocketConnectionStatus>>(
      webSocketConnectionStatusProvider,
      (previous, next) {
        next.whenData((status) {
          if (!_isRealtimeActive) {
            _fallbackPollingTimer?.cancel();
            return;
          }
          if (status == SocketConnectionStatus.connected) {
            // WebSocket подключен - отменяем fallback polling
            _fallbackPollingTimer?.cancel();
            // Переприсоединяемся к комнате после reconnect
            if (state.conversation != null) {
              _wsService.joinConversation(state.conversation!.id);
              _wsService.sendPresence(state.conversation!.id, true);
            }
          } else if (status == SocketConnectionStatus.disconnected) {
            // WebSocket отключен - начинаем fallback polling
            _startFallbackPolling();
          }
        });
      },
    );

    // Слушаем новые сообщения (отменяем предыдущую подписку при reconnect)
    _messageSubscription?.cancel();
    _messageSubscription = _wsService.messages.listen((data) {
      if (!_isRealtimeActive) return;
      try {
        final message = ChatMessage.fromJson(data);

        // Добавляем сообщение только если оно для текущего conversation
        if (state.conversation != null &&
            message.conversationId == state.conversation!.id) {
          // Проверка на дубликаты
          final existingIds = state.messages.map((m) => m.id).toSet();
          if (!existingIds.contains(message.id)) {
            final newMessages = [...state.messages, message];
            state = state.copyWith(
              messages: newMessages,
              lastMessageId: message.id,
            );

            // Показать локальное уведомление если чат закрыт
            if (message.isFromSupport) {
              final isChatOpen = ref.read(isChatScreenOpenProvider);
              if (!isChatOpen) {
                final notificationService = ref.read(
                  pushNotificationServiceProvider,
                );
                notificationService.showChatMessageNotification(
                  senderName: message.senderName,
                  message: message.content,
                  notificationId: message.id,
                );
              }
            }
          }
        }
      } catch (e) {
        debugPrint('[WebSocket] Error parsing message: $e');
      }
    });

    // Слушаем редактирование сообщений (отменяем предыдущую подписку при reconnect)
    _messageEditedSubscription?.cancel();
    _messageEditedSubscription = _wsService.messageEdited.listen((data) {
      if (!_isRealtimeActive) return;
      try {
        final editedMessage = ChatMessage.fromJson(data);
        if (state.conversation != null &&
            editedMessage.conversationId == state.conversation!.id) {
          final updatedMessages = state.messages.map((m) {
            return m.id == editedMessage.id ? editedMessage : m;
          }).toList();
          state = state.copyWith(messages: updatedMessages);
        }
      } catch (e) {
        debugPrint('[WebSocket] Error parsing edited message: $e');
      }
    });

    // Слушаем удаление сообщений
    _messageDeletedSubscription?.cancel();
    _messageDeletedSubscription = _wsService.messageDeleted.listen((data) {
      if (!_isRealtimeActive) return;
      try {
        final msgId = data['id'] as int?;
        final convId = data['conversationId'] as int?;
        if (msgId != null && state.conversation?.id == convId) {
          state = state.copyWith(
            messages: state.messages.where((m) => m.id != msgId).toList(),
          );
        }
      } catch (e) {
        debugPrint('[WebSocket] Error parsing deleted message: $e');
      }
    });
  }

  /// Fallback polling если WebSocket не работает
  void _startFallbackPolling() {
    if (!_isRealtimeActive) return;
    _fallbackPollingTimer?.cancel();
    _fallbackPollingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_isRealtimeActive) {
        _fallbackPollingTimer?.cancel();
        return;
      }
      if (_wsService.currentStatus != SocketConnectionStatus.connected) {
        pollNewMessages();
      }
    });
  }

  /// Включает/выключает realtime-активность чата без уничтожения состояния.
  ///
  /// Support tab живёт в StatefulShellRoute.indexedStack, поэтому dispose()
  /// не вызывается при уходе на главную/другую вкладку. Этот флаг гасит
  /// polling, presence и обработку WS-событий до возврата на вкладку.
  void setRealtimeActive(bool active) {
    if (_isRealtimeActive == active) return;
    _isRealtimeActive = active;

    if (!active) {
      _fallbackPollingTimer?.cancel();
      if (state.conversation != null) {
        _wsService.leaveConversation(state.conversation!.id);
        _wsService.sendPresence(state.conversation!.id, false);
      }
      return;
    }

    if (state.conversation != null) {
      _wsService.joinConversation(state.conversation!.id);
      _wsService.sendPresence(state.conversation!.id, true);
      if (_wsService.currentStatus != SocketConnectionStatus.connected) {
        _startFallbackPolling();
      }
      unawaited(pollNewMessages());
    }
  }

  /// Загрузить диалог
  Future<void> loadConversation() async {
    state = state.copyWith(isLoading: true, clearError: true);
    ClientLogService.instance.action('Загрузка чата поддержки');

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

      // Присоединяемся к WebSocket комнате только пока вкладка активна.
      if (_isRealtimeActive) {
        _wsService.joinConversation(conversation.id);
        _wsService.sendPresence(conversation.id, true);
      }
      ClientLogService.instance.add(
        type: 'support_chat_loaded',
        level: 'info',
        message: 'Чат поддержки загружен',
        data: {
          'conversationId': conversation.id,
          'messagesCount': messages.length,
          'lastMessageId': lastId,
        },
      );
    } catch (e) {
      ClientLogService.instance.add(
        type: 'support_chat_load_error',
        level: 'warning',
        message: 'Не удалось загрузить чат поддержки',
        data: {'error': e.toString()},
      );
      state = state.copyWith(
        isLoading: false,
        error: _supportChatUserErrorMessage(
          e,
          fallbackTitle: 'Не удалось загрузить чат поддержки',
        ),
      );
    }
  }

  /// Отправить сообщение
  Future<bool> sendMessage(String content, {List<int>? attachmentIds}) async {
    final hasContent = content.trim().isNotEmpty;
    final hasAttachments = attachmentIds != null && attachmentIds.isNotEmpty;

    if (!hasContent && !hasAttachments) return false;
    if (state.isSending) return false;

    state = state.copyWith(isSending: true, clearError: true);
    ClientLogService.instance.action(
      'Отправка сообщения в чат поддержки',
      data: {
        'hasContent': hasContent,
        'attachmentsCount': attachmentIds?.length ?? 0,
      },
    );

    try {
      final message = await _repository.sendMessage(
        content.trim(),
        attachmentIds: attachmentIds,
      );

      // WebSocket может добавить это же сообщение раньше ответа POST.
      final messageExists = state.messages.any((m) => m.id == message.id);
      final newMessages = messageExists
          ? state.messages
          : [...state.messages, message];
      final currentLastMessageId = state.lastMessageId;
      final nextLastMessageId =
          currentLastMessageId == null || message.id > currentLastMessageId
          ? message.id
          : currentLastMessageId;

      state = state.copyWith(
        messages: newMessages,
        isSending: false,
        lastMessageId: nextLastMessageId,
        pendingAttachments: [], // Очищаем pending attachments
      );
      ClientLogService.instance.add(
        type: 'support_chat_message_sent',
        level: 'info',
        message: 'Сообщение в чат поддержки отправлено',
        data: {'messageId': message.id, 'hasAttachments': hasAttachments},
      );
      return true;
    } catch (e) {
      ClientLogService.instance.add(
        type: 'support_chat_message_send_error',
        level: 'warning',
        message: 'Ошибка отправки сообщения в чат поддержки',
        data: {'error': e.toString(), 'hasAttachments': hasAttachments},
      );
      state = state.copyWith(
        isSending: false,
        error: _supportChatUserErrorMessage(
          e,
          fallbackTitle: 'Не удалось отправить сообщение',
        ),
      );
      return false;
    }
  }

  /// Загрузить файл и добавить к pending attachments
  Future<ChatAttachment?> uploadFile(File file) async {
    if (state.conversation == null) return null;

    state = state.copyWith(isUploading: true, clearError: true);
    ClientLogService.instance.action(
      'Загрузка файла в чат поддержки',
      data: {'source': 'file', 'conversationId': state.conversation!.id},
    );

    try {
      final attachment = await _repository.uploadAttachment(
        file,
        state.conversation!.id,
      );

      // Добавляем к pending attachments
      state = state.copyWith(
        isUploading: false,
        pendingAttachments: [...state.pendingAttachments, attachment],
      );
      ClientLogService.instance.add(
        type: 'support_chat_attachment_uploaded',
        level: 'info',
        message: 'Файл в чат поддержки загружен',
        data: {'attachmentId': attachment.id, 'source': 'file'},
      );

      return attachment;
    } catch (e) {
      ClientLogService.instance.add(
        type: 'support_chat_attachment_upload_error',
        level: 'warning',
        message: 'Ошибка загрузки файла в чат поддержки',
        data: {'error': e.toString(), 'source': 'file'},
      );
      state = state.copyWith(
        isUploading: false,
        error: _supportChatUserErrorMessage(
          e,
          fallbackTitle: 'Не удалось загрузить файл',
        ),
      );
      return null;
    }
  }

  /// Загрузить файл из bytes и добавить к pending attachments (для iOS)
  Future<ChatAttachment?> uploadFileFromBytes(
    Uint8List bytes,
    String fileName,
  ) async {
    if (state.conversation == null) return null;

    state = state.copyWith(isUploading: true, clearError: true);
    ClientLogService.instance.action(
      'Загрузка файла из bytes в чат поддержки',
      data: {
        'source': 'bytes',
        'bytes': bytes.length,
        'extension': fileName.contains('.')
            ? fileName.split('.').last.toLowerCase()
            : '',
        'conversationId': state.conversation!.id,
      },
    );

    try {
      final attachment = await _repository.uploadAttachmentFromBytes(
        bytes,
        fileName,
        state.conversation!.id,
      );

      // Добавляем к pending attachments
      state = state.copyWith(
        isUploading: false,
        pendingAttachments: [...state.pendingAttachments, attachment],
      );
      ClientLogService.instance.add(
        type: 'support_chat_attachment_uploaded',
        level: 'info',
        message: 'Файл из bytes в чат поддержки загружен',
        data: {'attachmentId': attachment.id, 'source': 'bytes'},
      );

      return attachment;
    } catch (e) {
      ClientLogService.instance.add(
        type: 'support_chat_attachment_upload_error',
        level: 'warning',
        message: 'Ошибка загрузки файла из bytes в чат поддержки',
        data: {'error': e.toString(), 'source': 'bytes'},
      );
      state = state.copyWith(
        isUploading: false,
        error: _supportChatUserErrorMessage(
          e,
          fallbackTitle: 'Не удалось загрузить файл',
        ),
      );
      return null;
    }
  }

  /// Удалить pending attachment
  void removePendingAttachment(int attachmentId) {
    state = state.copyWith(
      pendingAttachments: state.pendingAttachments
          .where((a) => a.id != attachmentId)
          .toList(),
    );
  }

  /// Очистить все pending attachments
  void clearPendingAttachments() {
    state = state.copyWith(pendingAttachments: []);
  }

  /// Проверить новые сообщения (polling)
  Future<void> pollNewMessages() async {
    if (!_isRealtimeActive) return;
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
        final uniqueNewMessages = newMessages
            .where((m) => !existingIds.contains(m.id))
            .toList();

        if (uniqueNewMessages.isNotEmpty) {
          final allMessages = [...state.messages, ...uniqueNewMessages];
          final lastId = allMessages.isNotEmpty
              ? allMessages.last.id
              : lastMessageId;

          state = state.copyWith(messages: allMessages, lastMessageId: lastId);
          ClientLogService.instance.add(
            type: 'support_chat_poll_new_messages',
            level: 'info',
            message: 'Получены новые сообщения чата поддержки через polling',
            data: {'count': uniqueNewMessages.length, 'lastMessageId': lastId},
          );

          // Показать локальное уведомление для сообщений от поддержки
          // только если экран чата закрыт
          final isChatOpen = ref.read(isChatScreenOpenProvider);
          if (!isChatOpen) {
            for (final msg in uniqueNewMessages) {
              if (msg.isFromSupport) {
                final notificationService = ref.read(
                  pushNotificationServiceProvider,
                );
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
      ClientLogService.instance.add(
        type: 'support_chat_poll_error',
        level: 'warning',
        message: 'Ошибка polling чата поддержки',
        data: {'error': e.toString()},
      );
      debugPrint('Error polling messages: $e');
    }
  }

  /// Очистить ошибку
  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

/// Провайдер контроллера чата
final chatControllerProvider = NotifierProvider<ChatController, ChatState>(
  ChatController.new,
);
