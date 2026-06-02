import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/cache/stale_data_cache.dart';
import '../../../core/logging/client_log_service.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/demo_mode_provider.dart';
import '../../../core/services/websocket_provider.dart';
import '../../shell/application/shell_branch_provider.dart';
import '../domain/photo_item.dart';

/// DS-H2/P7: realtime-мост для photos.
///
/// Photos в user-приложении — набор отдельных FutureProvider.family, который
/// нельзя естественно подписать на WebSocket. Этот provider держит
/// подписку на `ws.deltas` и `ws.dataChanged` для типов
/// `'photo_requests'` (само событие создания/обновления) и `'tracks'`
/// (когда фото привязывается к треку), и при каждом событии (с дебаунсом)
/// делает `ref.invalidate()` вспомогательных providers фото.
///
/// Подключается в `photos_screen.dart` через `ref.watch(photosRealtimeBridgeProvider);`,
/// чтобы он жил вместе с экраном (autoDispose снимает подписки при выходе).
final photosRealtimeBridgeProvider = Provider.autoDispose<void>((ref) {
  final isPhotosTabActive =
      ref.watch(activeShellBranchIndexProvider) == ShellBranchIndex.photos;
  if (!isPhotosTabActive) {
    return;
  }

  final ws = ref.read(webSocketServiceProvider);
  Timer? debounce;
  Timer? cooldownTimer;
  DateTime? lastInvalidateAt;
  const invalidateCooldown = Duration(seconds: 2);

  void invalidateAll(String reason) {
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 500), () {
      final now = DateTime.now();
      final last = lastInvalidateAt;
      if (last != null) {
        final elapsed = now.difference(last);
        if (elapsed < invalidateCooldown) {
          cooldownTimer ??= Timer(invalidateCooldown - elapsed, () {
            cooldownTimer = null;
            invalidateAll(reason);
          });
          return;
        }
      }
      lastInvalidateAt = now;
      debugPrint('[UserPhotos] silent invalidate ($reason)');
      ClientLogService.instance.add(
        type: 'photos_realtime_invalidate',
        level: 'info',
        message: 'Фотоотчёты получили realtime-обновление',
        data: {'reason': reason},
      );
      // Не инвалидируем paginatedPhotosProvider: это пересоздаёт notifier,
      // запускает загрузку с skip=0 и возвращает текущий скролл в начало.
      // Видимый список обновляется pull-to-refresh и мягким refresh внутри
      // PaginatedPhotosNotifier.
      ref.invalidate(photosTotalCountProvider);
      ref.invalidate(photosRecentProvider);
      ref.invalidate(photosDaysProvider);
      ref.invalidate(photosByDateProvider);
      ref.invalidate(photosSearchProvider);
    });
  }

  final deltaSub = ws.deltas
      .where((d) => d.type == 'photo_requests' || d.type == 'tracks')
      .listen((_) => invalidateAll('delta'));
  final dataChangedSub = ws.dataChanged
      .where((d) => d['type'] == 'photo_requests' || d['type'] == 'tracks')
      .listen((_) => invalidateAll('data_changed'));

  ref.onDispose(() {
    deltaSub.cancel();
    dataChangedSub.cancel();
    debounce?.cancel();
    cooldownTimer?.cancel();
  });
});

/// Провайдер для получения общего количества фото по коду клиента
final photosTotalCountProvider = FutureProvider.autoDispose.family<int, String>(
  (ref, clientCode) async {
    if (ref.watch(demoModeProvider)) return 0;
    final apiClient = ref.read(apiClientProvider);

    try {
      final queryParams = {
        'clientCode': clientCode,
        'source': 'photoRequest', // Только фото из запросов фотоотчётов
        'take': 1,
      };
      final data = await StaleDataCache.getJson(
        ref: ref,
        cacheKey: StaleDataCache.buildKey('photos_total_count', queryParams),
        label: 'количество фотоотчётов',
        request: () => apiClient.get('/photos', queryParameters: queryParams),
      );

      final total = data['total'] as int? ?? 0;
      return total;
    } catch (e) {
      debugPrint('Error loading photos count: $e');
      return 0;
    }
  },
);

