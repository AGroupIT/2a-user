import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http_parser/http_parser.dart';

import '../../../core/data/demo_data.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/demo_mode_provider.dart';
import '../../../core/services/websocket_provider.dart';
import '../domain/track_item.dart';

// ==================== Status Model ====================

/// Модель статуса из БД
class TrackStatus {
  final int id;
  final String type;
  final String code;
  final String nameRu;
  final String? nameZh;
  final String? color;
  final String? icon;
  final int sortOrder;
  final bool isActive;

  const TrackStatus({
    required this.id,
    required this.type,
    required this.code,
    required this.nameRu,
    this.nameZh,
    this.color,
    this.icon,
    required this.sortOrder,
    required this.isActive,
  });

  factory TrackStatus.fromJson(Map<String, dynamic> json) {
    return TrackStatus(
      id: json['id'] as int,
      type: json['type'] as String? ?? '',
      code: json['code'] as String? ?? '',
      nameRu: json['nameRu'] as String? ?? '',
      nameZh: json['nameZh'] as String?,
      color: json['color'] as String?,
      icon: json['icon'] as String?,
      sortOrder: json['sortOrder'] as int? ?? 0,
      isActive: json['isActive'] as bool? ?? true,
    );
  }
}

/// Провайдер для получения статусов из БД по типу сущности.
final statusesByTypeProvider = FutureProvider.family<List<TrackStatus>, String>((
  ref,
  type,
) async {
  final apiClient = ref.read(apiClientProvider);

  try {
    final response = await apiClient.get(
      '/statuses',
      queryParameters: {'type': type, 'activeOnly': 'true'},
    );

    debugPrint(
      'statusesByTypeProvider($type): statusCode=${response.statusCode}, data=${response.data}',
    );

    if (response.statusCode == 200 && response.data != null) {
      final data = response.data as Map<String, dynamic>;
      final statusesJson = data['data'] as List<dynamic>? ?? [];

      debugPrint(
        'statusesByTypeProvider($type): parsed ${statusesJson.length} statuses',
      );

      return statusesJson
          .map((json) => TrackStatus.fromJson(json as Map<String, dynamic>))
          .toList();
    }
    return [];
  } on DioException catch (e) {
    debugPrint('Error loading $type statuses: $e');
    return [];
  }
});

/// Провайдер для получения статусов треков из БД
final trackStatusesProvider = statusesByTypeProvider('track');

/// Провайдер для получения статусов сборок из БД
final assemblyStatusesProvider = statusesByTypeProvider('assembly');

/// Провайдер для получения статусов фотоотчётов из БД
final photoRequestStatusesProvider = statusesByTypeProvider('photo_request');

/// Провайдер для получения статусов вопросов из БД
final questionStatusesProvider = statusesByTypeProvider('question');

// ==================== Paginated Tracks State ====================

/// Параметры фильтрации треков
class TracksFilterParams {
  final String clientCode;
  final String? statusCode; // код статуса из БД
  final String? assemblyStatusCode; // код статуса сборки из БД
  final String? search;
  final String? viewMode; // 'all', 'groups', 'singles'
  final String? productInfo; // 'filled', 'empty'
  final String? photoRequestStatus; // 'none' или код статуса
  final String? questionStatus; // 'none' или код статуса
  final String? assemblyDeliveryInfo; // 'filled', 'empty'
  final String sortBy; // 'createdAt' или 'updatedAt'

