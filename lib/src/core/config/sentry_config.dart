import 'package:flutter/foundation.dart';

/// Конфигурация для Sentry error tracking
class SentryConfig {
  /// DSN (Data Source Name) для Sentry проекта
  /// Получается из переменной окружения при сборке или hardcoded для development
  static const String dsn = String.fromEnvironment(
    'SENTRY_DSN',
    defaultValue: '', // Пустой DSN для development - Sentry не будет работать
  );

  static const String _environment = String.fromEnvironment(
    'SENTRY_ENVIRONMENT',
    defaultValue: '',
  );
  static const String _release = String.fromEnvironment(
    'SENTRY_RELEASE',
    defaultValue: '',
  );
  static const String _dist = String.fromEnvironment(
    'SENTRY_DIST',
    defaultValue: '',
  );
  static const String _sampleRate = String.fromEnvironment(
    'SENTRY_SAMPLE_RATE',
    defaultValue: '1.0',
  );
  static const String _tracesSampleRate = String.fromEnvironment(
    'SENTRY_TRACES_SAMPLE_RATE',
    defaultValue: '0.05',
  );
  static const bool _tracesEnabled = bool.fromEnvironment(
    'SENTRY_ENABLE_TRACES',
  );
  static const bool verifyButtonEnabled = bool.fromEnvironment(
    'SENTRY_VERIFY_BUTTON',
  );
  static const String _replaySessionSampleRate = String.fromEnvironment(
    'SENTRY_REPLAY_SESSION_SAMPLE_RATE',
    defaultValue: '0.0',
  );
  static const String _replayOnErrorSampleRate = String.fromEnvironment(
    'SENTRY_REPLAY_ON_ERROR_SAMPLE_RATE',
    defaultValue: '1.0',
  );

  /// Включен ли Sentry (только release/profile-сборки с DSN).
  static bool get enabled => dsn.isNotEmpty && kReleaseMode;

  /// Окружение (production, staging, development)
  static String get environment {
    if (_environment.isNotEmpty) return _environment;
    if (kReleaseMode) {
      return 'production';
    } else if (kProfileMode) {
      return 'staging';
    } else {
      return 'development';
    }
  }

  /// Sample rate для отправки событий (0.0 - 1.0)
  /// 1.0 = отправлять все события
  static double get sampleRate => _rate(_sampleRate, fallback: 1.0);

  /// Sample rate для трассировки производительности (0.0 - 1.0)
  /// По умолчанию трассировка выключена, чтобы не плодить шум и трафик.
  static double get tracesSampleRate =>
      _tracesEnabled ? _rate(_tracesSampleRate, fallback: 0.05) : 0.0;

  /// Session Replay для обычных сессий по умолчанию выключен, чтобы не
  /// писать лишние экраны с персональными данными. Для ручного теста можно
  /// собрать с `--dart-define=SENTRY_REPLAY_SESSION_SAMPLE_RATE=1.0`.
  static double get replaySessionSampleRate =>
      _rate(_replaySessionSampleRate, fallback: 0.0);

  /// При ошибке replay сохраняет последние секунды сессии. Текст и изображения
  /// маскируются в main.dart, поэтому в Sentry не должны уходить фото/PII.
  static double get replayOnErrorSampleRate =>
      _rate(_replayOnErrorSampleRate, fallback: 1.0);

  /// Debug режим для Sentry (только в development)
  static bool get debug => kDebugMode;

  static String release({
    required String packageName,
    required String version,
    required String buildNumber,
  }) {
    if (_release.isNotEmpty) return _release;
    return '$packageName@$version+$buildNumber';
  }

  static String dist({required String buildNumber}) {
    if (_dist.isNotEmpty) return _dist;
    return buildNumber;
  }

  /// Имя приложения для Sentry
  static String get appName => '2a-user';

  /// Максимальное количество breadcrumbs
  static int get maxBreadcrumbs => 100;

  /// Timeout для отправки событий
  static Duration get sendTimeout => const Duration(seconds: 30);

  static double _rate(String value, {required double fallback}) {
    final parsed = double.tryParse(value) ?? fallback;
    if (parsed < 0) return 0;
    if (parsed > 1) return 1;
    return parsed;
  }
}