/// Провайдер для получения последних фото по коду клиента (только из фотоотчётов)
final photosRecentProvider = FutureProvider.autoDispose
    .family<List<PhotoItem>, ({String clientCode, int limit})>((
      ref,
      params,
    ) async {
      if (ref.watch(demoModeProvider)) {
        return const <PhotoItem>[];
      }
      final apiClient = ref.read(apiClientProvider);

      try {
        final queryParams = {
          'clientCode': params.clientCode,
          'source': 'photoRequest', // Только фото из запросов фотоотчётов
          'take': params.limit,
        };
        final data = await StaleDataCache.getJson(
          ref: ref,
          cacheKey: StaleDataCache.buildKey('photos_recent', queryParams),
          label: 'последние фотоотчёты',
          request: () => apiClient.get('/photos', queryParameters: queryParams),
        );

        final photosJson = data['data'] as List<dynamic>? ?? [];

        return photosJson
            .map((json) => PhotoItem.fromJson(json as Map<String, dynamic>))
            .toList();
      } catch (e) {
        debugPrint('Error loading recent photos: $e');
        return [];
      }
    });

/// Провайдер для получения дней с фото
final photosDaysProvider = FutureProvider.autoDispose
    .family<List<String>, ({String clientCode, int month, int year})>((
      ref,
      params,
    ) async {
      if (ref.watch(demoModeProvider)) {
        // Дни, в которые есть демо-фотографии за нужный месяц
        return const <String>[];
      }
      final apiClient = ref.read(apiClientProvider);

      try {
        final response = await apiClient.get(
          '/photos/days',
          queryParameters: {
            'clientCode': params.clientCode,
            'source': 'photoRequest', // Только фото из запросов фотоотчётов
            'month': params.month,
            'year': params.year,
          },
        );

        if (response.statusCode == 200 && response.data != null) {
          final data = response.data as Map<String, dynamic>;
          final days = data['days'] as List<dynamic>? ?? [];
          return days.map((d) => d.toString()).toList();
        }
        return [];
      } catch (e) {
        debugPrint('Error loading photo days: $e');
        return [];
      }
    });

/// Провайдер для получения фото по дате
final photosByDateProvider = FutureProvider.autoDispose
    .family<List<PhotoItem>, ({String clientCode, String date})>((
      ref,
      params,
    ) async {
      if (ref.watch(demoModeProvider)) {
        return const <PhotoItem>[];
      }
      final apiClient = ref.read(apiClientProvider);

      try {
        final queryParams = {
          'clientCode': params.clientCode,
          'source': 'photoRequest', // Только фото из запросов фотоотчётов
          'date': params.date,
          'take': 100,
        };
        final data = await StaleDataCache.getJson(
          ref: ref,
          cacheKey: StaleDataCache.buildKey('photos_by_date', queryParams),
          label: 'фотоотчёты',
          request: () => apiClient.get('/photos', queryParameters: queryParams),
        );

        final photosJson = data['data'] as List<dynamic>? ?? [];

        return photosJson
            .map((json) => PhotoItem.fromJson(json as Map<String, dynamic>))
            .toList();
      } catch (e) {
        debugPrint('Error loading photos by date: $e');
        return [];
      }
    });

// ─── Paginated photos by date ─────────────────────────────────────────────────

class PaginatedPhotosState {
  final List<PhotoItem> photos;
  final bool isLoading;
  final bool hasMore;
  final int total;
  final String? error;
  final String? date;
  final String clientCode;

  const PaginatedPhotosState({
    this.photos = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.total = 0,
    this.error,
    this.date,
    required this.clientCode,
  });

