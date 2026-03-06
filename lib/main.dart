import 'dart:io' if (dart.library.html) 'src/core/platform/platform_stub.dart';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';

import 'src/app/app.dart';
import 'src/core/config/sentry_config.dart';
import 'src/core/persistence/shared_preferences_provider.dart';
import 'src/core/services/analytics_service.dart';
import 'src/core/services/push_notification_service.dart';

/// Запрос разрешения на отслеживание (ATT) для iOS
Future<void> _requestTrackingPermission() async {
  if (kIsWeb) return; // Web не поддерживает ATT
  if (!Platform.isIOS) return;

  try {
    final status = await AppTrackingTransparency.trackingAuthorizationStatus;
    if (status == TrackingStatus.notDetermined) {
      // Небольшая задержка для корректного отображения диалога на iOS
      await Future.delayed(const Duration(milliseconds: 500));
      await AppTrackingTransparency.requestTrackingAuthorization();
    }
  } catch (e) {
    debugPrint('ATT: Ошибка запроса разрешения - $e');
  }
}

/// Проверка: является ли ошибка известным багом showcaseview 5.x.
///
/// Баг проявляется в двух сценариях:
/// 1. iOS: stale BuildContext в post-frame callback showcaseview → MediaQuery crash
///    (стек содержит 'showcaseview')
/// 2. Android: Showcase-виджет внутри ListView.builder → createChild crash
///    (стек содержит 'SliverMultiBoxAdaptorElement', showcaseview не виден)
///
/// В обоих случаях exception.toString() содержит `DiagnosticsProperty<void>`.
/// `DiagnosticsProperty<void>` никогда не должен быть исключением в рабочем коде —
/// это всегда признак данного конкретного бага.
bool _isKnownShowcaseBug(FlutterErrorDetails details) {
  final msg = details.exception.toString();
  // Все варианты бага дают 'DiagnosticsProperty' в тексте исключения.
  // В рабочем Flutter-приложении этого никогда не должно быть в production.
  if (!msg.contains('DiagnosticsProperty')) return false;

  final stack = details.stack?.toString() ?? '';
  // iOS: showcaseview явно в стеке (ShowcaseService.getScope / _initRootWidget)
  if (stack.contains('showcaseview')) return true;
  // Android: Showcase внутри ListView.builder (lazy createChild)
  if (stack.contains('SliverMultiBoxAdaptorElement')) return true;
  // Android: tap на InkWell → AutomaticKeepAlive → NotificationListener
  if (stack.contains('_NotificationElement.onNotification')) return true;
  // Редкий вариант: ошибка попадает в цепочку загрузки изображений
  if (stack.contains('FileImage._loadAsync')) return true;

  return false;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Перехватываем известный баг showcaseview 5.x: stale BuildContext → MediaQuery.sizeOf crash
  final originalOnError = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    if (_isKnownShowcaseBug(details)) {
      debugPrint('[showcaseview] Suppressed known DiagnosticsProperty crash: ${details.exception}');
      return;
    }
    originalOnError?.call(details);
  };

  // Перехватываем uncaught exceptions на уровне платформы (путь через layout callbacks)
  PlatformDispatcher.instance.onError = (error, stack) {
    if (error.toString().contains('DiagnosticsProperty')) {
      debugPrint('[showcaseview] Suppressed platform-level DiagnosticsProperty crash: $error');
      return true; // handled — не крашим приложение
    }
    return false; // не наша ошибка — пусть падает стандартно
  };

  // Инициализация Firebase для push-уведомлений
  await PushNotificationService.initializeFirebase();

  // Запрос разрешения на отслеживание (ATT) - ОБЯЗАТЕЛЬНО до AppMetrica
  await _requestTrackingPermission();

  // Инициализация AppMetrica для аналитики
  await AnalyticsService.initialize();

  // Инициализация SharedPreferences для showcase
  final sharedPreferences = await SharedPreferences.getInstance();

  // Инициализация Sentry для error tracking
  await SentryFlutter.init(
    (options) {
      options.dsn = SentryConfig.dsn;
      options.environment = SentryConfig.environment;
      options.release = SentryConfig.release;
      options.dist = SentryConfig.appName;
      options.sampleRate = SentryConfig.sampleRate;
      options.tracesSampleRate = SentryConfig.tracesSampleRate;
      options.maxBreadcrumbs = SentryConfig.maxBreadcrumbs;
      options.sendDefaultPii = false; // Не отправлять персональные данные
      options.debug = SentryConfig.debug;

      // Фильтровать чувствительные данные перед отправкой
      options.beforeSend = (event, hint) {
        // Не отправлять события если Sentry отключен
        if (!SentryConfig.enabled) {
          return null;
        }

        // Фильтровать известный баг showcaseview 5.x (DiagnosticsProperty во всех вариантах)
        final hasShowcaseFrame = event.exceptions?.any((ex) =>
          ex.stackTrace?.frames.any((f) => f.package == 'showcaseview') ?? false,
        ) ?? false;
        final hasDiagnosticsMsg = event.exceptions?.any((ex) =>
          ex.value?.contains('DiagnosticsProperty') ?? false,
        ) ?? false;
        if (hasShowcaseFrame || hasDiagnosticsMsg) return null;

        // Удалить чувствительные данные из user
        if (event.user != null) {
          event.user!.email = null;
          event.user!.username = null;
          event.user!.ipAddress = null;
        }

        // Удалить Authorization headers
        if (event.request?.headers != null) {
          event.request!.headers.remove('authorization');
          event.request!.headers.remove('Authorization');
        }

        return event;
      };
    },
    appRunner: () => runApp(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sharedPreferences),
        ],
        child: const App(),
      ),
    ),
  );
}
