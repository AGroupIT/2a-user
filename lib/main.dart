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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
