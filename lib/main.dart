import 'dart:async';
import 'dart:io' if (dart.library.html) 'src/core/platform/platform_stub.dart';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb, kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';

import 'src/app/app.dart';
import 'src/core/config/sentry_config.dart';
import 'src/core/logging/client_log_service.dart';
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

Future<PackageInfo?> _loadPackageInfo() async {
  try {
    return await PackageInfo.fromPlatform();
  } catch (e) {
    debugPrint('PackageInfo init failed (non-blocking): $e');
    return null;
  }
}

bool _globalErrorLoggingInstalled = false;

void _installGlobalErrorLogging() {
  if (_globalErrorLoggingInstalled) return;
  _globalErrorLoggingInstalled = true;

  final previousFlutterHandler = FlutterError.onError;
  FlutterError.onError = (details) {
    ClientLogService.instance.error(
      'Flutter framework error',
      error: details.exception,
      stackTrace: details.stack,
    );
    if (previousFlutterHandler != null) {
      previousFlutterHandler(details);
    } else {
      FlutterError.presentError(details);
    }
  };

  final previousPlatformHandler = ui.PlatformDispatcher.instance.onError;
  ui.PlatformDispatcher.instance.onError = (error, stackTrace) {
    ClientLogService.instance.error(
      'Platform dispatcher error',
      error: error,
      stackTrace: stackTrace,
    );
    return previousPlatformHandler?.call(error, stackTrace) ?? false;
  };
}

SentryEvent? _filterSentryEvent(SentryEvent event, Hint hint) {
  if (!SentryConfig.enabled) return null;

  final keepHttpError = hint.get('keep_http_error') == true;
  final exType = event.exceptions?.firstOrNull?.type ?? '';
  final exValue = event.exceptions?.firstOrNull?.value ?? '';

  // Сетевые сбои у клиентов ожидаемы: плохой интернет, VPN, DPI, China/RF routes.
  // Их оставляем в breadcrumbs, но не создаём отдельные issues.
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
  if (!keepHttpError && networkErrors.contains(exType)) return null;

  // Ошибки файловой системы — stale пути, удалённые кеш-файлы и т.п.
  // Обычно приходят из FileImage._loadAsync для превью фото из кеша.
  const fileErrors = {'PathNotFoundException', 'FileSystemException'};
  if (fileErrors.contains(exType)) return null;

  final frames = event.exceptions?.firstOrNull?.stackTrace?.frames;
  final joinedFrames = frames == null
      ? ''
      : frames
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
  final hasNoisyStack = noisyStackMarkers.any(joinedFrames.contains);

  // Flutter иногда заворачивает ошибку в DiagnosticsProperty. Не режем все такие
  // события подряд, иначе потеряем реальные layout/assert ошибки. Фильтруем
  // только когда значение или стек явно указывают на сетевой/файловый слой.
  if (exValue.contains('DiagnosticsProperty') && hasNoisyStack) return null;

  if (!keepHttpError &&
      (exValue.contains('Connection refused') ||
          exValue.contains('Connection reset') ||
          exValue.contains('Connection closed') ||
          exValue.contains('Connection timed out') ||
          exValue.contains('Network is unreachable') ||
          exValue.contains('Software caused connection abort') ||
          exValue.contains('No such file or directory') ||
          exValue.contains('Cannot open file'))) {
    return null;
  }

  if (!keepHttpError && hasNoisyStack) return null;

  // Не отправляем PII и auth headers.
  if (event.user != null) {
    event.user!.email = null;
    event.user!.username = null;
    event.user!.ipAddress = null;
  }
  if (event.request?.headers != null) {
    event.request!.headers.remove('authorization');
    event.request!.headers.remove('Authorization');
  }

  event.tags ??= {};
  event.tags!['app'] = SentryConfig.appName;

  return event;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kReleaseMode) {
    debugPrint = (String? message, {int? wrapWidth}) {};
  }

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
  final packageInfo = await _loadPackageInfo();

  // Инициализация Sentry для error tracking (только в release с DSN)
  if (!SentryConfig.enabled) {
    // В debug без DSN — запускаем без Sentry чтобы не спамить native логи
    _installGlobalErrorLogging();
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
      if (packageInfo != null) {
        options.release = SentryConfig.release(
          packageName: packageInfo.packageName,
          version: packageInfo.version,
          buildNumber: packageInfo.buildNumber,
        );
        options.dist = SentryConfig.dist(buildNumber: packageInfo.buildNumber);
      } else {
        options.release = '${SentryConfig.appName}@unknown';
        options.dist = 'unknown';
      }
      options.sampleRate = SentryConfig.sampleRate;
      options.tracesSampleRate = SentryConfig.tracesSampleRate;
      options.maxBreadcrumbs = SentryConfig.maxBreadcrumbs;
      options.sendDefaultPii = false;
      options.debug = SentryConfig.debug;
      options.attachStacktrace = true;
      options.enableAutoSessionTracking = true;
      options.enablePrintBreadcrumbs = false;
      options.anrEnabled = true;
      options.replay.sessionSampleRate = SentryConfig.replaySessionSampleRate;
      options.replay.onErrorSampleRate = SentryConfig.replayOnErrorSampleRate;
      options.privacy.maskAllText = true;
      options.privacy.maskAllImages = true;
      options.beforeSend = _filterSentryEvent;
    },
    appRunner: () {
      _installGlobalErrorLogging();
      runApp(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(sharedPreferences),
          ],
          child: SentryWidget(child: const App()),
        ),
      );
    },
  );
}
