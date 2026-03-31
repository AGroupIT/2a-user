import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/demo_data.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/demo_mode_provider.dart';
import '../../../core/services/websocket_provider.dart';
import '../domain/photo_item.dart';

/// Провайдер для получения общего количества фото по коду клиента
final photosTotalCountProvider = FutureProvider.autoDispose.family<int, String>((ref, clientCode) async {
  if (ref.watch(demoModeProvider)) return DemoData.photosCount;
  final apiClient = ref.read(apiClientProvider);
  
  try {
    final response = await apiClient.get(
      '/photos',
      queryParameters: {
        'clientCode': clientCode,
        'source': 'photoRequest', // Только фото из запросов фотоотчётов
        'take': 1,
      },
    );
    
    if (response.statusCode == 200 && response.data != null) {
      final data = response.data as Map<String, dynamic>;
      return data['total'] as int? ?? 0;
    }
    return 0;
  } on DioException catch (e) {
    debugPrint('Error loading photos count: $e');
    return 0;
  }
});

/// Провайдер для получения последних фото по коду клиента (только из фотоотчётов)
final photosRecentProvider = FutureProvider.autoDispose.family<List<PhotoItem>, ({String clientCode, int limit})>((ref, params) async {
  if (ref.watch(demoModeProvider)) return DemoData.photos.take(params.limit).toList();
  final apiClient = ref.read(apiClientProvider);
  
  try {
    final response = await apiClient.get(
      '/photos',
      queryParameters: {
        'clientCode': params.clientCode,
        'source': 'photoRequest', // Только фото из запросов фотоотчётов
        'take': params.limit,
      },
    );
    
    if (response.statusCode == 200 && response.data != null) {
      final data = response.data as Map<String, dynamic>;
      final photosJson = data['data'] as List<dynamic>? ?? [];
      
      return photosJson.map((json) => PhotoItem.fromJson(json as Map<String, dynamic>)).toList();
    }
    return [];
  } on DioException catch (e) {
    debugPrint('Error loading recent photos: $e');
    return [];
  }
});

/// Провайдер для получения дней с фото
final photosDaysProvider = FutureProvider.autoDispose.family<List<String>, ({String clientCode, int month, int year})>((ref, params) async {
  if (ref.watch(demoModeProvider)) {
    // Дни, в которые есть демо-фотографии за нужный месяц
    return DemoData.photos
        .where((p) => p.date.month == params.month && p.date.year == params.year)
        .map((p) => p.date.day.toString())
        .toSet()
        .toList();
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
  } on DioException catch (e) {
    debugPrint('Error loading photo days: $e');
    return [];
  }
});

