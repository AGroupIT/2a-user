import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/network/api_client.dart';
import '../core/network/api_config.dart';
import '../core/services/app_language_service.dart';
import '../core/services/chat_presence_service.dart';
import '../core/services/delta_sync_provider.dart';
import '../core/services/websocket_provider.dart';
import '../core/ui/app_colors.dart';
import '../core/ui/demo_mode_banner.dart';
import '../features/auth/data/auth_provider.dart';
import '../features/notifications/application/notifications_controller.dart';
import 'router.dart';
import 'theme/app_theme.dart';

class App extends ConsumerStatefulWidget {
  const App({super.key});

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> with WidgetsBindingObserver {
  DateTime? _pausedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Инициализируем обработчик push уведомлений
    WidgetsBinding.instance.addPostFrameCallback((_) {
      initializePushNotificationsHandler(ref);
      _setupUnauthorizedHandler();
    });
  }

  /// Настройка обработчика 401 ошибки
  void _setupUnauthorizedHandler() {
    final apiClient = ref.read(apiClientProvider);
    apiClient.setOnUnauthorizedCallback(() {
      ref.read(authProvider.notifier).logout();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      ref.read(chatPresenceServiceProvider).onAppPaused();
      _pausedAt ??= DateTime.now();
    } else if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.inactive) {
      _pausedAt ??= DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      // iOS-фикс: в background TCP-сокеты (HTTP keepalive и WebSocket)
      // часто становятся мертвы, но dart:io этого не знает и пишет в
      // зомби-соединение до receive timeout → у пользователя висит
      // spinner и UI не обновляется. Принудительно пересоздаём сокет
      // только если пауза была больше 5 секунд (короткие паузы —
      // клавиатура, notification center — сокет пережить может).
      final pausedAt = _pausedAt;
      _pausedAt = null;
      if (pausedAt == null) return;
      final pausedFor = DateTime.now().difference(pausedAt);
      if (pausedFor.inSeconds < 5) return;
      debugPrint(
        '[App] Resumed after ${pausedFor.inSeconds}s — force WS reconnect',
      );
      ref.read(apiClientProvider).resetConnections();
      ref.read(webSocketServiceProvider).forceReconnect();
      Future.microtask(() {
        if (!mounted) return;
        if (!ref.read(authProvider).isLoggedIn) return;
        invalidateClientDataProviders(ref);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // WebSocket + delta sync: watch ensures re-trigger on auth state change
    ref.watch(webSocketAutoConnectProvider);
    ref.watch(deltaSyncProvider);

    final router = ref.watch(routerProvider);
    final brandColors = ref.watch(brandColorsProvider);
    final language = ref.watch(appLanguageProvider);

    // 2a-user всегда работает напрямую с основным backend.
    // HK-прокси используется только в 2a-admin для сотрудников из Китая.
    ApiConfig.setChineseMode(false);

    return MaterialApp.router(
      title: 'Карго',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ru'), Locale('zh')],
      locale: language.locale,
      theme: AppTheme.lightWithColors(brandColors),
      routerConfig: router,
      builder: (context, child) => Stack(
        children: [child ?? const SizedBox.shrink(), const DemoModeBanner()],
      ),
    );
  }
}
