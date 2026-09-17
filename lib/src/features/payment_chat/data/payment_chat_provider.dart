import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http_parser/http_parser.dart';
import 'package:twoalogistic_shared/twoalogistic_shared.dart';

import '../../../core/logging/client_log_service.dart';
import '../../../core/models/chat_history_page.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/push_notification_service.dart';
import '../../../core/services/websocket_provider.dart';
import '../../../core/utils/error_utils.dart';

// ==================== Payment Chat Repository ====================

String _paymentChatUserErrorMessage(
  Object error, {
  required String fallbackTitle,
}) {
  final errorInfo = ErrorUtils.getErrorInfo(error);
  final title = ErrorUtils.isNetworkError(error)
      ? errorInfo.titleRu
      : fallbackTitle;
  return '$title\n\n${errorInfo.messageRu}';
}

/// Простой Notifier для bool состояния (открыт ли экран чата по оплате)
class IsPaymentChatScreenOpenNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}

/// Провайдер флага открытия экрана чата по оплате
final isPaymentChatScreenOpenProvider =
    NotifierProvider<IsPaymentChatScreenOpenNotifier, bool>(
      IsPaymentChatScreenOpenNotifier.new,
    );

/// Репозиторий для работы с чатом по оплате
class PaymentChatRepository {
  final ApiClient _apiClient;

  PaymentChatRepository(this._apiClient);

  Future<ChatHistoryPage> getHistoryPage({int? beforeMessageId}) async {
    final response = await _apiClient.get(
      '/client/payment-chat',
      queryParameters: {
        'limit': 50,
        if (beforeMessageId != null) 'beforeMessageId': beforeMessageId,
      },
    );
    return ChatHistoryPage.fromJson(response.data as Map<String, dynamic>);
  }

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
  Future<ChatMessage> sendMessage(
    String content, {
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
          if (attachmentIds != null && attachmentIds.isNotEmpty)
            'attachmentIds': attachmentIds,
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
  Future<Map<String, dynamic>?> uploadAttachment(
    File file,
    int conversationId,
  ) async {
    try {
      final fileName = file.path.split('/').last;
      final extension = fileName.split('.').last.toLowerCase();

      // Читаем файл в память сразу, чтобы избежать проблем с временными файлами iOS
      final bytes = await file.readAsBytes();

      if (bytes.isEmpty) {
        debugPrint('Error: File is empty');
        return null;
      }

      return _uploadAttachmentBytes(bytes, fileName, extension, conversationId);
    } on DioException catch (e) {
      debugPrint('Error uploading payment chat attachment: $e');
      return null;
    }
  }

  /// Загрузить файл из bytes в чат (для iOS - обход sandbox ограничений)
  Future<Map<String, dynamic>?> uploadAttachmentFromBytes(
    Uint8List bytes,
    String fileName,
    int conversationId,
  ) async {
    try {
      if (bytes.isEmpty) {
        debugPrint('Error: File is empty');
        return null;
      }

      final extension = fileName.split('.').last.toLowerCase();
      return _uploadAttachmentBytes(bytes, fileName, extension, conversationId);
    } on DioException catch (e) {
      debugPrint('Error uploading payment chat attachment from bytes: $e');
      return null;
    }
  }

  /// Внутренний метод загрузки bytes
  Future<Map<String, dynamic>?> _uploadAttachmentBytes(
    Uint8List bytes,
    String fileName,
    String extension,
    int conversationId,
  ) async {
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
      case 'heic':
      case 'heif':
        mimeType = 'image';
        mimeSubtype = 'heic';
        break;
      case 'pdf':
        mimeType = 'application';
        mimeSubtype = 'pdf';
        break;
      case 'doc':
        mimeType = 'application';
        mimeSubtype = 'msword';
        break;
      case 'docx':
        mimeType = 'application';
        mimeSubtype =
            'vnd.openxmlformats-officedocument.wordprocessingml.document';
        break;
      case 'xls':
        mimeType = 'application';
        mimeSubtype = 'vnd.ms-excel';
        break;
      case 'xlsx':
        mimeType = 'application';
        mimeSubtype = 'vnd.openxmlformats-officedocument.spreadsheetml.sheet';
        break;
      case 'ppt':
        mimeType = 'application';
        mimeSubtype = 'vnd.ms-powerpoint';
        break;
      case 'pptx':
        mimeType = 'application';
        mimeSubtype =
            'vnd.openxmlformats-officedocument.presentationml.presentation';
        break;
      case 'csv':
        mimeType = 'text';
        mimeSubtype = 'csv';
        break;
      case 'txt':
        mimeType = 'text';
        mimeSubtype = 'plain';
        break;
      case 'rtf':
        mimeType = 'application';
        mimeSubtype = 'rtf';
        break;
      case 'zip':
        mimeType = 'application';
        mimeSubtype = 'zip';
        break;
      case 'rar':
        mimeType = 'application';
        mimeSubtype = 'x-rar-compressed';
        break;
      case '7z':
        mimeType = 'application';
        mimeSubtype = 'x-7z-compressed';
        break;
      default:
        mimeType = 'application';
        mimeSubtype = 'octet-stream';
    }

    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(
        bytes,
        filename: fileName,
        contentType: MediaType(mimeType, mimeSubtype),
      ),
      'conversationId': conversationId.toString(),
    });

