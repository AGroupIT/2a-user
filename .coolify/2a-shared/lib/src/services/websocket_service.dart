import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'dart:async';

import '../models/common/delta_event.dart';

/// Статус подключения WebSocket
enum SocketConnectionStatus {
  disconnected,
  connecting,
  connected,
  reconnecting,
}

/// Сервис для управления WebSocket подключением
class WebSocketService {
  IO.Socket? _socket;
  String? _token;
  final String _serverUrl;

  final _connectionStatusController =
      StreamController<SocketConnectionStatus>.broadcast();
  Stream<SocketConnectionStatus> get connectionStatus =>
      _connectionStatusController.stream;

  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get messages => _messageController.stream;

  final _conversationUpdateController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get conversationUpdates =>
      _conversationUpdateController.stream;

  final _typingController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get typing => _typingController.stream;

  final _presenceController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get presence => _presenceController.stream;

  final _messageEditedController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get messageEdited =>
      _messageEditedController.stream;

  final _messageDeletedController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get messageDeleted =>
      _messageDeletedController.stream;

  final _messagesReadController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get messagesRead =>
      _messagesReadController.stream;

  final _dataChangedController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get dataChanged => _dataChangedController.stream;

  final _taskPresenceController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get taskPresence =>
      _taskPresenceController.stream;

  final _taskPresenceDisconnectController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get taskPresenceDisconnect =>
      _taskPresenceDisconnectController.stream;

  final _taskDeltaController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get taskDelta => _taskDeltaController.stream;

  final _assemblyDeltaController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get assemblyDelta =>
      _assemblyDeltaController.stream;

  final _employeeChatPresenceController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get employeeChatPresence =>
      _employeeChatPresenceController.stream;

  // === Delta Sync streams ===
  final _deltaController = StreamController<DeltaEvent>.broadcast();
  Stream<DeltaEvent> get deltas => _deltaController.stream;

  final _deltaBatchController = StreamController<DeltaBatchEvent>.broadcast();
  Stream<DeltaBatchEvent> get deltaBatches => _deltaBatchController.stream;

  /// Fires when connection is restored after a disconnect.
  /// Providers should do a full refetch when this fires.
  final _reconnectedController = StreamController<void>.broadcast();
  Stream<void> get reconnected => _reconnectedController.stream;

  bool _wasConnected = false;
  DateTime? _disconnectedAt;

  // Heartbeat & force reconnect
  String? _lastConnectedUrl;
  Timer? _heartbeatTimer;
  bool _isForceReconnecting = false;
  static const _heartbeatInterval = Duration(seconds: 30);
  static const _forceReconnectAfter = Duration(seconds: 120);

  SocketConnectionStatus _currentStatus = SocketConnectionStatus.disconnected;
  SocketConnectionStatus get currentStatus => _currentStatus;

  WebSocketService({required String serverUrl}) : _serverUrl = serverUrl;

  dynamic _normalizeSocketValue(dynamic value) {
    if (value is Map) {
      return value.map(
        (key, nestedValue) =>
            MapEntry(key.toString(), _normalizeSocketValue(nestedValue)),
      );
    }
    if (value is List) {
      return value.map(_normalizeSocketValue).toList();
    }
    return value;
  }

  Map<String, dynamic>? _normalizeSocketMap(dynamic data) {
    final normalized = _normalizeSocketValue(data);
    if (normalized is Map<String, dynamic>) {
      return normalized;
    }
    return null;
  }