  const TracksFilterParams({
    required this.clientCode,
    this.statusCode,
    this.assemblyStatusCode,
    this.search,
    this.viewMode,
    this.productInfo,
    this.photoRequestStatus,
    this.questionStatus,
    this.assemblyDeliveryInfo,
    this.sortBy = 'createdAt',
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TracksFilterParams &&
          runtimeType == other.runtimeType &&
          clientCode == other.clientCode &&
          statusCode == other.statusCode &&
          assemblyStatusCode == other.assemblyStatusCode &&
          search == other.search &&
          viewMode == other.viewMode &&
          productInfo == other.productInfo &&
          photoRequestStatus == other.photoRequestStatus &&
          questionStatus == other.questionStatus &&
          assemblyDeliveryInfo == other.assemblyDeliveryInfo &&
          sortBy == other.sortBy;

  @override
  int get hashCode =>
      clientCode.hashCode ^
      statusCode.hashCode ^
      assemblyStatusCode.hashCode ^
      search.hashCode ^
      viewMode.hashCode ^
      productInfo.hashCode ^
      photoRequestStatus.hashCode ^
      questionStatus.hashCode ^
      assemblyDeliveryInfo.hashCode ^
      sortBy.hashCode;

  TracksFilterParams copyWith({
    String? clientCode,
    String? statusCode,
    String? assemblyStatusCode,
    String? search,
    String? viewMode,
    String? productInfo,
    String? photoRequestStatus,
    String? questionStatus,
    String? assemblyDeliveryInfo,
    String? sortBy,
    bool clearStatus = false,
    bool clearAssemblyStatus = false,
    bool clearSearch = false,
    bool clearProductInfo = false,
    bool clearPhotoRequestStatus = false,
    bool clearQuestionStatus = false,
    bool clearAssemblyDeliveryInfo = false,
  }) {
    return TracksFilterParams(
      clientCode: clientCode ?? this.clientCode,
      statusCode: clearStatus ? null : (statusCode ?? this.statusCode),
      assemblyStatusCode: clearAssemblyStatus
          ? null
          : (assemblyStatusCode ?? this.assemblyStatusCode),
      search: clearSearch ? null : (search ?? this.search),
      viewMode: viewMode ?? this.viewMode,
      productInfo: clearProductInfo ? null : (productInfo ?? this.productInfo),
      photoRequestStatus: clearPhotoRequestStatus
          ? null
          : (photoRequestStatus ?? this.photoRequestStatus),
      questionStatus: clearQuestionStatus
          ? null
          : (questionStatus ?? this.questionStatus),
      assemblyDeliveryInfo: clearAssemblyDeliveryInfo
          ? null
          : (assemblyDeliveryInfo ?? this.assemblyDeliveryInfo),
      sortBy: sortBy ?? this.sortBy,
    );
  }
}

/// Состояние пагинированного списка треков
class PaginatedTracksState {
  final List<TrackItem> tracks;
  final bool isLoading;
  final bool hasMore;
  final int total;
  final String? error;
  final TracksFilterParams filters;

  const PaginatedTracksState({
    this.tracks = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.total = 0,
    this.error,
    required this.filters,
  });

  PaginatedTracksState copyWith({
    List<TrackItem>? tracks,
    bool? isLoading,
    bool? hasMore,
    int? total,
    String? error,
    TracksFilterParams? filters,
    bool clearError = false,
  }) {
    return PaginatedTracksState(
      tracks: tracks ?? this.tracks,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      total: total ?? this.total,
      error: clearError ? null : (error ?? this.error),
      filters: filters ?? this.filters,
    );
  }
}

/// Notifier для управления пагинированным списком треков
/// Использует Provider.family для создания экземпляров с разными фильтрами
class PaginatedTracksNotifier {
  final Ref _ref;
  static const int _pageSize = 50;
  static const _silentRefreshCooldown = Duration(seconds: 2);

  PaginatedTracksState _state;
  PaginatedTracksState get state => _state;

  final List<void Function()> _listeners = [];

  StreamSubscription? _deltaSub;
  StreamSubscription? _dataChangedSub;
  StreamSubscription? _reconnectSub;
  Timer? _debounceTimer;
  Timer? _silentRefreshTimer;
  DateTime? _lastSilentRefreshStartedAt;
  bool _silentRefreshInProgress = false;

  static const _tracksTypes = {
    'tracks',
    'photo_requests',
    'questions',
    'assemblies',
  };

  PaginatedTracksNotifier(this._ref, TracksFilterParams initialFilters)
    : _state = PaginatedTracksState(filters: initialFilters) {
    // Delta/data_changed sync is handled silently to preserve scroll and pagination.
    final wsService = _ref.read(webSocketServiceProvider);
    _deltaSub = wsService.deltas
        .where((delta) => _tracksTypes.contains(delta.type))
        .listen((_) => _debouncedSilentRefresh());
    _dataChangedSub = wsService.dataChanged
        .where((event) => _tracksTypes.contains(event['type']))
        .listen((_) => _debouncedSilentRefresh());
    _reconnectSub = wsService.reconnected.listen(
      (_) => _debouncedSilentRefresh(),
    );

    // Загружаем начальные данные при создании
    loadInitial();
  }

  void dispose() {
    _deltaSub?.cancel();
    _dataChangedSub?.cancel();
    _reconnectSub?.cancel();
    _debounceTimer?.cancel();
    _silentRefreshTimer?.cancel();
  }

  void _debouncedSilentRefresh() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _scheduleSilentRefresh();
    });
  }

  void _scheduleSilentRefresh() {
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
    unawaited(loadInitial(silent: true));
  }

  void _queueSilentRefresh(Duration delay) {
    if (_silentRefreshTimer != null) {
      return;
    }

    _silentRefreshTimer = Timer(delay, () {
      _silentRefreshTimer = null;
      _scheduleSilentRefresh();
    });
  }

  ApiClient get _apiClient => _ref.read(apiClientProvider);

  void addListener(void Function() listener) {
    if (!_listeners.contains(listener)) {
      _listeners.add(listener);
    }
  }

  void removeListener(void Function() listener) {
    _listeners.remove(listener);
  }

  void _notifyListeners() {
    for (final listener in _listeners) {
      listener();
    }
  }

  void _updateState(PaginatedTracksState newState) {
    _state = newState;
    _notifyListeners();
  }

  /// Загрузить начальную страницу
  /// [silent] - если true, не показывать индикатор загрузки (для фонового обновления)
  Future<void> loadInitial({bool silent = false}) async {
    final requestFilters = _state.filters;
    if (_ref.read(demoModeProvider)) {
      _updateState(
        _state.copyWith(
          tracks: DemoData.tracks,
          total: DemoData.tracksCount,
          hasMore: false,
          isLoading: false,
          clearError: true,
        ),
      );
      return;
    }
    if (_state.isLoading) return;

    // При silent refresh не показываем loader и не очищаем текущие данные.
    // Загружаем столько же треков, сколько уже подгружено, чтобы сохранить
    // позицию скролла и пагинацию.
    if (silent) {
      if (_silentRefreshInProgress) return;
      _silentRefreshInProgress = true;
      try {
        final currentCount = _state.tracks.length;
        final take = currentCount > _pageSize ? currentCount : _pageSize;
        final result = await _fetchTracks(
          skip: 0,
          take: take,
          filters: requestFilters,
        );
        if (_state.filters != requestFilters) {
          await loadInitial(silent: true);
          return;
        }
        if (_state.tracks.length > currentCount) {
          _queueSilentRefresh(Duration.zero);
          return;
        }
        _updateState(
          _state.copyWith(
            tracks: result.tracks,
            total: result.total,
            hasMore: result.tracks.length < result.total,
            clearError: true,
          ),
        );
      } catch (e) {
        // При silent refresh ошибки не показываем пользователю
        debugPrint('[TracksProvider] Silent refresh error: $e');
      } finally {
        _silentRefreshInProgress = false;
      }
      return;
    }

    // Обычная загрузка с показом индикатора
    _updateState(
      _state.copyWith(
        isLoading: true,
        clearError: true,
        tracks: [],
        hasMore: true,
      ),
    );

    try {
      final result = await _fetchTracks(
        skip: 0,
        take: _pageSize,
        filters: requestFilters,
      );
      if (_state.filters != requestFilters) {
        _updateState(_state.copyWith(isLoading: false));
        await loadInitial();
        return;
      }
      _updateState(
        _state.copyWith(
          tracks: result.tracks,
          total: result.total,
          hasMore: result.tracks.length < result.total,
          isLoading: false,
        ),
      );
    } catch (e) {
      _updateState(_state.copyWith(error: e.toString(), isLoading: false));
    }
  }

  /// Загрузить следующую страницу
  Future<void> loadMore() async {
    if (_state.isLoading || !_state.hasMore) return;

    final requestFilters = _state.filters;
    _updateState(_state.copyWith(isLoading: true, clearError: true));

    try {
      final result = await _fetchTracks(
        skip: _state.tracks.length,
        take: _pageSize,
        filters: requestFilters,
      );
      if (_state.filters != requestFilters) {
        _updateState(_state.copyWith(isLoading: false));
        await loadInitial();
        return;
      }

      final newTracks = _sortTracksDesc([
        ..._state.tracks,
        ...result.tracks,
      ], _state.filters.sortBy);
      _updateState(
        _state.copyWith(
          tracks: newTracks,
          total: result.total,
          hasMore: newTracks.length < result.total,
          isLoading: false,
        ),
      );
    } catch (e) {
      _updateState(_state.copyWith(error: e.toString(), isLoading: false));
    }
  }

  /// Обновить фильтры и перезагрузить
  Future<void> updateFilters(TracksFilterParams newFilters) async {
    // Сохраняем новые фильтры
    _updateState(_state.copyWith(filters: newFilters));
    // Перезагружаем с новыми фильтрами
    await loadInitial();
  }

  /// Обновить список (pull-to-refresh)
  Future<void> refresh() async {
    await loadInitial();
  }

  /// Оптимистично удалить трек из локального стейта
  void removeTrackOptimistically(int trackId) {
    final updatedTracks = _state.tracks.where((t) => t.id != trackId).toList();
    _updateState(
      _state.copyWith(
        tracks: updatedTracks,
        total: _state.total > 0 ? _state.total - 1 : 0,
      ),
    );
  }

  Future<_TracksResult> _fetchTracks({
    required int skip,
    required int take,
    TracksFilterParams? filters,
  }) async {
    final requestFilters = filters ?? _state.filters;
    final queryParams = <String, dynamic>{
      'clientCode': requestFilters.clientCode,
      'take': take,
      'skip': skip,
      'sortBy': requestFilters.sortBy,
    };

    // Фильтр по статусу (код статуса из БД)
    if (requestFilters.statusCode != null &&
        requestFilters.statusCode!.isNotEmpty) {
      queryParams['status'] = requestFilters.statusCode;
    }

    if (requestFilters.assemblyStatusCode != null &&
        requestFilters.assemblyStatusCode!.isNotEmpty) {
      queryParams['assemblyStatus'] = requestFilters.assemblyStatusCode;
    }

    // Поиск
    if (requestFilters.search != null && requestFilters.search!.isNotEmpty) {
      queryParams['search'] = requestFilters.search;
    }

    // Фильтр по виду (сборки/одиночные)
    if (requestFilters.viewMode == 'groups') {
      // Треки в сборках - assemblyId не null
      queryParams['hasAssembly'] = 'true';
    } else if (requestFilters.viewMode == 'singles') {
      // Одиночные треки - без сборки
      queryParams['assemblyId'] = 'null';
    }

    if (requestFilters.productInfo != null &&
        requestFilters.productInfo!.isNotEmpty) {
      queryParams['productInfo'] = requestFilters.productInfo;
    }

    if (requestFilters.photoRequestStatus != null &&
        requestFilters.photoRequestStatus!.isNotEmpty) {
      queryParams['photoRequestStatus'] = requestFilters.photoRequestStatus;
    }

    if (requestFilters.questionStatus != null &&
        requestFilters.questionStatus!.isNotEmpty) {
      queryParams['questionStatus'] = requestFilters.questionStatus;
    }

    if (requestFilters.assemblyDeliveryInfo != null &&
        requestFilters.assemblyDeliveryInfo!.isNotEmpty) {
      queryParams['assemblyDeliveryInfo'] = requestFilters.assemblyDeliveryInfo;
    }

    debugPrint('Fetching tracks: $queryParams');

    final response = await _apiClient.get(
      '/tracks',
      queryParameters: queryParams,
    );

    if (response.statusCode == 200 && response.data != null) {
      final data = response.data as Map<String, dynamic>;
      final tracksJson = data['data'] as List<dynamic>? ?? [];
      final total = data['total'] as int? ?? 0;

      final tracks = tracksJson
          .map((json) => TrackItem.fromJson(json as Map<String, dynamic>))
          .toList();

      debugPrint('Fetched ${tracks.length} tracks, total: $total');

      return _TracksResult(
        tracks: _sortTracksDesc(tracks, requestFilters.sortBy),
        total: total,
      );
    }

    throw Exception('Failed to load tracks');
  }
}

