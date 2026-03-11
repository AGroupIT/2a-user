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
    Future.microtask(() async {
      try {
        final token = await apiClient.getToken();
        debugPrint('[WS] Token: ${token != null ? "${token.substring(0, 20)}..." : "NULL"}');
        debugPrint('[WS] URL: ${ApiConfig.baseUrl.replaceAll('/api', '')}');
        if (token != null && token.isNotEmpty) {
          await service.connect(token);
          debugPrint('[WS] Connect called successfully');
        } else {
          debugPrint('[WS] No token — skipping WebSocket connect');
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