  /// Подключиться к WebSocket серверу.
  /// [serverUrl] — если передан, переопределяет URL, указанный при создании сервиса.
  /// Это позволяет использовать актуальный хост (EU или HK) в момент соединения,
  /// даже если режим прокси был изменён после создания провайдера.
  Future<void> connect(String token, {String? serverUrl}) async {
    // Защита от повторных connect() вызовов (часто случается при rebuild'ах провайдеров):
    // - если уже подключены — ничего не делаем
    // - если уже в процессе подключения/реконнекта — не создаём новый socket (иначе утечки и дубликаты событий)
    if (_socket != null) {
      if (_socket!.connected == true) return;
      if (_currentStatus == SocketConnectionStatus.connecting ||
          _currentStatus == SocketConnectionStatus.reconnecting) {
        return;
      }
      // Если socket есть, но он не подключён и мы не "connecting/reconnecting",
      // то это "подвисшее" состояние — чистим и создаём новый.
      await disconnect();
    }

    _token = token;
    final url = serverUrl ?? _serverUrl;
    _lastConnectedUrl = url;
    _updateStatus(SocketConnectionStatus.connecting);

    _socket = IO.io(
      url,
      IO.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .enableAutoConnect()
          .enableReconnection()
          .setReconnectionDelay(2000)
          .setReconnectionDelayMax(30000)
          .setReconnectionAttempts(999999999)
          .setAuth({'token': token})
          .build(),
    );

    _setupListeners();
    _startHeartbeat();
  }

  void _setupListeners() {
    if (_socket == null) return;

    _socket!.onConnect((_) {
      print('WebSocket connected');
      final wasDisconnected = _wasConnected;
      _wasConnected = true;
      _updateStatus(SocketConnectionStatus.connected);
      // If we were previously connected and got disconnected, fire reconnect
      // Only if disconnected for more than 5 seconds (avoids Bluetooth scanner reconnects)
      if (wasDisconnected) {
        final disconnectDuration = _disconnectedAt != null
            ? DateTime.now().difference(_disconnectedAt!)
            : const Duration(seconds: 999);
        _disconnectedAt = null;
        if (disconnectDuration.inSeconds >= 5) {
          print(
            'WebSocket reconnected after ${disconnectDuration.inSeconds}s — triggering full refetch',
          );
          if (!_reconnectedController.isClosed) {
            _reconnectedController.add(null);
          }
        } else {
          print(
            'WebSocket reconnected after ${disconnectDuration.inMilliseconds}ms — skipping refetch (too short)',
          );
        }
      }
    });

    _socket!.onDisconnect((_) {
      print('WebSocket disconnected');
      _disconnectedAt = DateTime.now();
      _updateStatus(SocketConnectionStatus.disconnected);
    });

    _socket!.onReconnect((_) {
      print('WebSocket reconnected');
      _updateStatus(SocketConnectionStatus.connected);
      // Fire reconnect event only if disconnected long enough (>= 5s)
      final disconnectDuration = _disconnectedAt != null
          ? DateTime.now().difference(_disconnectedAt!)
          : const Duration(seconds: 999);
      _disconnectedAt = null;
      if (disconnectDuration.inSeconds >= 5) {
        print(
          'WebSocket onReconnect after ${disconnectDuration.inSeconds}s — triggering full refetch',
        );
        if (!_reconnectedController.isClosed) {
          _reconnectedController.add(null);
        }
      } else {
        print(
          'WebSocket onReconnect after ${disconnectDuration.inMilliseconds}ms — skipping refetch (too short)',
        );
      }
    });

    _socket!.on('reconnecting', (_) {
      print('WebSocket reconnecting...');
      _updateStatus(SocketConnectionStatus.reconnecting);
    });

    _socket!.onConnectError((error) {
      print('WebSocket connection error: $error');
    });

    _socket!.onError((error) {
      print('WebSocket error: $error');
    });

    _socket!.on('reconnect_failed', (_) {
      print('[WS] All reconnection attempts exhausted — force reconnecting');
      _forceReconnect();
    });

    _socket!.on('reconnect_error', (error) {
      print('[WS] Reconnect error: $error');
    });

    // Chat events
    _socket!.on('new_message', (data) {
      final normalized = _normalizeSocketMap(data);
      if (normalized != null) {
        _messageController.add(normalized);
      }
    });

    _socket!.on('conversation_updated', (data) {
      final normalized = _normalizeSocketMap(data);
      if (normalized != null) {
        _conversationUpdateController.add(normalized);
      }
    });

    _socket!.on('user_typing', (data) {
      final normalized = _normalizeSocketMap(data);
      if (normalized != null) {
        _typingController.add(normalized);
      }
    });

    _socket!.on('user_presence', (data) {
      final normalized = _normalizeSocketMap(data);
      if (normalized != null) {
        _presenceController.add(normalized);
      }
    });

    _socket!.on('messages_read', (data) {
      final normalized = _normalizeSocketMap(data);
      if (normalized != null) {
        if (!_messagesReadController.isClosed) {
          _messagesReadController.add(normalized);
        }
      }
    });

    _socket!.on('message_edited', (data) {
      final normalized = _normalizeSocketMap(data);
      if (normalized != null) {
        _messageEditedController.add(normalized);
      }
    });

    _socket!.on('message_deleted', (data) {
      final normalized = _normalizeSocketMap(data);
      if (normalized != null) {
        _messageDeletedController.add(normalized);
      }
    });

    // Data change events (real-time sync)
    _socket!.on('data_changed', (data) {
      final normalized = _normalizeSocketMap(data);
      if (normalized != null) {
        _dataChangedController.add(normalized);
      }
    });

    // Warehouse task presence events
    _socket!.on('task_presence', (data) {
      final normalized = _normalizeSocketMap(data);
      if (normalized != null) {
        _taskPresenceController.add(normalized);
      }
    });

    _socket!.on('task_presence_disconnect', (data) {
      final normalized = _normalizeSocketMap(data);
      if (normalized != null) {
        _taskPresenceDisconnectController.add(normalized);
      }
    });

    // Delta events for warehouse workers (real-time task/assembly updates)
    _socket!.on('task_delta', (data) {
      final normalized = _normalizeSocketMap(data);
      if (normalized != null) {
        _taskDeltaController.add(normalized);
      }
    });

    _socket!.on('assembly_delta', (data) {
      final normalized = _normalizeSocketMap(data);
      if (normalized != null) {
        _assemblyDeltaController.add(normalized);
      }
    });

    _socket!.on('employee_chat_presence', (data) {
      final normalized = _normalizeSocketMap(data);
      if (normalized != null) {
        _employeeChatPresenceController.add(normalized);
      }
    });

    // === Delta Sync events (universal) ===
    _socket!.on('delta', (data) {
      final normalized = _normalizeSocketMap(data);
      if (normalized != null) {
        try {
          final event = DeltaEvent.fromJson(normalized);
          if (!_deltaController.isClosed) {
            _deltaController.add(event);
          }
        } catch (e) {
          print('WebSocket delta parse error: $e');
        }
      }
    });

    _socket!.on('delta_batch', (data) {
      final normalized = _normalizeSocketMap(data);
      if (normalized != null) {
        try {
          final batch = DeltaBatchEvent.fromJson(normalized);
          if (!_deltaBatchController.isClosed) {
            _deltaBatchController.add(batch);
          }
        } catch (e) {
          print('WebSocket delta_batch parse error: $e');
        }
      }
    });
  }

