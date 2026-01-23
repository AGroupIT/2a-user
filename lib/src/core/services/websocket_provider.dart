import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:twoalogistic_shared/twoalogistic_shared.dart';
import '../network/api_config.dart';
import '../persistence/shared_preferences_provider.dart';

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

/// Провайдер для автоматического подключения WebSocket при наличии токена
final webSocketAutoConnectProvider = Provider<void>((ref) {
  final service = ref.watch(webSocketServiceProvider);
  final prefs = ref.watch(sharedPreferencesProvider);

  // Получаем токен из SharedPreferences
  final token = prefs.getString('token');

  if (token != null && token.isNotEmpty) {
    // Подключаемся асинхронно
    Future.microtask(() async {
      try {
        await service.connect(token);
      } catch (e) {
        // Ошибка подключения WebSocket не критична, будет fallback на polling
      }
    });
  }
});
