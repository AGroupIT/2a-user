// TODO: Update to ShowcaseView.get() API when showcaseview 6.0.0 is released
// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:showcaseview/showcaseview.dart';

import '../core/network/api_client.dart';
import '../core/services/app_language_service.dart';
import '../core/services/chat_presence_service.dart';
import '../core/services/showcase_service.dart';
import '../core/services/websocket_provider.dart';
import '../core/ui/app_colors.dart';
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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Инициализируем обработчик push уведомлений
    WidgetsBinding.instance.addPostFrameCallback((_) {
      initializePushNotificationsHandler(ref);
      _setupUnauthorizedHandler();
      // Инициализируем WebSocket подключение
      ref.read(webSocketAutoConnectProvider);
    });
  }
  
  /// Настройка обработчика 401 ошибки
  void _setupUnauthorizedHandler() {
    final apiClient = ref.read(apiClientProvider);
    apiClient.setOnUnauthorizedCallback(() {
      // Вызываем logout и редирект на логин
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
    
    // Глобальный обработчик жизненного цикла для chat presence
    if (state == AppLifecycleState.paused || 
        state == AppLifecycleState.detached) {
      // Приложение ушло в фон или закрывается - очищаем все присутствия
      ref.read(chatPresenceServiceProvider).onAppPaused();
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    // Загружаем брендовые цвета из профиля агента
    final brandColors = ref.watch(brandColorsProvider);
    final language = ref.watch(appLanguageProvider);
    
    return MaterialApp.router(
      title: 'Карго',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ru'),
        Locale('zh'),
      ],
      locale: language.locale,
      theme: AppTheme.lightWithColors(brandColors),
      routerConfig: router,
      builder: (context, child) => _AppShowcaseHost(child: child),
    );
  }
}

/// Единственный ShowCaseWidget для всего приложения.
///
/// Все экраны имеют общий scope, что устраняет конфликт currentScope
/// в синглтоне ShowcaseService (пакета) при нескольких живых ShowCaseWidget.
class _AppShowcaseHost extends ConsumerWidget {
  final Widget? child;

  const _AppShowcaseHost({this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ShowCaseWidget(
      blurValue: 1,
      enableAutoScroll: false,
      onFinish: () {
        // Помечаем блоки, показанные в только что завершённом туре
        final blocks = ref.read(showcasePendingBlocksProvider);
        if (blocks.isNotEmpty) {
          final svc = ref.read(showcaseServiceProvider);
          for (final block in blocks) {
            svc.markBlockAsSeen(block);
            ref.invalidate(showcaseBlockProvider(block));
          }
          ref.read(showcasePendingBlocksProvider.notifier).clear();
        }
      },
      globalFloatingActionWidget: (ctx) => FloatingActionWidget(
        right: 16,
        top: MediaQuery.of(ctx).padding.top + 12,
        child: GestureDetector(
          onTap: () {
            ShowCaseWidget.of(ctx).dismiss();
            ref.read(showcaseServiceProvider).markAllBlocksSeen();
            for (final block in ShowcaseBlock.values) {
              ref.invalidate(showcaseBlockProvider(block));
            }
            ref.read(showcasePendingBlocksProvider.notifier).clear();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Пропустить обучение',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
      builder: (_) => child ?? const SizedBox.shrink(),
    );
  }
}
