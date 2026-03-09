import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:twoalogistic_shared/twoalogistic_shared.dart';
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
/// Использует ApiClient.getToken() — он корректно читает из SecureStorage на мобильных
/// и из SharedPreferences/localStorage на web/desktop.
final webSocketAutoConnectProvider = Provider<void>((ref) {
  final service = ref.watch(webSocketServiceProvider);
  final apiClient = ref.watch(apiClientProvider);

  Future.microtask(() async {
    try {
      final token = await apiClient.getToken();
      if (token != null && token.isNotEmpty) {
        await service.connect(token);
      }
    } catch (e) {
      // Ошибка подключения WebSocket не критична, будет fallback на polling
    }
  });
});
