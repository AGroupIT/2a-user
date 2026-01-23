import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Интервал автоматического обновления данных (60 секунд)
const kAutoRefreshInterval = Duration(seconds: 60);

/// Провайдер для глобального интервала обновления
final autoRefreshIntervalProvider = Provider<Duration>((ref) {
  return kAutoRefreshInterval;
});

/// Миксин для автоматического обновления данных в ConsumerStatefulWidget
/// 
/// Пример использования:
/// ```dart
/// class _MyScreenState extends ConsumerState<MyScreen> with AutoRefreshMixin {
///   @override
///   void initState() {
///     super.initState();
///     startAutoRefresh(() {
///       ref.invalidate(myDataProvider);
///     });
///   }
/// }
/// ```
mixin AutoRefreshMixin<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  Timer? _autoRefreshTimer;
  bool _isVisible = true;

  /// Запускает автоматическое обновление данных
  void startAutoRefresh(VoidCallback onRefresh, {Duration? interval}) {
    stopAutoRefresh();
    
    final refreshInterval = interval ?? kAutoRefreshInterval;
    
    _autoRefreshTimer = Timer.periodic(refreshInterval, (_) {
      if (_isVisible && mounted) {
        debugPrint('AutoRefresh: Обновление данных...');
        onRefresh();
      }
    });
  }

  /// Останавливает автоматическое обновление
  void stopAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = null;
  }

  /// Приостанавливает обновление когда экран не виден
  void pauseAutoRefresh() {
    _isVisible = false;
  }

  /// Возобновляет обновление когда экран снова виден
  void resumeAutoRefresh() {
    _isVisible = true;
  }

  @override
  void dispose() {
    stopAutoRefresh();
    super.dispose();
  }
}

/// Класс для отслеживания видимости экрана и управления auto-refresh
class AutoRefreshController {
  Timer? _timer;
  bool _isPaused = false;
  final VoidCallback onRefresh;
  final Duration interval;

  AutoRefreshController({
    required this.onRefresh,
    this.interval = kAutoRefreshInterval,
  });

  void start() {
    stop();
    _timer = Timer.periodic(interval, (_) {
      if (!_isPaused) {
        onRefresh();
      }
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void pause() => _isPaused = true;
  void resume() => _isPaused = false;

  void dispose() => stop();
}