    final response = await _apiClient.post(
      '/support/attachments',
      data: formData,
      options: Options(headers: {'Content-Type': 'multipart/form-data'}),
    );

    if (response.statusCode == 201 && response.data != null) {
      return response.data as Map<String, dynamic>;
    }
    return null;
  }

  /// Получить новые сообщения после указанного ID (для polling)
  Future<List<ChatMessage>> getNewMessages(
    int conversationId,
    int afterMessageId,
  ) async {
    try {
      final response = await _apiClient.get(
        '/client/payment-chat',
        queryParameters: {'afterMessageId': afterMessageId.toString()},
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
  final bool hasMoreHistory;
  final bool isLoadingHistory;
  final bool historyError;

  const PaymentChatState({
    this.conversation,
    this.messages = const [],
    this.isLoading = false,
    this.isSending = false,
    this.isUploading = false,
    this.error,
    this.lastMessageId,
    this.pendingAttachments = const [],
    this.hasMoreHistory = false,
    this.isLoadingHistory = false,
    this.historyError = false,
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
    bool? hasMoreHistory,
    bool? isLoadingHistory,
    bool? historyError,
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
      hasMoreHistory: hasMoreHistory ?? this.hasMoreHistory,
      isLoadingHistory: isLoadingHistory ?? this.isLoadingHistory,
      historyError: historyError ?? this.historyError,
    );
  }
}

// ==================== Payment Chat Controller ====================

/// Контроллер чата по оплате
class PaymentChatController extends Notifier<PaymentChatState> {
  PaymentChatRepository get _repository =>
      ref.read(paymentChatRepositoryProvider);
  late WebSocketService _wsService;
  StreamSubscription<Map<String, dynamic>>? _messageSubscription;
  StreamSubscription<Map<String, dynamic>>? _messageEditedSubscription;
  StreamSubscription<Map<String, dynamic>>? _messageDeletedSubscription;
  Timer? _fallbackPollingTimer;

  bool _isDisposed = false;
  bool _isRealtimeActive = false;
  bool _pollInFlight = false;
  int _generation = 0;
  int _loadGeneration = 0;
  int? _conversationIdForCleanup;

  @override
  PaymentChatState build() {
    _generation++;
    _loadGeneration++;
    _isDisposed = false;
    _wsService = ref.watch(webSocketServiceProvider);
    _listenToWebSocket();

    // Cleanup при dispose
    ref.onDispose(() {
      _generation++;
      _loadGeneration++;
      _isDisposed = true;
      _messageSubscription?.cancel();
      _messageEditedSubscription?.cancel();
      _messageDeletedSubscription?.cancel();
      _fallbackPollingTimer?.cancel();
      final conversationId = _conversationIdForCleanup;
      if (conversationId != null) {
        _wsService.leaveConversation(conversationId);
        _wsService.sendPresence(conversationId, false);
      }
    });

    return const PaymentChatState();
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
            _fallbackPollingTimer?.cancel();
          } else if (status == SocketConnectionStatus.disconnected) {
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

        if (state.conversation != null &&
            message.conversationId == state.conversation!.id) {
          final existingIds = state.messages.map((m) => m.id).toSet();
          if (!existingIds.contains(message.id)) {
            final newMessages = [...state.messages, message];
            state = state.copyWith(
              messages: newMessages,
              lastMessageId: message.id,
            );

            if (message.isFromSupport) {
              final isChatOpen = ref.read(isPaymentChatScreenOpenProvider);
              if (!isChatOpen) {
                final notificationService = ref.read(
                  pushNotificationServiceProvider,
                );
                notificationService.showPaymentChatMessageNotification(
                  senderName: message.senderName,
                  message: message.content,
                  notificationId: message.id,
                );
              }
            }
          }
        }
      } catch (e) {
        debugPrint('[WebSocket] Error parsing payment message: $e');
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
        debugPrint('[WebSocket] Error parsing edited payment message: $e');
      }
    });

    // Слушаем удаление сообщений
    _messageDeletedSubscription?.cancel();
    _messageDeletedSubscription = _wsService.messageDeleted.listen((data) {
      if (!_isRealtimeActive) return;
      try {
        final deletedId = data['id'] as int?;
        final convId = data['conversationId'] as int?;
        if (deletedId != null &&
            state.conversation != null &&
            convId == state.conversation!.id) {
          final filtered = state.messages
              .where((m) => m.id != deletedId)
              .toList();
          state = state.copyWith(messages: filtered);
        }
      } catch (e) {
        debugPrint('[WebSocket] Error parsing deleted payment message: $e');
      }
    });
  }

  /// Fallback polling если WebSocket не работает
  void _startFallbackPolling() {
    if (!_isRealtimeActive) return;
    _fallbackPollingTimer?.cancel();
    _fallbackPollingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_isDisposed || !_isRealtimeActive) {
        _fallbackPollingTimer?.cancel();
        return;
      }
      if (_wsService.currentStatus != SocketConnectionStatus.connected) {
        pollNewMessages();
      }
    });
  }

  /// Включает/выключает realtime-активность чата без уничтожения истории.
  ///
  /// Payment chat открыт отдельным root-route, но provider не autoDispose,
  /// поэтому после выхода со страницы нужно явно гасить polling и presence.
  void setRealtimeActive(bool active) {
    if (_isDisposed || _isRealtimeActive == active) return;
    _isRealtimeActive = active;
    _generation++;

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
    _generation++;
    final generation = ++_loadGeneration;
    state = state.copyWith(
      isLoading: true,
      isLoadingHistory: false,
      clearError: true,
    );
    ClientLogService.instance.action('Загрузка чата по оплате');

    try {
      final page = await _repository.getHistoryPage();
      if (!ref.mounted || generation != _loadGeneration) return;
      final conversation = page.conversation;
      _conversationIdForCleanup = conversation.id;
      final messages = conversation.messages;
      final lastId = messages.isNotEmpty ? messages.last.id : 0;

      state = state.copyWith(
        conversation: conversation,
        messages: messages,
        isLoading: false,
        lastMessageId: lastId,
        hasMoreHistory: page.hasMore,
      );

      // Присоединяемся к WebSocket комнате только пока экран активен.
      if (_isRealtimeActive) {
        _wsService.joinConversation(conversation.id);
        _wsService.sendPresence(conversation.id, true);
      }
      ClientLogService.instance.add(
        type: 'payment_chat_loaded',
        level: 'info',
        message: 'Чат по оплате загружен',
        data: {
          'conversationId': conversation.id,
          'messagesCount': messages.length,
          'lastMessageId': lastId,
        },
      );
    } catch (e) {
      if (!ref.mounted || generation != _loadGeneration) return;
      ClientLogService.instance.add(
        type: 'payment_chat_load_error',
        level: 'warning',
        message: 'Не удалось загрузить чат по оплате',
        data: {'error': e.toString()},
      );
      state = state.copyWith(
        isLoading: false,
        error: _paymentChatUserErrorMessage(
          e,
          fallbackTitle: 'Не удалось загрузить чат по оплате',
        ),
      );
    }
  }

  /// Отправить сообщение
  Future<bool> sendMessage(
    String content, {
    Map<String, dynamic>? metadata,
    List<int>? attachmentIds,
  }) async {
    if (!ref.mounted || state.isSending) return false;
    if (content.trim().isEmpty &&
        (attachmentIds == null || attachmentIds.isEmpty)) {
      return false;
    }

    state = state.copyWith(isSending: true, clearError: true);
    ClientLogService.instance.action(
      'Отправка сообщения в чат по оплате',
      data: {
        'hasContent': content.trim().isNotEmpty,
        'attachmentsCount': attachmentIds?.length ?? 0,
        'hasMetadata': metadata != null && metadata.isNotEmpty,
      },
    );

    try {
      final message = await _repository.sendMessage(
        content.trim(),
        metadata: metadata,
        attachmentIds: attachmentIds,
      );
      if (!ref.mounted) return false;
      final newMessages = state.messages.any((m) => m.id == message.id)
          ? state.messages
          : [...state.messages, message];

      state = state.copyWith(
        messages: newMessages,
        isSending: false,
        lastMessageId: (state.lastMessageId ?? 0) > message.id
            ? state.lastMessageId
            : message.id,
      );
      ClientLogService.instance.add(
        type: 'payment_chat_message_sent',
        level: 'info',
        message: 'Сообщение в чат по оплате отправлено',
        data: {
          'messageId': message.id,
          'hasAttachments': attachmentIds != null && attachmentIds.isNotEmpty,
        },
      );
      return true;
    } catch (e) {
      if (!ref.mounted) return false;
      ClientLogService.instance.add(
        type: 'payment_chat_message_send_error',
        level: 'warning',
        message: 'Ошибка отправки сообщения в чат по оплате',
        data: {'error': e.toString()},
      );
      state = state.copyWith(
        isSending: false,
        error: _paymentChatUserErrorMessage(
          e,
          fallbackTitle: 'Не удалось отправить сообщение',
        ),
      );
      return false;
    }
  }

  /// Загрузить файл на сервер
  Future<Map<String, dynamic>?> uploadFile(
    File file,
    int conversationId,
  ) async {
    state = state.copyWith(isUploading: true, clearError: true);
    ClientLogService.instance.action(
      'Загрузка файла в чат по оплате',
      data: {'source': 'file', 'conversationId': conversationId},
    );

    try {
      final result = await _repository.uploadAttachment(file, conversationId);
      if (!ref.mounted) return null;

      if (result != null) {
        // Добавляем в pending attachments
        state = state.copyWith(
          isUploading: false,
          pendingAttachments: [...state.pendingAttachments, result],
        );
        ClientLogService.instance.add(
          type: 'payment_chat_attachment_uploaded',
          level: 'info',
          message: 'Файл в чат по оплате загружен',
          data: {'source': 'file', 'attachmentId': result['id']},
        );
        return result;
      }

      ClientLogService.instance.add(
        type: 'payment_chat_attachment_upload_error',
        level: 'warning',
        message: 'Загрузка файла в чат по оплате вернула пустой ответ',
        data: {'source': 'file'},
      );
      state = state.copyWith(
        isUploading: false,
        error: 'Не удалось загрузить файл',
      );
      return null;
    } catch (e) {
      if (!ref.mounted) return null;
      ClientLogService.instance.add(
        type: 'payment_chat_attachment_upload_error',
        level: 'warning',
        message: 'Ошибка загрузки файла в чат по оплате',
        data: {'source': 'file', 'error': e.toString()},
      );
      state = state.copyWith(
        isUploading: false,
        error: _paymentChatUserErrorMessage(
          e,
          fallbackTitle: 'Не удалось загрузить файл',
        ),
      );
      return null;
    }
  }

  /// Загрузить файл из bytes на сервер (для iOS - обход sandbox ограничений)
  Future<Map<String, dynamic>?> uploadFileFromBytes(
    Uint8List bytes,
    String fileName,
    int conversationId,
  ) async {
    state = state.copyWith(isUploading: true, clearError: true);
    ClientLogService.instance.action(
      'Загрузка файла из bytes в чат по оплате',
      data: {
        'source': 'bytes',
        'bytes': bytes.length,
        'extension': fileName.contains('.')
            ? fileName.split('.').last.toLowerCase()
            : '',
        'conversationId': conversationId,
      },
    );

    try {
      final result = await _repository.uploadAttachmentFromBytes(
        bytes,
        fileName,
        conversationId,
      );
      if (!ref.mounted) return null;

      if (result != null) {
        // Добавляем в pending attachments
        state = state.copyWith(
          isUploading: false,
          pendingAttachments: [...state.pendingAttachments, result],
        );
        ClientLogService.instance.add(
          type: 'payment_chat_attachment_uploaded',
          level: 'info',
          message: 'Файл из bytes в чат по оплате загружен',
          data: {'source': 'bytes', 'attachmentId': result['id']},
        );
        return result;
      }

      ClientLogService.instance.add(
        type: 'payment_chat_attachment_upload_error',
        level: 'warning',
        message: 'Загрузка файла из bytes в чат по оплате вернула пустой ответ',
        data: {'source': 'bytes'},
      );
      state = state.copyWith(
        isUploading: false,
        error: 'Не удалось загрузить файл',
      );
      return null;
    } catch (e) {
      if (!ref.mounted) return null;
      ClientLogService.instance.add(
        type: 'payment_chat_attachment_upload_error',
        level: 'warning',
        message: 'Ошибка загрузки файла из bytes в чат по оплате',
        data: {'source': 'bytes', 'error': e.toString()},
      );
      state = state.copyWith(
        isUploading: false,
        error: _paymentChatUserErrorMessage(
          e,
          fallbackTitle: 'Не удалось загрузить файл',
        ),
      );
      return null;
    }
  }

  /// Удалить pending attachment
  void removePendingAttachment(String id) {
    // PU-M6: a['id'] обычно приходит как int (id из backend), а параметр id —
    // String. Прямое сравнение `a['id'] != id` всегда истинно → never removed.
    // Приводим обе стороны к String, тогда сравнение корректно.
    state = state.copyWith(
      pendingAttachments: state.pendingAttachments
          .where((a) => a['id']?.toString() != id)
          .toList(),
    );
  }

  /// Очистить все pending attachments
  void clearPendingAttachments() {
    state = state.copyWith(pendingAttachments: []);
  }

  /// Проверить новые сообщения (polling)
  Future<void> pollNewMessages() async {
    if (!ref.mounted || _pollInFlight) return;
    if (_isDisposed || !_isRealtimeActive || state.conversation == null) return;

    final lastMessageId = state.lastMessageId ?? 0;
    final conversationId = state.conversation!.id;
    final generation = _generation;
    _pollInFlight = true;

    try {
      final newMessages = await _repository.getNewMessages(
        conversationId,
        lastMessageId,
      );
      if (!ref.mounted ||
          generation != _generation ||
          !_isRealtimeActive ||
          state.conversation?.id != conversationId) {
        return;
      }

      if (newMessages.isNotEmpty) {
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
            type: 'payment_chat_poll_new_messages',
            level: 'info',
            message: 'Получены новые сообщения чата по оплате через polling',
            data: {'count': uniqueNewMessages.length, 'lastMessageId': lastId},
          );

          // Показать локальное уведомление для сообщений от бухгалтерии
          final isChatOpen = ref.read(isPaymentChatScreenOpenProvider);
          if (!isChatOpen) {
            for (final msg in uniqueNewMessages) {
              if (msg.isFromSupport) {
                final notificationService = ref.read(
                  pushNotificationServiceProvider,
                );
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
      ClientLogService.instance.add(
        type: 'payment_chat_poll_error',
        level: 'warning',
        message: 'Ошибка polling чата по оплате',
        data: {'error': e.toString()},
      );
      debugPrint('Error polling payment messages: $e');
    } finally {
      _pollInFlight = false;
    }
  }

  Future<void> loadOlderMessages() async {
    if (!ref.mounted ||
        state.isLoadingHistory ||
        !state.hasMoreHistory ||
        state.messages.isEmpty) {
      return;
    }
    final generation = _loadGeneration;
    final conversationId = state.conversation!.id;
    final before = state.messages
        .map((m) => m.id)
        .reduce((a, b) => a < b ? a : b);
    state = state.copyWith(isLoadingHistory: true, historyError: false);
    try {
      final page = await _repository.getHistoryPage(beforeMessageId: before);
      if (!ref.mounted ||
          generation != _loadGeneration ||
          state.conversation?.id != conversationId) {
        return;
      }
      final ids = state.messages.map((m) => m.id).toSet();
      final older = page.conversation.messages
          .where((m) => !ids.contains(m.id))
          .toList();
      state = state.copyWith(
        messages: [...older, ...state.messages],
        hasMoreHistory: page.hasMore && older.isNotEmpty,
      );
    } catch (_) {
      if (ref.mounted && generation == _loadGeneration) {
        state = state.copyWith(historyError: true);
      }
    } finally {
      if (ref.mounted &&
          generation == _loadGeneration &&
          state.conversation?.id == conversationId) {
        state = state.copyWith(isLoadingHistory: false);
      }
    }
  }

  /// Очистить ошибку
  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

/// Провайдер контроллера чата по оплате
final paymentChatControllerProvider =
    NotifierProvider<PaymentChatController, PaymentChatState>(
      PaymentChatController.new,
    );