class _TracksResult {
  final List<TrackItem> tracks;
  final int total;

  _TracksResult({required this.tracks, required this.total});
}

/// Провайдер для пагинированного списка треков
/// Ключ - clientCode, фильтры обновляются через updateFilters
final paginatedTracksProvider = Provider.autoDispose
    .family<PaginatedTracksNotifier, String>((ref, clientCode) {
      final notifier = PaginatedTracksNotifier(
        ref,
        TracksFilterParams(clientCode: clientCode),
      );
      ref.onDispose(notifier.dispose);
      return notifier;
    });

// ==================== Legacy Providers (for compatibility) ====================

/// Параметры для получения списка треков
class TracksListParams {
  final String clientCode;
  final String? status;
  final String? search;
  final String? assemblyId; // 'null' для треков без сборки
  final int take;
  final int skip;

  const TracksListParams({
    required this.clientCode,
    this.status,
    this.search,
    this.assemblyId,
    this.take = 100,
    this.skip = 0,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TracksListParams &&
          runtimeType == other.runtimeType &&
          clientCode == other.clientCode &&
          status == other.status &&
          search == other.search &&
          assemblyId == other.assemblyId &&
          take == other.take &&
          skip == other.skip;

  @override
  int get hashCode =>
      clientCode.hashCode ^
      status.hashCode ^
      search.hashCode ^
      assemblyId.hashCode ^
      take.hashCode ^
      skip.hashCode;
}

/// Провайдер для получения списка треков с параметрами
final tracksListProvider =
    FutureProvider.family<List<TrackItem>, TracksListParams>((
      ref,
      params,
    ) async {
      final apiClient = ref.read(apiClientProvider);

      try {
        final queryParams = <String, dynamic>{
          'clientCode': params.clientCode,
          'take': params.take,
          'skip': params.skip,
          'sortBy': 'createdAt',
        };

        if (params.status != null && params.status!.isNotEmpty) {
          queryParams['status'] = params.status;
        }
        if (params.search != null && params.search!.isNotEmpty) {
          queryParams['search'] = params.search;
        }
        if (params.assemblyId != null) {
          queryParams['assemblyId'] = params.assemblyId;
        }

        final response = await apiClient.get(
          '/tracks',
          queryParameters: queryParams,
        );

        if (response.statusCode == 200 && response.data != null) {
          final data = response.data as Map<String, dynamic>;
          final tracksJson = data['data'] as List<dynamic>? ?? [];

          final tracks = tracksJson
              .map((json) => TrackItem.fromJson(json as Map<String, dynamic>))
              .toList();

          return _sortTracksByCreatedAtDesc(tracks);
        }
        return [];
      } on DioException catch (e) {
        debugPrint('Error loading tracks: $e');
        return [];
      }
    });

/// Провайдер для получения списка треков по коду клиента (простой)
final tracksSimpleListProvider = FutureProvider.family<List<TrackItem>, String>(
  (ref, clientCode) async {
    final apiClient = ref.read(apiClientProvider);

    try {
      final response = await apiClient.get(
        '/tracks',
        queryParameters: {
          'clientCode': clientCode,
          'take': 100,
          'sortBy': 'createdAt',
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final tracksJson = data['data'] as List<dynamic>? ?? [];

        final tracks = tracksJson
            .map((json) => TrackItem.fromJson(json as Map<String, dynamic>))
            .toList();

        return _sortTracksByCreatedAtDesc(tracks);
      }
      return [];
    } on DioException catch (e) {
      debugPrint('Error loading tracks: $e');
      return [];
    }
  },
);

/// Провайдер для дайджеста - последние 10 треков отсортированные по дате создания
final tracksDigestProvider = FutureProvider.family<List<TrackItem>, String>((
  ref,
  clientCode,
) async {
  if (ref.watch(demoModeProvider)) return DemoData.tracks.take(10).toList();
  final apiClient = ref.read(apiClientProvider);

  try {
    final response = await apiClient.get(
      '/tracks',
      queryParameters: {
        'clientCode': clientCode,
        'take': 10,
        'sortBy': 'createdAt',
      },
    );

    if (response.statusCode == 200 && response.data != null) {
      final data = response.data as Map<String, dynamic>;
      final tracksJson = data['data'] as List<dynamic>? ?? [];

      final tracks = tracksJson
          .map((json) => TrackItem.fromJson(json as Map<String, dynamic>))
          .toList();

      return _sortTracksByCreatedAtDesc(tracks);
    }
    return [];
  } on DioException catch (e) {
    debugPrint('Error loading tracks digest: $e');
    return [];
  }
});

List<TrackItem> _sortTracksByCreatedAtDesc(List<TrackItem> tracks) {
  return _sortTracksDesc(tracks, 'createdAt');
}

List<TrackItem> _sortTracksDesc(List<TrackItem> tracks, String sortBy) {
  return [...tracks]..sort((a, b) {
    final aDate = sortBy == 'updatedAt' ? a.updatedAt : a.createdAt;
    final bDate = sortBy == 'updatedAt' ? b.updatedAt : b.createdAt;
    final byDate = bDate.compareTo(aDate);
    if (byDate != 0) return byDate;
    return (b.id ?? 0).compareTo(a.id ?? 0);
  });
}

MediaType _mediaTypeForFileName(String fileName) {
  final lower = fileName.toLowerCase();
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
    return MediaType('image', 'jpeg');
  }
  if (lower.endsWith('.png')) return MediaType('image', 'png');
  if (lower.endsWith('.gif')) return MediaType('image', 'gif');
  if (lower.endsWith('.webp')) return MediaType('image', 'webp');
  if (lower.endsWith('.heic')) return MediaType('image', 'heic');
  if (lower.endsWith('.heif')) return MediaType('image', 'heif');
  return MediaType('image', 'jpeg');
}

MediaType? _mediaTypeForMimeType(String? mimeType) {
  if (mimeType == null || mimeType.isEmpty || !mimeType.contains('/')) {
    return null;
  }
  final parts = mimeType.split('/');
  if (parts.length != 2 || parts[0].isEmpty || parts[1].isEmpty) return null;
  return MediaType(parts[0], parts[1]);
}

/// Провайдер количества треков для карточки на главном экране.
/// Считаются только треки в активной обработке: pending / in_warehouse / in_assembly.
final tracksCountProvider = FutureProvider.family<int, String>((
  ref,
  clientCode,
) async {
  if (ref.watch(demoModeProvider)) return DemoData.tracksCount;
  final apiClient = ref.read(apiClientProvider);

  try {
    final response = await apiClient.get(
      '/tracks',
      queryParameters: {
        'clientCode': clientCode,
        'take': 1,
        'statuses': 'pending,in_warehouse,in_assembly',
      },
    );

    if (response.statusCode == 200 && response.data != null) {
      final data = response.data as Map<String, dynamic>;
      return data['total'] as int? ?? 0;
    }
    return 0;
  } on DioException catch (e) {
    debugPrint('Error loading tracks count: $e');
    return 0;
  }
});

/// Количество треков, созданных за последние 7 дней.
final tracksWeeklyCountProvider = FutureProvider.family<int, String>((
  ref,
  clientCode,
) async {
  final weekStart = _weekStart();
  if (ref.watch(demoModeProvider)) {
    return DemoData.tracks
        .where((track) => !track.createdAt.isBefore(weekStart))
        .length;
  }
  final apiClient = ref.read(apiClientProvider);

  try {
    final response = await apiClient.get(
      '/tracks',
      queryParameters: {
        'clientCode': clientCode,
        'take': 1,
        'dateFrom': weekStart.toUtc().toIso8601String(),
        'sortBy': 'createdAt',
      },
    );

    if (response.statusCode == 200 && response.data != null) {
      final data = response.data as Map<String, dynamic>;
      return data['total'] as int? ?? 0;
    }
    return 0;
  } on DioException catch (e) {
    debugPrint('Error loading weekly tracks count: $e');
    return 0;
  }
});

DateTime _weekStart() => DateTime.now().subtract(const Duration(days: 7));

/// Провайдер для количества треков без сборки
final tracksWithoutAssemblyCountProvider = FutureProvider.family<int, String>((
  ref,
  clientCode,
) async {
  final apiClient = ref.read(apiClientProvider);

  try {
    final response = await apiClient.get(
      '/tracks',
      queryParameters: {
        'clientCode': clientCode,
        'assemblyId': 'null', // Треки без сборки
        'take': 1,
      },
    );

    if (response.statusCode == 200 && response.data != null) {
      final data = response.data as Map<String, dynamic>;
      return data['total'] as int? ?? 0;
    }
    return 0;
  } on DioException catch (e) {
    debugPrint('Error loading tracks without assembly count: $e');
    return 0;
  }
});

// ==================== API Mutations ====================

/// Сервис для API операций с треками
class TracksApiService {
  final Ref _ref;

  TracksApiService(this._ref);

  ApiClient get _apiClient => _ref.read(apiClientProvider);

  Future<TrackItem?> getTrackById(int trackId) async {
    try {
      final response = await _apiClient.get('/tracks/$trackId');

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final trackJson = data['data'] as Map<String, dynamic>?;
        if (trackJson == null) return null;
        return TrackItem.fromJson(trackJson);
      }
      return null;
    } on DioException catch (e) {
      debugPrint('Error loading track by id: $e');
      return null;
    }
  }

  Future<List<TrackItem>> fetchTracksForDeepLink({
    String? clientCode,
    String? assemblyId,
    String? search,
    int take = 200,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'take': take,
        'skip': 0,
        'sortBy': 'createdAt',
        if (clientCode != null && clientCode.isNotEmpty)
          'clientCode': clientCode,
        if (assemblyId != null && assemblyId.isNotEmpty)
          'assemblyId': assemblyId,
        if (search != null && search.isNotEmpty) 'search': search,
      };

      final response = await _apiClient.get(
        '/tracks',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final tracksJson = data['data'] as List<dynamic>? ?? const [];
        final tracks = tracksJson
            .map((json) => TrackItem.fromJson(json as Map<String, dynamic>))
            .toList();
        return _sortTracksByCreatedAtDesc(tracks);
      }
      return [];
    } on DioException catch (e) {
      debugPrint('Error loading tracks for deep link: $e');
      return [];
    }
  }