  /// Запуск периодического heartbeat для обнаружения мёртвых соединений
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) => _checkHealth());
  }

  /// Проверка здоровья соединения
  void _checkHealth() {
    if (_isForceReconnecting) return;

    final socketConnected = _socket?.connected ?? false;

    // Статус connected, но сокет на самом деле мёртв
    if (!socketConnected &&
        _currentStatus == SocketConnectionStatus.connected) {
      print('[WS Health] Socket dead — status was connected, correcting');
      _disconnectedAt ??= DateTime.now();
      _updateStatus(SocketConnectionStatus.disconnected);
    }

    // Статус disconnected, но сокет на самом деле жив (маловероятно, но защита)
    if (socketConnected && _currentStatus != SocketConnectionStatus.connected) {
      print(
        '[WS Health] Socket alive but status was ${_currentStatus.name}, correcting',
      );
      _updateStatus(SocketConnectionStatus.connected);
      return;
    }

    // Слишком долго без соединения — пересоздаём сокет полностью
    if (!socketConnected && _disconnectedAt != null && _token != null) {
      final disconnectedFor = DateTime.now().difference(_disconnectedAt!);
      if (disconnectedFor >= _forceReconnectAfter) {
        print(
          '[WS Health] Disconnected for ${disconnectedFor.inSeconds}s — force reconnecting',
        );
        _forceReconnect();
      }
    }
  }

  /// Полное пересоздание сокета (когда socket.io reconnect зависает).
  /// Приватная реализация — вызывается из внутренних health-check и
  /// reconnect_failed handler. Для внешнего использования см. [forceReconnect].
  Future<void> _forceReconnect() async {
    if (_isForceReconnecting) return;
    if (_currentStatus == SocketConnectionStatus.connecting) return;
    _isForceReconnecting = true;

    try {
      final token = _token;
      final url = _lastConnectedUrl;
      if (token == null) return;

      print('[WS] Force reconnect: destroying old socket');
      _heartbeatTimer?.cancel();
      _socket?.disconnect();
      _socket?.dispose();
      _socket = null;
      // НЕ сбрасываем _wasConnected и _disconnectedAt,
      // чтобы onConnect при новом подключении вызвал reconnected stream
      _updateStatus(SocketConnectionStatus.disconnected);

      _isForceReconnecting = false;
      await connect(token, serverUrl: url);
    } catch (e) {
      print('[WS] Force reconnect error: $e');
      _isForceReconnecting = false;
      // Heartbeat перезапустится при следующем connect()
    }
  }

  /// Публичный API для принудительного пересоздания сокета —
  /// вызывать при `AppLifecycleState.resumed` на iOS, где системные
  /// TCP-соединения умирают в background, но dart:io этого не знает.
  /// После успешного reconnect стрим [reconnected] эмитит событие,
  /// что триггерит `loadTasks`/`loadAssemblies` в провайдерах.
  Future<void> forceReconnect() => _forceReconnect();

  /// Присоединиться к комнате разговора
  void joinConversation(int conversationId) {
    _socket?.emit('join_conversation', conversationId);
  }

  /// Покинуть комнату разговора
  void leaveConversation(int conversationId) {
    _socket?.emit('leave_conversation', conversationId);
  }

  /// Отправить индикатор набора текста
  void sendTyping(int conversationId, bool isTyping) {
    _socket?.emit('typing', {
      'conversationId': conversationId,
      'isTyping': isTyping,
    });
  }

  /// Отправить уведомление о прочтении сообщения
  void sendMessageRead(int conversationId, int messageId) {
    _socket?.emit('message_read', {
      'conversationId': conversationId,
      'messageId': messageId,
    });
  }

  /// Отправить статус присутствия
  void sendPresence(int conversationId, bool isOpen) {
    _socket?.emit('presence', {
      'conversationId': conversationId,
      'isOpen': isOpen,
    });
  }

  /// Отправить фокус на задаче/сборке (warehouse presence)
  void sendTaskFocus(String taskId) {
    _socket?.emit('task_focus', {'taskId': taskId});
  }

  /// Отправить blur с задачи/сборки (warehouse presence)
  void sendTaskBlur(String taskId) {
    _socket?.emit('task_blur', {'taskId': taskId});
  }

  void _updateStatus(SocketConnectionStatus status) {
    _currentStatus = status;
    if (!_connectionStatusController.isClosed) {
      _connectionStatusController.add(status);
    }
  }

  /// Отключиться от WebSocket сервера
  Future<void> disconnect() async {
    _heartbeatTimer?.cancel();
    _isForceReconnecting = false;
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _wasConnected = false;
    _disconnectedAt = null;
    _updateStatus(SocketConnectionStatus.disconnected);
  }

  /// Освободить ресурсы
  void dispose() {
    _heartbeatTimer?.cancel();
    disconnect();
    _connectionStatusController.close();
    _messageController.close();
    _conversationUpdateController.close();
    _typingController.close();
    _presenceController.close();
    _messageEditedController.close();
    _messageDeletedController.close();
    _messagesReadController.close();
    _dataChangedController.close();
    _taskPresenceController.close();
    _taskPresenceDisconnectController.close();
    _taskDeltaController.close();
    _assemblyDeltaController.close();
    _employeeChatPresenceController.close();
    _deltaController.close();
    _deltaBatchController.close();
    _reconnectedController.close();
  }

  /// Проверить статус подключения
  bool get isConnected => _currentStatus == SocketConnectionStatus.connected;
}
