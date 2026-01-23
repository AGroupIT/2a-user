import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'src/app/app.dart';
import 'src/core/config/sentry_config.dart';
import 'src/core/persistence/shared_preferences_provider.dart';
import 'src/core/services/push_notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Инициализация Firebase для push-уведомлений
  await PushNotificationService.initializeFirebase();

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
          event = event.copyWith(
            user: event.user?.copyWith(
              email: null,
              username: null,
              ipAddress: null,
            ),
          );
        }

        // Удалить Authorization headers
        if (event.request?.headers != null) {
          final headers = Map<String, String>.from(event.request!.headers);
          headers.remove('authorization');
          headers.remove('Authorization');
          event = event.copyWith(
            request: event.request?.copyWith(headers: headers),
          );
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