  /// Создать запрос фотоотчета
  Future<bool> createPhotoRequest({
    required int clientId,
    required int? clientCodeId,
    required int trackId,
    required String trackNumber,
    String? wish,
  }) async {
    try {
      debugPrint(
        'Creating photo request: clientId=$clientId, clientCodeId=$clientCodeId, trackId=$trackId, trackNumber=$trackNumber',
      );
      final response = await _apiClient.post(
        '/photo-requests',
        data: {
          'clientId': clientId,
          'clientCodeId': clientCodeId,
          'trackId': trackId,
          'trackNumber': trackNumber,
          'wish': wish,
        },
      );
      debugPrint('Photo request response: ${response.statusCode}');
      return response.statusCode == 200 || response.statusCode == 201;
    } on DioException catch (e) {
      debugPrint('Error creating photo request: $e');
      debugPrint('Response data: ${e.response?.data}');
      return false;
    }
  }

  /// Отменить запрос фотоотчета
  Future<bool> cancelPhotoRequest(int photoRequestId) async {
    try {
      debugPrint('Cancelling photo request: id=$photoRequestId');
      final response = await _apiClient.patch(
        '/photo-requests/$photoRequestId',
        data: {'status': 'cancelled'},
      );
      debugPrint('Cancel photo request response: ${response.statusCode}');
      return response.statusCode == 200;
    } on DioException catch (e) {
      debugPrint('Error cancelling photo request: $e');
      debugPrint('Response data: ${e.response?.data}');
      return false;
    }
  }