  PaginatedPhotosState copyWith({
    List<PhotoItem>? photos,
    bool? isLoading,
    bool? hasMore,
    int? total,
    String? error,
    bool clearError = false,
  }) {
    return PaginatedPhotosState(
      photos: photos ?? this.photos,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      total: total ?? this.total,
      error: clearError ? null : (error ?? this.error),
      date: date,
      clientCode: clientCode,
    );
  }
}

class PaginatedPhotosNotifier {
  static const int _pageSize = 12;
  static const _silentRefreshCooldown = Duration(seconds: 2);
  static const _photoTypes = {'photo_requests', 'tracks'};

  final Ref _ref;
  PaginatedPhotosState _state;
  PaginatedPhotosState get state => _state;

  final List<void Function()> _listeners = [];
  StreamSubscription? _deltaSub;
  StreamSubscription? _reconnectSub;
  Timer? _refreshTimer;
  Timer? _cooldownTimer;
  DateTime? _lastSilentRefreshStartedAt;
  bool _silentRefreshInProgress = false;
  bool _isRealtimeRefreshEnabled = false;

  PaginatedPhotosNotifier(this._ref, String clientCode, [String? date])
    : _state = PaginatedPhotosState(clientCode: clientCode, date: date) {
    loadInitial();
  }

  void setRealtimeRefreshEnabled(bool enabled) {
    if (_isRealtimeRefreshEnabled == enabled) return;
    _isRealtimeRefreshEnabled = enabled;

    if (enabled) {
      _subscribeRealtimeRefresh();
      if (_state.photos.isNotEmpty) {
        _debouncedRefresh();
      }
      return;
    }

    _cancelRealtimeRefresh();
    _refreshTimer?.cancel();
    _refreshTimer = null;
    _cooldownTimer?.cancel();
    _cooldownTimer = null;
  }

  void _subscribeRealtimeRefresh() {
    if (_deltaSub != null || _reconnectSub != null) return;

    // Delta sync is the primary update mechanism.
    // data_changed broadcast is not used to avoid full page reloads
    // that reset scroll position and pagination.
    final wsService = _ref.read(webSocketServiceProvider);
    _deltaSub = wsService.deltas
        .where((delta) => _photoTypes.contains(delta.type))
        .listen((_) => _debouncedRefresh());
    _reconnectSub = wsService.reconnected.listen((_) => _debouncedRefresh());
  }

  void _cancelRealtimeRefresh() {
    unawaited(_deltaSub?.cancel());
    unawaited(_reconnectSub?.cancel());
    _deltaSub = null;
    _reconnectSub = null;
  }

  void _debouncedRefresh() {
    if (!_isRealtimeRefreshEnabled) return;
    _refreshTimer?.cancel();
    _refreshTimer = Timer(const Duration(milliseconds: 500), () {
      _scheduleSilentRefresh();
    });
  }

  void _scheduleSilentRefresh() {
    if (!_isRealtimeRefreshEnabled) return;
    if (_silentRefreshInProgress) {
      _queueSilentRefresh(_silentRefreshCooldown);
      return;
    }

    final lastStartedAt = _lastSilentRefreshStartedAt;
    if (lastStartedAt != null) {
      final elapsed = DateTime.now().difference(lastStartedAt);
      if (elapsed < _silentRefreshCooldown) {
        _queueSilentRefresh(_silentRefreshCooldown - elapsed);
        return;
      }
    }

    _lastSilentRefreshStartedAt = DateTime.now();
    debugPrint(
      '[PaginatedPhotos] WS event — silent refresh for ${_state.date ?? 'all'}',
    );
    ClientLogService.instance.add(
      type: 'photos_silent_refresh_scheduled',
      level: 'info',
      message: 'Запланировано мягкое обновление фотоотчётов',
      data: {'date': _state.date, 'currentCount': _state.photos.length},
    );
    unawaited(_silentRefresh());
  }

  void _queueSilentRefresh(Duration delay) {
    if (_cooldownTimer != null) {
      return;
    }

    _cooldownTimer = Timer(delay, () {
      _cooldownTimer = null;
      _scheduleSilentRefresh();
    });
  }

