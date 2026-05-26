import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as IO;

import '../models/common/delta_event.dart';

/// Статус подключения WebSocket
enum SocketConnectionStatus {
  disconnected,
  connecting,
  connected,
  reconnecting,
}

/// Диагностическое событие WebSocket для клиентских логов.
class SocketDiagnosticEvent {
  const SocketDiagnosticEvent({
    required this.type,
    required this.level,
    required this.message,
    this.status,
    this.data,
  });

  final String type;
  final String level;
  final String message;
  final SocketConnectionStatus? status;
  final Map<String, dynamic>? data;

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'level': level,
      'message': message,
      if (status != null) 'status': status!.name,
      if (data != null && data!.isNotEmpty) 'data': data,
    };
  }
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

  final _diagnosticController =
      StreamController<SocketDiagnosticEvent>.broadcast();
  Stream<SocketDiagnosticEvent> get diagnostics => _diagnosticController.stream;

  bool _wasConnected = false;
  DateTime? _disconnectedAt;
  DateTime? _connectStateStartedAt;
  String? _lastConnectionError;

  // Heartbeat & force reconnect
  String? _lastConnectedUrl;
  Timer? _heartbeatTimer;
  Timer? _connectWatchdogTimer;
  bool _isForceReconnecting = false;
  static const _heartbeatInterval = Duration(seconds: 30);
  static const _forceReconnectAfter = Duration(seconds: 120);
  static const _connectTimeout = Duration(seconds: 20);
  static const _staleConnectingAfter = Duration(seconds: 25);

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

  void _emitDiagnostic({
    required String type,
    required String level,
    required String message,
    Map<String, dynamic>? data,
  }) {
    if (_diagnosticController.isClosed) return;
    _diagnosticController.add(
      SocketDiagnosticEvent(
        type: type,
        level: level,
        message: message,
        status: _currentStatus,
        data: {
          if (_lastConnectedUrl != null) 'serverUrl': _lastConnectedUrl,
          if (_lastConnectionError != null)
            'lastConnectionError': _lastConnectionError,
          if (_connectStateStartedAt != null)
            'connectStateAgeMs': DateTime.now()
                .difference(_connectStateStartedAt!)
                .inMilliseconds,
          if (data != null) ...data,
        },
      ),
    );
  }

  void _emitReconnectedIfDisconnectedLongEnough(String source) {
    final disconnectedAt = _disconnectedAt;
    _disconnectedAt = null;

    if (disconnectedAt == null) {
      print(
        'WebSocket $source without disconnect timestamp — skipping refetch',
      );
      return;
    }

    final disconnectDuration = DateTime.now().difference(disconnectedAt);
    if (disconnectDuration.inSeconds >= 5) {
      print(
        'WebSocket $source after ${disconnectDuration.inSeconds}s — triggering full refetch',
      );
      if (!_reconnectedController.isClosed) {
        _reconnectedController.add(null);
      }
    } else {
      print(
        'WebSocket $source after ${disconnectDuration.inMilliseconds}ms — skipping refetch (too short)',
      );
    }
  }

  bool _isConnectingState(SocketConnectionStatus status) {
    return status == SocketConnectionStatus.connecting ||
        status == SocketConnectionStatus.reconnecting;
  }

  bool _isConnectStateStale() {
    if (!_isConnectingState(_currentStatus)) return false;
    final startedAt = _connectStateStartedAt;
    if (startedAt == null) return true;
    return DateTime.now().difference(startedAt) >= _staleConnectingAfter;
  }

  void _startConnectWatchdog() {
    _connectWatchdogTimer?.cancel();
    _connectWatchdogTimer = Timer(_connectTimeout, () {
      if (_socket?.connected == true) return;
      if (!_isConnectingState(_currentStatus)) return;
      _emitDiagnostic(
        type: 'connect_timeout',
        level: 'warning',
        message: 'WebSocket connection attempt timed out',
        data: {'timeoutMs': _connectTimeout.inMilliseconds},
      );
      unawaited(_forceReconnect(reason: 'connect_timeout'));
    });
  }

  void _destroySocketForReconnect(String reason) {
    _connectWatchdogTimer?.cancel();
    _heartbeatTimer?.cancel();
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _disconnectedAt ??= DateTime.now();
    _updateStatus(SocketConnectionStatus.disconnected);
    _emitDiagnostic(
      type: 'socket_destroyed_for_reconnect',
      level: 'warning',
      message: 'WebSocket socket destroyed before reconnect',
      data: {'reason': reason},
    );
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
        if (!_isConnectStateStale()) return;
        print('[WS] Stale ${_currentStatus.name} state — rebuilding socket');
        _emitDiagnostic(
          type: 'stale_connect_state',
          level: 'warning',
          message: 'WebSocket connect state is stale',
          data: {'status': _currentStatus.name},
        );
        _destroySocketForReconnect('stale_${_currentStatus.name}');
      } else {
        // Если socket есть, но он не подключён и мы не "connecting/reconnecting",
        // то это "подвисшее" состояние — чистим и создаём новый.
        await disconnect();
      }
    }

    _token = token;
    final url = serverUrl ?? _serverUrl;
    _lastConnectedUrl = url;
    _lastConnectionError = null;
    _updateStatus(SocketConnectionStatus.connecting);
    _emitDiagnostic(
      type: 'connect_start',
      level: 'info',
      message: 'WebSocket connection attempt started',
      data: {'serverUrl': url},
    );

    _socket = IO.io(
      url,
      IO.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .enableAutoConnect()
          .enableReconnection()
          .setReconnectionDelay(2000)
          .setReconnectionDelayMax(30000)
          .setReconnectionAttempts(999999999)
          .setTimeout(_connectTimeout.inMilliseconds)
          .setAuth({'token': token})
          .build(),
    );

    _setupListeners();
    _startConnectWatchdog();
    _startHeartbeat();
  }

  void _setupListeners() {
    if (_socket == null) return;

    _socket!.onConnect((_) {
      print('WebSocket connected');
      _connectWatchdogTimer?.cancel();
      _lastConnectionError = null;
      final wasDisconnected = _wasConnected;
      _wasConnected = true;
      _updateStatus(SocketConnectionStatus.connected);
      _emitDiagnostic(
        type: 'connected',
        level: 'info',
        message: 'WebSocket connected',
      );
      // If we were previously connected and got disconnected, fire reconnect
      // Only if disconnected for more than 5 seconds (avoids Bluetooth scanner reconnects)
      if (wasDisconnected) {
        _emitReconnectedIfDisconnectedLongEnough('reconnected');
      }
    });

    _socket!.onDisconnect((reason) {
      print('WebSocket disconnected');
      _connectWatchdogTimer?.cancel();
      _disconnectedAt = DateTime.now();
      _updateStatus(SocketConnectionStatus.disconnected);
      _emitDiagnostic(
        type: 'disconnected',
        level: 'warning',
        message: 'WebSocket disconnected',
        data: {'reason': reason?.toString() ?? 'unknown'},
      );
    });

    _socket!.onReconnect((_) {
      print('WebSocket reconnected');
      _connectWatchdogTimer?.cancel();
      _lastConnectionError = null;
      _updateStatus(SocketConnectionStatus.connected);
      _emitDiagnostic(
        type: 'reconnected',
        level: 'warning',
        message: 'WebSocket reconnected',
      );
      // Fire reconnect event only if disconnected long enough (>= 5s)
      _emitReconnectedIfDisconnectedLongEnough('onReconnect');
    });

    _socket!.on('reconnecting', (attempt) {
      print('WebSocket reconnecting...');
      _updateStatus(SocketConnectionStatus.reconnecting);
      _startConnectWatchdog();
      _emitDiagnostic(
        type: 'reconnecting',
        level: 'warning',
        message: 'WebSocket reconnecting',
        data: {'attempt': attempt?.toString() ?? 'unknown'},
      );
    });

    _socket!.onConnectError((error) {
      print('WebSocket connection error: $error');
      _lastConnectionError = error?.toString();
      _emitDiagnostic(
        type: 'connect_error',
        level: 'warning',
        message: 'WebSocket connection error',
        data: {'error': error?.toString() ?? 'unknown'},
      );
    });

    _socket!.onError((error) {
      print('WebSocket error: $error');
      _lastConnectionError = error?.toString();
      _emitDiagnostic(
        type: 'error',
        level: 'warning',
        message: 'WebSocket error',
        data: {'error': error?.toString() ?? 'unknown'},
      );
    });

    _socket!.on('reconnect_failed', (_) {
      print('[WS] All reconnection attempts exhausted — force reconnecting');
      _forceReconnect(reason: 'reconnect_failed');
    });

    _socket!.on('reconnect_error', (error) {
      print('[WS] Reconnect error: $error');
      _lastConnectionError = error?.toString();
      _emitDiagnostic(
        type: 'reconnect_error',
        level: 'warning',
        message: 'WebSocket reconnect error',
        data: {'error': error?.toString() ?? 'unknown'},
      );
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

    if (!socketConnected && _isConnectStateStale() && _token != null) {
      print(
        '[WS Health] ${_currentStatus.name} for too long — force reconnecting',
      );
      _emitDiagnostic(
        type: 'stale_connect_healthcheck',
        level: 'warning',
        message: 'WebSocket connect/reconnect state is stale',
        data: {'status': _currentStatus.name},
      );
      _forceReconnect(reason: 'stale_${_currentStatus.name}_healthcheck');
      return;
    }

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
        _forceReconnect(reason: 'disconnected_healthcheck');
      }
    }
  }

  /// Полное пересоздание сокета (когда socket.io reconnect зависает).
  /// Приватная реализация — вызывается из внутренних health-check и
  /// reconnect_failed handler. Для внешнего использования см. [forceReconnect].
  Future<void> _forceReconnect({String reason = 'manual'}) async {
    if (_isForceReconnecting) return;
    _isForceReconnecting = true;

    try {
      final token = _token;
      final url = _lastConnectedUrl;
      if (token == null) {
        _isForceReconnecting = false;
        return;
      }

      print('[WS] Force reconnect: destroying old socket (reason=$reason)');
      _emitDiagnostic(
        type: 'force_reconnect_start',
        level: 'warning',
        message: 'WebSocket force reconnect started',
        data: {'reason': reason},
      );
      _destroySocketForReconnect(reason);

      _isForceReconnecting = false;
      await connect(token, serverUrl: url);
    } catch (e) {
      print('[WS] Force reconnect error: $e');
      _lastConnectionError = e.toString();
      _emitDiagnostic(
        type: 'force_reconnect_error',
        level: 'warning',
        message: 'WebSocket force reconnect failed',
        data: {'reason': reason, 'error': e.toString()},
      );
      _isForceReconnecting = false;
      // Heartbeat перезапустится при следующем connect()
    }
  }

  /// Публичный API для принудительного пересоздания сокета —
  /// вызывать при `AppLifecycleState.resumed` на iOS, где системные
  /// TCP-соединения умирают в background, но dart:io этого не знает.
  /// После успешного reconnect стрим [reconnected] эмитит событие,
  /// что триггерит `loadTasks`/`loadAssemblies` в провайдерах.
  Future<void> forceReconnect({String reason = 'manual'}) =>
      _forceReconnect(reason: reason);

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
    if (_currentStatus != status) {
      _connectStateStartedAt = _isConnectingState(status)
          ? DateTime.now()
          : null;
    } else if (_isConnectingState(status)) {
      _connectStateStartedAt ??= DateTime.now();
    }
    _currentStatus = status;
    if (!_connectionStatusController.isClosed) {
      _connectionStatusController.add(status);
    }
  }

  /// Отключиться от WebSocket сервера
  Future<void> disconnect() async {
    _connectWatchdogTimer?.cancel();
    _heartbeatTimer?.cancel();
    _isForceReconnecting = false;
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _wasConnected = false;
    _disconnectedAt = null;
    _connectStateStartedAt = null;
    _lastConnectionError = null;
    _updateStatus(SocketConnectionStatus.disconnected);
  }

  /// Освободить ресурсы
  void dispose() {
    _connectWatchdogTimer?.cancel();
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
    _diagnosticController.close();
  }

  /// Проверить статус подключения
  bool get isConnected => _currentStatus == SocketConnectionStatus.connected;
}
