import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import '../logging/client_log_service.dart';

/// Лёгкий монитор кадров для profile/release сборок.
///
/// Не меняет бизнес-логику и не отправляет отдельные запросы на каждый кадр:
/// агрегирует просадки и пишет их в локальный ClientLog/Sentry breadcrumbs
/// максимум раз в [_reportInterval]. Это помогает разбирать жалобы клиентов и
/// делать page-by-page profiling без постоянного DevTools-подключения.
class AppPerformanceMonitor {
  AppPerformanceMonitor._();

  static final AppPerformanceMonitor instance = AppPerformanceMonitor._();

  /// Можно выключить при необходимости:
  /// `--dart-define=APP_PERF_MONITOR=false`.
  static const bool enabled = bool.fromEnvironment(
    'APP_PERF_MONITOR',
    defaultValue: true,
  );

  /// Включить Flutter performance overlay поверх приложения:
  /// `--dart-define=APP_PERF_OVERLAY=true`.
  static const bool showOverlay = bool.fromEnvironment(
    'APP_PERF_OVERLAY',
    defaultValue: false,
  );

  static const Duration _reportInterval = Duration(seconds: 20);
  static const double _slowFrameMs = 16.7;
  static const double _verySlowFrameMs = 33.3;

  bool _started = false;
  DateTime _windowStartedAt = DateTime.now();
  DateTime? _lastReportAt;
  int _frames = 0;
  int _slowFrames = 0;
  int _verySlowFrames = 0;
  double _worstTotalMs = 0;
  double _worstBuildMs = 0;
  double _worstRasterMs = 0;

  void start() {
    if (!enabled || _started) return;
    _started = true;
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  void stop() {
    if (!_started) return;
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    _started = false;
  }

  void _onTimings(List<FrameTiming> timings) {
    for (final timing in timings) {
      final buildMs = _toMs(timing.buildDuration);
      final rasterMs = _toMs(timing.rasterDuration);
      final totalMs = buildMs + rasterMs;

      _frames += 1;
      if (totalMs > _slowFrameMs) _slowFrames += 1;
      if (totalMs > _verySlowFrameMs) _verySlowFrames += 1;
      if (totalMs > _worstTotalMs) {
        _worstTotalMs = totalMs;
        _worstBuildMs = buildMs;
        _worstRasterMs = rasterMs;
      }
    }

    _maybeReport();
  }

  void _maybeReport() {
    if (_frames == 0 || _slowFrames == 0) return;

    final now = DateTime.now();
    final lastReportAt = _lastReportAt;
    if (lastReportAt != null &&
        now.difference(lastReportAt) < _reportInterval) {
      return;
    }

    _lastReportAt = now;
    final windowDuration = now.difference(_windowStartedAt);
    final slowPercent = (_slowFrames / _frames * 100).toStringAsFixed(1);

    ClientLogService.instance.add(
      type: 'performance_slow_frames',
      level: _verySlowFrames > 0 ? 'warning' : 'info',
      message:
          'Замечены медленные кадры: $_slowFrames/$_frames ($slowPercent%)',
      data: {
        'windowMs': windowDuration.inMilliseconds,
        'frames': _frames,
        'slowFrames': _slowFrames,
        'verySlowFrames': _verySlowFrames,
        'slowFrameThresholdMs': _slowFrameMs,
        'verySlowFrameThresholdMs': _verySlowFrameMs,
        'worstTotalMs': double.parse(_worstTotalMs.toStringAsFixed(1)),
        'worstBuildMs': double.parse(_worstBuildMs.toStringAsFixed(1)),
        'worstRasterMs': double.parse(_worstRasterMs.toStringAsFixed(1)),
        'mode': kReleaseMode
            ? 'release'
            : kProfileMode
            ? 'profile'
            : 'debug',
      },
    );

    _resetWindow(now);
  }

  void _resetWindow(DateTime now) {
    _windowStartedAt = now;
    _frames = 0;
    _slowFrames = 0;
    _verySlowFrames = 0;
    _worstTotalMs = 0;
    _worstBuildMs = 0;
    _worstRasterMs = 0;
  }

  double _toMs(Duration duration) => duration.inMicroseconds / 1000.0;
}