/// Провайдер для получения фото по дате
final photosByDateProvider = FutureProvider.autoDispose.family<List<PhotoItem>, ({String clientCode, String date})>((ref, params) async {
  if (ref.watch(demoModeProvider)) {
    final d = DateTime.tryParse(params.date);
    if (d == null) return DemoData.photos;
    return DemoData.photos
        .where((p) => p.date.year == d.year && p.date.month == d.month && p.date.day == d.day)
        .toList();
  }
  final apiClient = ref.read(apiClientProvider);
  
  try {
    final response = await apiClient.get(
      '/photos',
      queryParameters: {
        'clientCode': params.clientCode,
        'source': 'photoRequest', // Только фото из запросов фотоотчётов
        'date': params.date,
        'take': 100,
      },
    );
    
    if (response.statusCode == 200 && response.data != null) {
      final data = response.data as Map<String, dynamic>;
      final photosJson = data['data'] as List<dynamic>? ?? [];
      
      return photosJson.map((json) => PhotoItem.fromJson(json as Map<String, dynamic>)).toList();
    }
    return [];
  } on DioException catch (e) {
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
  final String date;
  final String clientCode;

  const PaginatedPhotosState({
    this.photos = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.total = 0,
    this.error,
    required this.date,
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
  static const int _pageSize = 30;
  static const _photoTypes = {'photo_requests'};

  final Ref _ref;
  PaginatedPhotosState _state;
  PaginatedPhotosState get state => _state;

  final List<void Function()> _listeners = [];
  StreamSubscription? _deltaSub;
  StreamSubscription? _reconnectSub;
  Timer? _refreshTimer;

  PaginatedPhotosNotifier(this._ref, String clientCode, String date)
      : _state = PaginatedPhotosState(clientCode: clientCode, date: date) {
    // Delta sync is the primary update mechanism.
    // data_changed broadcast is not used to avoid full page reloads
    // that reset scroll position and pagination.
    final wsService = _ref.read(webSocketServiceProvider);
    _deltaSub = wsService.deltas
        .where((delta) => _photoTypes.contains(delta.type))
        .listen((_) => _debouncedRefresh());
    _reconnectSub = wsService.reconnected
        .listen((_) => _debouncedRefresh());

    loadInitial();
  }

  void _debouncedRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer(const Duration(milliseconds: 500), () {
      debugPrint('[PaginatedPhotos] WS event — silent refresh for ${_state.date}');
      _silentRefresh();
    });
  }

  /// Фоновое обновление без сброса скролла и пагинации.
  /// Перезагружает столько же фото, сколько уже подгружено.
  Future<void> _silentRefresh() async {
    try {
      final currentCount = _state.photos.length;
      final take = currentCount > _pageSize ? currentCount : _pageSize;
      final response = await _apiClient.get('/photos', queryParameters: {
        'clientCode': _state.clientCode,
        'source': 'photoRequest',
        'date': _state.date,
        'take': take,
        'skip': 0,
      });
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final json = data['data'] as List<dynamic>? ?? [];
        final total = data['total'] as int? ?? 0;
        final photos = json.map((j) => PhotoItem.fromJson(j as Map<String, dynamic>)).toList();
        _update(_state.copyWith(
          photos: photos,
          total: total,
          hasMore: photos.length < total,
        ));
      }
    } catch (e) {
      debugPrint('[PaginatedPhotos] Silent refresh error: $e');
    }
  }

  void dispose() {
    _deltaSub?.cancel();
    _reconnectSub?.cancel();
    _refreshTimer?.cancel();
  }

  ApiClient get _apiClient => _ref.read(apiClientProvider);

  void addListener(void Function() l) => _listeners.add(l);
  void removeListener(void Function() l) => _listeners.remove(l);
  void _notify() { for (final l in _listeners) { l(); } }

  void _update(PaginatedPhotosState s) { _state = s; _notify(); }

  Future<void> loadInitial() async {
    if (_ref.read(demoModeProvider)) {
      final d = DateTime.tryParse(_state.date);
      final demoPhotos = d == null
          ? DemoData.photos
          : DemoData.photos
              .where((p) => p.date.year == d.year && p.date.month == d.month && p.date.day == d.day)
              .toList();
      _update(_state.copyWith(photos: demoPhotos, total: demoPhotos.length, hasMore: false, isLoading: false));
      return;
    }
    _update(_state.copyWith(isLoading: true, photos: [], hasMore: true, clearError: true));
    try {
      final result = await _fetch(skip: 0);
      _update(_state.copyWith(
        photos: result.photos,
        total: result.total,
        hasMore: result.photos.length >= _pageSize,
        isLoading: false,
      ));
    } catch (e) {
      _update(_state.copyWith(error: e.toString(), isLoading: false));
    }
  }

  Future<void> loadMore() async {
    if (_state.isLoading || !_state.hasMore) return;
    _update(_state.copyWith(isLoading: true));
    try {
      final result = await _fetch(skip: _state.photos.length);
      _update(_state.copyWith(
        photos: [..._state.photos, ...result.photos],
        total: result.total,
        hasMore: result.photos.length >= _pageSize,
        isLoading: false,
      ));
    } catch (e) {
      _update(_state.copyWith(error: e.toString(), isLoading: false));
    }
  }

  Future<({List<PhotoItem> photos, int total})> _fetch({required int skip}) async {
    final response = await _apiClient.get('/photos', queryParameters: {
      'clientCode': _state.clientCode,
      'source': 'photoRequest',
      'date': _state.date,
      'take': _pageSize,
      'skip': skip,
    });

    if (response.statusCode == 200 && response.data != null) {
      final data = response.data as Map<String, dynamic>;
      final json = data['data'] as List<dynamic>? ?? [];
      final total = data['total'] as int? ?? 0;
      final photos = json.map((j) => PhotoItem.fromJson(j as Map<String, dynamic>)).toList();
      return (photos: photos, total: total);
    }
    throw Exception('Failed to load photos');
  }
}

final paginatedPhotosByDateProvider = Provider.family<
    PaginatedPhotosNotifier,
    ({String clientCode, String date})>((ref, params) {
  final notifier = PaginatedPhotosNotifier(ref, params.clientCode, params.date);
  ref.onDispose(() => notifier.dispose());
  return notifier;
});

/// Провайдер для поиска фото
final photosSearchProvider = FutureProvider.family<List<PhotoItem>, ({String clientCode, String query})>((ref, params) async {
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
      
      return photosJson.map((json) => PhotoItem.fromJson(json as Map<String, dynamic>)).toList();
    }
    return [];
  } on DioException catch (e) {
    debugPrint('Error searching photos: $e');
    return [];
  }
});
