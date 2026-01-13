import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_client.dart';

/// Тип чата для отслеживания присутствия
enum ChatType {
  support,
  payment,
}

/// Состояние присутствия клиента в чатах
class ChatPresenceState {
  final ChatType? openChat;
  final int? conversationId;
  final bool isAppInBackground;

  const ChatPresenceState({
    this.openChat,
    this.conversationId,
    this.isAppInBackground = false,
  });

  ChatPresenceState copyWith({
    ChatType? openChat,
    int? conversationId,
    bool? isAppInBackground,
    bool clearChat = false,
  }) {
    return ChatPresenceState(
      openChat: clearChat ? null : (openChat ?? this.openChat),
      conversationId: clearChat ? null : (conversationId ?? this.conversationId),
      isAppInBackground: isAppInBackground ?? this.isAppInBackground,
    );
  }
}

/// Провайдер для ChatPresenceService
final chatPresenceServiceProvider = Provider<ChatPresenceService>((ref) {
  return ChatPresenceService(ref.read(apiClientProvider));
});

/// Сервис для управления присутствием клиента в чатах
/// 
/// Когда клиент открывает чат, сервис информирует сервер.
/// Сервер не будет отправлять push-уведомления пока чат открыт.
class ChatPresenceService {
  final ApiClient _apiClient;
  Timer? _heartbeatTimer;
  
  // Интервал heartbeat (каждые 2 минуты)
  static const Duration _heartbeatInterval = Duration(minutes: 2);

  ChatPresenceService(this._apiClient);

  /// Уведомить сервер что клиент открыл чат
  Future<void> openChat(ChatType chatType, {int? conversationId}) async {
    try {
      await _apiClient.put(
        '/client/chat-presence',
        data: {
          'chatType': chatType.name,
          'conversationId': conversationId,
          'isOpen': true,
        },
      );
      debugPrint('[ChatPresence] Opened ${chatType.name} chat (conversation: $conversationId)');
      
      // Запускаем heartbeat для поддержания присутствия
      _startHeartbeat(chatType, conversationId);
    } catch (e) {
      debugPrint('[ChatPresence] Error opening chat: $e');
      // Не выбрасываем ошибку - это не критично для работы приложения
    }
  }

  /// Уведомить сервер что клиент закрыл чат
  Future<void> closeChat(ChatType chatType) async {
    try {
      // Останавливаем heartbeat
      _stopHeartbeat();
      
      await _apiClient.put(
        '/client/chat-presence',
        data: {
          'chatType': chatType.name,
          'isOpen': false,
        },
      );
      debugPrint('[ChatPresence] Closed ${chatType.name} chat');
    } catch (e) {
      debugPrint('[ChatPresence] Error closing chat: $e');
    }
  }

  /// Уведомить сервер что приложение ушло в фон
  /// Закрывает все чаты
  Future<void> onAppPaused() async {
    try {
      _stopHeartbeat();
      
      await _apiClient.delete('/client/chat-presence');
      debugPrint('[ChatPresence] App paused - cleared all presence');
    } catch (e) {
      debugPrint('[ChatPresence] Error clearing presence on pause: $e');
    }
  }

  /// Уведомить сервер что приложение вернулось из фона
  /// Нужно заново открыть чат если он был открыт
  Future<void> onAppResumed(ChatType? currentChat, int? conversationId) async {
    if (currentChat != null) {
      await openChat(currentChat, conversationId: conversationId);
    }
  }

  /// Запустить heartbeat для поддержания присутствия
  void _startHeartbeat(ChatType chatType, int? conversationId) {
    _stopHeartbeat();
    
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) async {
      try {
        await _apiClient.put(
          '/client/chat-presence',
          data: {
            'chatType': chatType.name,
            'conversationId': conversationId,
            'isOpen': true,
          },
        );
        debugPrint('[ChatPresence] Heartbeat sent for ${chatType.name} chat');
      } catch (e) {
        debugPrint('[ChatPresence] Heartbeat error: $e');
      }
    });
  }

  /// Остановить heartbeat
  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  /// Освободить ресурсы
  void dispose() {
    _stopHeartbeat();
  }
}