  /// Обновить пожелание к фотоотчету
  Future<bool> updatePhotoWish(int photoRequestId, String wish) async {
    try {
      debugPrint('Updating photo wish: id=$photoRequestId, wish=$wish');
      final response = await _apiClient.patch(
        '/photo-requests/$photoRequestId',
        data: {'wish': wish},
      );
      debugPrint('Update photo wish response: ${response.statusCode}');
      return response.statusCode == 200;
    } on DioException catch (e) {
      debugPrint('Error updating photo wish: $e');
      debugPrint('Response data: ${e.response?.data}');
      return false;
    }
  }

  /// Создать вопрос по треку
  Future<bool> createTrackQuestion({
    required int clientId,
    required int? clientCodeId,
    required int trackId,
    required String trackNumber,
    required String question,
  }) async {
    try {
      debugPrint(
        'Creating track question: clientId=$clientId, clientCodeId=$clientCodeId, trackId=$trackId, trackNumber=$trackNumber',
      );
      final response = await _apiClient.post(
        '/track-questions',
        data: {
          'clientId': clientId,
          'clientCodeId': clientCodeId,
          'trackId': trackId,
          'trackNumber': trackNumber,
          'question': question,
        },
      );
      debugPrint('Track question response: ${response.statusCode}');
      return response.statusCode == 200 || response.statusCode == 201;
    } on DioException catch (e) {
      debugPrint('Error creating track question: $e');
      debugPrint('Response data: ${e.response?.data}');
      return false;
    }
  }

