import 'dart:async';
import 'dart:io' if (dart.library.html) 'src/core/platform/platform_stub.dart';

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
  if (kIsWeb) return;
  if (!Platform.isIOS) return;

  try {
    final status = await AppTrackingTransparency.trackingAuthorizationStatus;
    if (status == TrackingStatus.notDetermined) {
      await Future.delayed(const Duration(milliseconds: 500));
      await AppTrackingTransparency.requestTrackingAuthorization();
    }
  } catch (e) {
    debugPrint('ATT: Ошибка запроса разрешения - $e');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Ограничиваем кэш декодированных изображений в памяти
  PaintingBinding.instance.imageCache.maximumSize =
      300; // до 300 изображений (для списков с 100+ треками)
  PaintingBinding.instance.imageCache.maximumSizeBytes =
      100 * 1024 * 1024; // 100 МБ

  // Firebase инициализируется в фоне — НЕ блокирует запуск приложения.
  // Это критично для пользователей в РФ, где провайдеры могут замедлять
  // трафик к googleapis.com через DPI (ТСПУ).
  PushNotificationService.initializeFirebase().catchError((e) {
    debugPrint('Firebase init failed (non-blocking): $e');
  });

  // Запрос разрешения на отслеживание (ATT) - ОБЯЗАТЕЛЬНО до AppMetrica
  await _requestTrackingPermission();

  // Инициализация AppMetrica не должна блокировать первый экран приложения.
  unawaited(
    AnalyticsService.initialize()
        .timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            debugPrint('AppMetrica init timed out (non-blocking)');
          },
        )
        .catchError((e) {
          debugPrint('AppMetrica init failed (non-blocking): $e');
        }),
  );

  // Инициализация SharedPreferences для showcase
  final sharedPreferences = await SharedPreferences.getInstance();

  // Инициализация Sentry для error tracking (только в release с DSN)
  if (!SentryConfig.enabled) {
    // В debug без DSN — запускаем без Sentry чтобы не спамить native логи
    runApp(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sharedPreferences),
        ],
        child: const App(),
      ),
    );
    return;
  }
  await SentryFlutter.init(
    (options) {
      options.dsn = SentryConfig.dsn;
      options.environment = SentryConfig.environment;
      options.release = SentryConfig.release;
      options.dist = SentryConfig.appName;
      options.sampleRate = SentryConfig.sampleRate;
      options.tracesSampleRate = SentryConfig.tracesSampleRate;
      options.maxBreadcrumbs = SentryConfig.maxBreadcrumbs;
      options.sendDefaultPii = false;
      options.debug = SentryConfig.debug;

      options.beforeSend = (event, hint) {
        if (!SentryConfig.enabled) return null;

        // Фильтруем сетевые ошибки — не баги, а ожидаемое поведение при плохом интернете.
        final exType = event.exceptions?.firstOrNull?.type ?? '';
        const networkErrors = {
          'SocketException',
          '_ClientSocketException',
          '_HttpException',
          'ClientException',
          'HandshakeException',
          'TlsException',
          '_TlsException',
          'HttpException',
          'HttpExceptionWithStatus',
          'TimeoutException',
          'WebSocketException',
          'DioException',
          'OSError',
        };
        if (networkErrors.contains(exType)) return null;

        // Ошибки файловой системы — stale пути, удалённые кеш-файлы и т.п.
        // Обычно приходят из FileImage._loadAsync для превью фото из кеша.
        const fileErrors = {'PathNotFoundException', 'FileSystemException'};
        if (fileErrors.contains(exType)) return null;

        // Flutter error reporter оборачивает реальный exception в DiagnosticsProperty,
        // из-за чего тип события в Sentry становится непредсказуемым, а value —
        // "Instance of 'DiagnosticsProperty<void>'". Такие события приходят из
        // системных сетевых/файловых сбоев и не являются багами приложения.
        final exValue = event.exceptions?.firstOrNull?.value ?? '';
        if (exValue.contains("DiagnosticsProperty")) return null;

        // Also filter by exception value containing network-related keywords
        if (exValue.contains('Connection refused') ||
            exValue.contains('Connection reset') ||
            exValue.contains('Connection closed') ||
            exValue.contains('Connection timed out') ||
            exValue.contains('Network is unreachable') ||
            exValue.contains('Software caused connection abort') ||
            exValue.contains('No such file or directory') ||
            exValue.contains('Cannot open file')) {
          return null;
        }

        // Фильтрация по стек-трейсу: если фреймы указывают на сетевой/файловый
        // слой dart:io или painting.FileImage — это такая же "network/filesystem noise".
        final frames = event.exceptions?.firstOrNull?.stackTrace?.frames;
        if (frames != null && frames.isNotEmpty) {
          final joined = frames
              .map(
                (f) =>
                    '${f.package ?? ''}:${f.fileName ?? ''}:${f.function ?? ''}',
              )
              .join('\n');
          const noisyStackMarkers = [
            '_HttpParser',
            '_RawSecureSocket',
            '_NativeSocket',
            'secure_socket.dart',
            'socket_patch.dart',
            'http_impl.dart',
            'http_parser.dart',
            'FileImage._loadAsync',
          ];
          for (final marker in noisyStackMarkers) {
            if (joined.contains(marker)) return null;
          }
        }

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