  /// Фоновое обновление без сброса скролла и пагинации.
  /// Перезагружает столько же фото, сколько уже подгружено.
  Future<void> _silentRefresh() async {
    if (_silentRefreshInProgress) {
      return;
    }
    _silentRefreshInProgress = true;
    try {
      final currentCount = _state.photos.length;
      final take = currentCount > _pageSize ? currentCount : _pageSize;
      final response = await _apiClient.get(
        '/photos',
        queryParameters: {
          'clientCode': _state.clientCode,
          'source': 'photoRequest',
          if (_state.date != null) 'date': _state.date,
          'take': take,
          'skip': 0,
        },
      );
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final json = data['data'] as List<dynamic>? ?? [];
        final total = data['total'] as int? ?? 0;
        final photos = json
            .map((j) => PhotoItem.fromJson(j as Map<String, dynamic>))
            .toList();
        ClientLogService.instance.add(
          type: 'photos_silent_refresh_success',
          level: 'info',
          message: 'Мягкое обновление фотоотчётов выполнено',
          data: {'date': _state.date, 'count': photos.length, 'total': total},
        );
        if (_state.photos.length > currentCount) {
          _queueSilentRefresh(Duration.zero);
          return;
        }
        _update(
          _state.copyWith(
            photos: photos,
            total: total,
            hasMore: photos.length < total,
          ),
        );
      }
    } catch (e) {
      ClientLogService.instance.add(
        type: 'photos_silent_refresh_error',
        level: 'warning',
        message: 'Ошибка мягкого обновления фотоотчётов',
        data: {'date': _state.date, 'error': e.toString()},
      );
      debugPrint('[PaginatedPhotos] Silent refresh error: $e');
    } finally {
      _silentRefreshInProgress = false;
    }
  }

  void dispose() {
    _cancelRealtimeRefresh();
    _refreshTimer?.cancel();
    _cooldownTimer?.cancel();
  }

  ApiClient get _apiClient => _ref.read(apiClientProvider);

  void addListener(void Function() l) => _listeners.add(l);
  void removeListener(void Function() l) => _listeners.remove(l);
  void _notify() {
    for (final l in _listeners) {
      l();
    }
  }

  void _update(PaginatedPhotosState s) {
    _state = s;
    _notify();
  }

  Future<void> loadInitial() async {
    if (_ref.read(demoModeProvider)) {
      _update(
        _state.copyWith(
          photos: const <PhotoItem>[],
          total: 0,
          hasMore: false,
          isLoading: false,
        ),
      );
      return;
    }
    _update(
      _state.copyWith(
        isLoading: true,
        photos: [],
        hasMore: true,
        clearError: true,
      ),
    );
    try {
      ClientLogService.instance.add(
        type: 'photos_page_load_start',
        level: 'info',
        message: 'Загрузка первой страницы фотоотчётов',
        data: {'date': _state.date, 'take': _pageSize},
      );
      final result = await _fetch(skip: 0);
      ClientLogService.instance.add(
        type: 'photos_page_load_success',
        level: 'info',
        message: 'Первая страница фотоотчётов загружена',
        data: {
          'date': _state.date,
          'count': result.photos.length,
          'total': result.total,
        },
      );
      _update(
        _state.copyWith(
          photos: result.photos,
          total: result.total,
          hasMore: result.photos.length < result.total,
          isLoading: false,
        ),
      );
    } catch (e) {
      ClientLogService.instance.add(
        type: 'photos_page_load_error',
        level: 'warning',
        message: 'Ошибка загрузки первой страницы фотоотчётов',
        data: {'date': _state.date, 'error': e.toString()},
      );
      _update(_state.copyWith(error: e.toString(), isLoading: false));
    }
  }

  Future<void> loadMore() async {
    if (_state.isLoading || !_state.hasMore) return;
    _update(_state.copyWith(isLoading: true));
    try {
      final skip = _state.photos.length;
      ClientLogService.instance.add(
        type: 'photos_page_load_more_start',
        level: 'info',
        message: 'Загрузка следующей страницы фотоотчётов',
        data: {'date': _state.date, 'take': _pageSize, 'skip': skip},
      );
      final result = await _fetch(skip: skip);
      ClientLogService.instance.add(
        type: 'photos_page_load_more_success',
        level: 'info',
        message: 'Следующая страница фотоотчётов загружена',
        data: {
          'date': _state.date,
          'count': result.photos.length,
          'total': result.total,
          'skip': skip,
        },
      );
      final photos = [..._state.photos, ...result.photos];
      _update(
        _state.copyWith(
          photos: photos,
          total: result.total,
          hasMore: photos.length < result.total,
          isLoading: false,
        ),
      );
    } catch (e) {
      ClientLogService.instance.add(
        type: 'photos_page_load_more_error',
        level: 'warning',
        message: 'Ошибка загрузки следующей страницы фотоотчётов',
        data: {'date': _state.date, 'error': e.toString()},
      );
      _update(_state.copyWith(error: e.toString(), isLoading: false));
    }
  }

  Future<({List<PhotoItem> photos, int total})> _fetch({
    required int skip,
  }) async {
    final queryParams = {
      'clientCode': _state.clientCode,
      'source': 'photoRequest',
      if (_state.date != null) 'date': _state.date,
      'take': _pageSize,
      'skip': skip,
    };
    final data = await StaleDataCache.getJson(
      ref: _ref,
      cacheKey: StaleDataCache.buildKey('photos_paginated', queryParams),
      label: 'фотоотчёты',
      request: () => _apiClient.get('/photos', queryParameters: queryParams),
    );

    final json = data['data'] as List<dynamic>? ?? [];
    final total = data['total'] as int? ?? 0;
    final photos = json
        .map((j) => PhotoItem.fromJson(j as Map<String, dynamic>))
        .toList();
    return (photos: photos, total: total);
  }
}