  /// Оформить возврат трека
  Future<bool> createTrackReturn({
    required int trackId,
    required String returnCode,
    String? screenshotUrl,
    String? note,
  }) async {
    try {
      debugPrint(
        'Creating track return: trackId=$trackId, returnCode=$returnCode',
      );
      final response = await _apiClient.post(
        '/client/tracks/$trackId/return',
        data: {
          'returnCode': returnCode,
          if (screenshotUrl != null) 'screenshotUrl': screenshotUrl,
          if (note != null && note.isNotEmpty) 'note': note,
        },
      );
      debugPrint('Track return response: ${response.statusCode}');
      return response.statusCode == 200 || response.statusCode == 201;
    } on DioException catch (e) {
      debugPrint('Error creating track return: $e');
      debugPrint('Response data: ${e.response?.data}');
      return false;
    }
  }

  /// Отменить вопрос
  Future<bool> cancelTrackQuestion(int questionId) async {
    try {
      debugPrint('Cancelling track question: id=$questionId');
      final response = await _apiClient.patch(
        '/track-questions/$questionId',
        data: {'status': 'cancelled'},
      );
      debugPrint('Cancel track question response: ${response.statusCode}');
      return response.statusCode == 200;
    } on DioException catch (e) {
      debugPrint('Error cancelling track question: $e');
      debugPrint('Response data: ${e.response?.data}');
      return false;
    }
  }

