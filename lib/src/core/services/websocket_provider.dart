import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:twoalogistic_shared/twoalogistic_shared.dart';
import '../../features/auth/data/auth_provider.dart';
import '../network/api_client.dart';
import '../network/api_config.dart';

final webSocketServiceProvider = Provider<WebSocketService>((ref) {
  // WebSocket is proxied through nginx at /socket.io/ path
  final wsUrl = ApiConfig.baseUrl.replaceAll('/api', '');

  final service = WebSocketService(
    serverUrl: wsUrl,
  );

  ref.onDispose(() {
    service.dispose();
  });

  return service;
});

final webSocketConnectionStatusProvider = StreamProvider<SocketConnectionStatus>((ref) {
  final service = ref.watch(webSocketServiceProvider);
  return service.connectionStatus;
});

/// Провайдер для автоматического подключения WebSocket при наличии токена.
/// Слушает authProvider — подключается после логина, отключается при логауте.
final webSocketAutoConnectProvider = Provider<void>((ref) {
  final authState = ref.watch(authProvider);
  final service = ref.watch(webSocketServiceProvider);
  final apiClient = ref.read(apiClientProvider);

  debugPrint('[WS] Provider triggered: isLoggedIn=${authState.isLoggedIn}, isLoading=${authState.isLoading}');

  if (authState.isLoggedIn && !authState.isLoading) {
    // Skip if already connected or connecting
    if (service.currentStatus == SocketConnectionStatus.connected ||
        service.currentStatus == SocketConnectionStatus.connecting) {
      return;
    }
    Future.microtask(() async {
      try {
        // Double-check after microtask
        if (service.currentStatus == SocketConnectionStatus.connected) return;
        final token = await apiClient.getToken();
        if (token != null && token.isNotEmpty) {
          await service.connect(token);
          debugPrint('[WS] Connect called successfully');
        }
      } catch (e) {
        debugPrint('[WS] Connection error: $e');
      }
    });
  } else {
    // Отключаемся при логауте
    if (service.currentStatus != SocketConnectionStatus.disconnected) {
      debugPrint('[WS] Auth lost — disconnecting');
      service.disconnect();
    }
  }
});