final paginatedPhotosProvider = Provider.autoDispose
    .family<PaginatedPhotosNotifier, String>((ref, clientCode) {
      final notifier = PaginatedPhotosNotifier(ref, clientCode);
      ref.listen<int>(
        activeShellBranchIndexProvider,
        (_, index) => notifier.setRealtimeRefreshEnabled(
          index == ShellBranchIndex.photos,
        ),
        fireImmediately: true,
      );
      ref.onDispose(() => notifier.dispose());
      return notifier;
    });

final paginatedPhotosByDateProvider = Provider.autoDispose
    .family<PaginatedPhotosNotifier, ({String clientCode, String date})>((
      ref,
      params,
    ) {
      final notifier = PaginatedPhotosNotifier(
        ref,
        params.clientCode,
        params.date,
      );
      ref.listen<int>(
        activeShellBranchIndexProvider,
        (_, index) => notifier.setRealtimeRefreshEnabled(
          index == ShellBranchIndex.photos,
        ),
        fireImmediately: true,
      );
      ref.onDispose(() => notifier.dispose());
      return notifier;
    });

/// Провайдер для поиска фото
final photosSearchProvider =
    FutureProvider.family<List<PhotoItem>, ({String clientCode, String query})>(
      (ref, params) async {
        final apiClient = ref.read(apiClientProvider);

        try {
          final response = await apiClient.get(
            '/photos',
            queryParameters: {
              'clientCode': params.clientCode,
              'source': 'photoRequest', // Только фото из запросов фотоотчётов
              'search': params.query,
              'take': 50,
            },
          );

          if (response.statusCode == 200 && response.data != null) {
            final data = response.data as Map<String, dynamic>;
            final photosJson = data['data'] as List<dynamic>? ?? [];

            return photosJson
                .map((json) => PhotoItem.fromJson(json as Map<String, dynamic>))
                .toList();
          }
          return [];
        } on DioException catch (e) {
          debugPrint('Error searching photos: $e');
          return [];
        }
      },
    );