  /// Обновить информацию о товаре
  Future<bool> updateProductInfo({
    required int trackId,
    required String productName,
    required int quantity,
    File? imageFile,
    String? imageUrl,
  }) async {
    try {
      // Сначала загружаем изображение если есть файл
      String? uploadedImageUrl = imageUrl;
      if (imageFile != null) {
        final uploadResponse = await _uploadProductInfoImage(
          trackId,
          imageFile,
        );
        uploadedImageUrl = uploadResponse;
      }

      // Используем PUT /api/tracks/{id} с productInfo в теле
      final response = await _apiClient.put(
        '/tracks/$trackId',
        data: {
          'productInfo': {
            'name': productName,
            'quantity': quantity,
            if (uploadedImageUrl != null) 'imageUrl': uploadedImageUrl,
          },
        },
      );

      debugPrint('updateProductInfo response: ${response.statusCode}');
      return response.statusCode == 200 || response.statusCode == 201;
    } on DioException catch (e) {
      debugPrint('Error updating product info: $e');
      debugPrint('Response data: ${e.response?.data}');
      return false;
    }
  }

  /// Загрузить изображение товара и привязать его к треку.
  Future<String?> _uploadProductInfoImage(int trackId, File file) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          file.path,
          filename: file.path.split(Platform.pathSeparator).last,
          contentType: _mediaTypeForFileName(file.path),
        ),
      });

      final response = await _apiClient.post(
        '/tracks/$trackId/product-info-image',
        data: formData,
      );

      debugPrint('Upload product info image response: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data as Map<String, dynamic>;
        return data['url'] as String?;
      }
      return null;
    } on DioException catch (e) {
      debugPrint('Error uploading product info image: $e');
      debugPrint('Response data: ${e.response?.data}');
      return null;
    }
  }

  /// Загрузить изображение товара из байтов (для Web платформы).
  Future<String?> uploadProductInfoImageFromBytes(
    int trackId,
    Uint8List bytes,
    String fileName, {
    String? mimeType,
  }) async {
    try {
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          bytes,
          filename: fileName,
          contentType:
              _mediaTypeForMimeType(mimeType) ??
              _mediaTypeForFileName(fileName),
        ),
      });

      final response = await _apiClient.post(
        '/tracks/$trackId/product-info-image',
        data: formData,
      );

      debugPrint('Upload product info image response: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data as Map<String, dynamic>;
        return data['url'] as String?;
      }
      return null;
    } on DioException catch (e) {
      debugPrint('Error uploading product info image: $e');
      debugPrint('Response data: ${e.response?.data}');
      return null;
    }
  }

  /// Добавить/обновить комментарий к треку (поле note)
  Future<bool> addTrackComment({
    required int trackId,
    required String comment,
  }) async {
    try {
      final response = await _apiClient.patch(
        '/tracks/$trackId',
        data: {'note': comment},
      );
      return response.statusCode == 200;
    } on DioException catch (e) {
      debugPrint('Error adding track comment: $e');
      return false;
    }
  }

  /// Удалить трек (только в статусе «В ожидании»)
  Future<bool> deleteTrack(int trackId) async {
    try {
      final response = await _apiClient.delete('/tracks/$trackId');
      final code = response.statusCode ?? 0;
      return code >= 200 && code < 300;
    } on DioException catch (e) {
      debugPrint('Error deleting track: $e');
      return false;
    }
  }
}

/// Провайдер для API сервиса треков
final tracksApiServiceProvider = Provider<TracksApiService>((ref) {
  return TracksApiService(ref);
});
