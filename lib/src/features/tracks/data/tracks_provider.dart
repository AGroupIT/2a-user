import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
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

/// Провайдер для получения статусов треков из БД
final trackStatusesProvider = FutureProvider<List<TrackStatus>>((ref) async {
  final apiClient = ref.read(apiClientProvider);
  
  try {
    final response = await apiClient.get(
      '/statuses',
      queryParameters: {
        'type': 'track',
        'activeOnly': 'true',
      },
    );
    
    if (response.statusCode == 200 && response.data != null) {
      final data = response.data as Map<String, dynamic>;
      final statusesJson = data['data'] as List<dynamic>? ?? [];
      
      return statusesJson
          .map((json) => TrackStatus.fromJson(json as Map<String, dynamic>))
          .toList();
    }
    return [];
  } on DioException catch (e) {
    debugPrint('Error loading track statuses: $e');
    return [];
  }
});

// ==================== Paginated Tracks State ====================

/// Параметры фильтрации треков
class TracksFilterParams {
  final String clientCode;
  final String? statusCode; // код статуса из БД
  final String? search;
  final String? viewMode; // 'all', 'groups', 'singles'

  const TracksFilterParams({
    required this.clientCode,
    this.statusCode,
    this.search,
    this.viewMode,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TracksFilterParams &&
          runtimeType == other.runtimeType &&
          clientCode == other.clientCode &&
          statusCode == other.statusCode &&
          search == other.search &&
          viewMode == other.viewMode;

  @override
  int get hashCode =>
      clientCode.hashCode ^
      statusCode.hashCode ^
      search.hashCode ^
      viewMode.hashCode;

  TracksFilterParams copyWith({
    String? clientCode,
    String? statusCode,
    String? search,
    String? viewMode,
    bool clearStatus = false,
    bool clearSearch = false,
  }) {
    return TracksFilterParams(
      clientCode: clientCode ?? this.clientCode,
      statusCode: clearStatus ? null : (statusCode ?? this.statusCode),
      search: clearSearch ? null : (search ?? this.search),
      viewMode: viewMode ?? this.viewMode,
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
  static const int _pageSize = 100;
  
  PaginatedTracksState _state;
  PaginatedTracksState get state => _state;
  
  final List<void Function()> _listeners = [];

  PaginatedTracksNotifier(this._ref, TracksFilterParams initialFilters)
      : _state = PaginatedTracksState(filters: initialFilters) {
    // Загружаем начальные данные при создании
    loadInitial();
  }

  ApiClient get _apiClient => _ref.read(apiClientProvider);

  void addListener(void Function() listener) {
    _listeners.add(listener);
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
    if (_state.isLoading) return;

    // При silent refresh не показываем loader и не очищаем текущие данные
    if (silent) {
      try {
        final result = await _fetchTracks(skip: 0, take: _pageSize);
        
        // Обновляем только если данные изменились
        if (_hasDataChanged(result.tracks)) {
          _updateState(_state.copyWith(
            tracks: result.tracks,
            total: result.total,
            hasMore: result.tracks.length >= _pageSize,
          ));
        }
      } catch (e) {
        // При silent refresh ошибки не показываем пользователю
        debugPrint('Silent refresh error: $e');
      }
      return;
    }

    // Обычная загрузка с показом индикатора
    _updateState(_state.copyWith(
      isLoading: true,
      clearError: true,
      tracks: [],
      hasMore: true,
    ));

    try {
      final result = await _fetchTracks(skip: 0, take: _pageSize);
      _updateState(_state.copyWith(
        tracks: result.tracks,
        total: result.total,
        hasMore: result.tracks.length >= _pageSize,
        isLoading: false,
      ));
    } catch (e) {
      _updateState(_state.copyWith(
        error: e.toString(),
        isLoading: false,
      ));
    }
  }
  
  /// Проверяет, изменились ли данные
  bool _hasDataChanged(List<TrackItem> newTracks) {
    if (_state.tracks.length != newTracks.length) return true;
    
    // Сравниваем ID и даты обновления
    for (var i = 0; i < _state.tracks.length; i++) {
      final oldTrack = _state.tracks[i];
      final newTrack = newTracks[i];
      
      if (oldTrack.id != newTrack.id || 
          oldTrack.updatedAt != newTrack.updatedAt ||
          oldTrack.status != newTrack.status) {
        return true;
      }
    }
    
    return false;
  }

  /// Загрузить следующую страницу
  Future<void> loadMore() async {
    if (_state.isLoading || !_state.hasMore) return;

    _updateState(_state.copyWith(isLoading: true));

    try {
      final result = await _fetchTracks(
        skip: _state.tracks.length,
        take: _pageSize,
      );

      final newTracks = [..._state.tracks, ...result.tracks];
      _updateState(_state.copyWith(
        tracks: newTracks,
        total: result.total,
        hasMore: result.tracks.length >= _pageSize,
        isLoading: false,
      ));
    } catch (e) {
      _updateState(_state.copyWith(
        error: e.toString(),
        isLoading: false,
      ));
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

  Future<_TracksResult> _fetchTracks({
    required int skip,
    required int take,
  }) async {
    final queryParams = <String, dynamic>{
      'clientCode': _state.filters.clientCode,
      'take': take,
      'skip': skip,
      'sortBy': 'updatedAt',
    };

    // Фильтр по статусу (код статуса из БД)
    if (_state.filters.statusCode != null && 
        _state.filters.statusCode!.isNotEmpty) {
      queryParams['status'] = _state.filters.statusCode;
    }

    // Поиск
    if (_state.filters.search != null && _state.filters.search!.isNotEmpty) {
      queryParams['search'] = _state.filters.search;
    }

    // Фильтр по виду (сборки/одиночные)
    if (_state.filters.viewMode == 'groups') {
      // Треки в сборках - assemblyId не null
      queryParams['hasAssembly'] = 'true';
    } else if (_state.filters.viewMode == 'singles') {
      // Одиночные треки - без сборки
      queryParams['assemblyId'] = 'null';
    }
    
    debugPrint('Fetching tracks: $queryParams');

    final response = await _apiClient.get('/tracks', queryParameters: queryParams);

    if (response.statusCode == 200 && response.data != null) {
      final data = response.data as Map<String, dynamic>;
      final tracksJson = data['data'] as List<dynamic>? ?? [];
      final total = data['total'] as int? ?? 0;

      final tracks = tracksJson
          .map((json) => TrackItem.fromJson(json as Map<String, dynamic>))
          .toList();
      
      debugPrint('Fetched ${tracks.length} tracks, total: $total');

      return _TracksResult(tracks: tracks, total: total);
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
final paginatedTracksProvider = Provider.family<
    PaginatedTracksNotifier, String>(
  (ref, clientCode) => PaginatedTracksNotifier(ref, TracksFilterParams(clientCode: clientCode)),
);

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
final tracksListProvider = FutureProvider.family<List<TrackItem>, TracksListParams>((ref, params) async {
  final apiClient = ref.read(apiClientProvider);
  
  try {
    final queryParams = <String, dynamic>{
      'clientCode': params.clientCode,
      'take': params.take,
      'skip': params.skip,
      'sortBy': 'updatedAt',
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
    
    final response = await apiClient.get('/tracks', queryParameters: queryParams);
    
    if (response.statusCode == 200 && response.data != null) {
      final data = response.data as Map<String, dynamic>;
      final tracksJson = data['data'] as List<dynamic>? ?? [];
      
      return tracksJson.map((json) => TrackItem.fromJson(json as Map<String, dynamic>)).toList();
    }
    return [];
  } on DioException catch (e) {
    debugPrint('Error loading tracks: $e');
    return [];
  }
});

/// Провайдер для получения списка треков по коду клиента (простой)
final tracksSimpleListProvider = FutureProvider.family<List<TrackItem>, String>((ref, clientCode) async {
  final apiClient = ref.read(apiClientProvider);
  
  try {
    final response = await apiClient.get(
      '/tracks',
      queryParameters: {
        'clientCode': clientCode,
        'take': 100,
        'sortBy': 'updatedAt',
      },
    );
    
    if (response.statusCode == 200 && response.data != null) {
      final data = response.data as Map<String, dynamic>;
      final tracksJson = data['data'] as List<dynamic>? ?? [];
      
      return tracksJson.map((json) => TrackItem.fromJson(json as Map<String, dynamic>)).toList();
    }
    return [];
  } on DioException catch (e) {
    debugPrint('Error loading tracks: $e');
    return [];
  }
});

/// Провайдер для дайджеста - последние 10 треков отсортированные по дате изменения
final tracksDigestProvider = FutureProvider.family<List<TrackItem>, String>((ref, clientCode) async {
  final apiClient = ref.read(apiClientProvider);
  
  try {
    final response = await apiClient.get(
      '/tracks',
      queryParameters: {
        'clientCode': clientCode,
        'take': 10,
        'sortBy': 'updatedAt',
      },
    );
    
    if (response.statusCode == 200 && response.data != null) {
      final data = response.data as Map<String, dynamic>;
      final tracksJson = data['data'] as List<dynamic>? ?? [];
      
      return tracksJson.map((json) => TrackItem.fromJson(json as Map<String, dynamic>)).toList();
    }
    return [];
  } on DioException catch (e) {
    debugPrint('Error loading tracks digest: $e');
    return [];
  }
});

/// Провайдер для общего количества треков
final tracksCountProvider = FutureProvider.family<int, String>((ref, clientCode) async {
  final apiClient = ref.read(apiClientProvider);
  
  try {
    final response = await apiClient.get(
      '/tracks',
      queryParameters: {
        'clientCode': clientCode,
        'take': 1,
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

/// Провайдер для количества треков без сборки
final tracksWithoutAssemblyCountProvider = FutureProvider.family<int, String>((ref, clientCode) async {
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
  
  /// Создать запрос фотоотчета
  Future<bool> createPhotoRequest({
    required int clientId,
    required int? clientCodeId,
    required int trackId,
    required String trackNumber,
    String? wish,
  }) async {
    try {
      debugPrint('Creating photo request: clientId=$clientId, clientCodeId=$clientCodeId, trackId=$trackId, trackNumber=$trackNumber');
      final response = await _apiClient.post('/photo-requests', data: {
        'clientId': clientId,
        'clientCodeId': clientCodeId,
        'trackId': trackId,
        'trackNumber': trackNumber,
        'wish': wish,
      });
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
      final response = await _apiClient.patch('/photo-requests/$photoRequestId', data: {
        'status': 'cancelled',
      });
      debugPrint('Cancel photo request response: ${response.statusCode}');
      return response.statusCode == 200;
    } on DioException catch (e) {
      debugPrint('Error cancelling photo request: $e');
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
      debugPrint('Creating track question: clientId=$clientId, clientCodeId=$clientCodeId, trackId=$trackId, trackNumber=$trackNumber');
      final response = await _apiClient.post('/track-questions', data: {
        'clientId': clientId,
        'clientCodeId': clientCodeId,
        'trackId': trackId,
        'trackNumber': trackNumber,
        'question': question,
      });
      debugPrint('Track question response: ${response.statusCode}');
      return response.statusCode == 200 || response.statusCode == 201;
    } on DioException catch (e) {
      debugPrint('Error creating track question: $e');
      debugPrint('Response data: ${e.response?.data}');
      return false;
    }
  }
  
  /// Отменить вопрос
  Future<bool> cancelTrackQuestion(int questionId) async {
    try {
      debugPrint('Cancelling track question: id=$questionId');
      final response = await _apiClient.patch('/track-questions/$questionId', data: {
        'status': 'cancelled',
      });
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
  }) async {
    try {
      // Сначала загружаем изображение если есть
      String? imageUrl;
      if (imageFile != null) {
        final uploadResponse = await _uploadImage(imageFile, 'product-info');
        imageUrl = uploadResponse;
      }
      
      // Используем PUT /api/tracks/{id} с productInfo в теле
      final response = await _apiClient.put('/tracks/$trackId', data: {
        'productInfo': {
          'name': productName,
          'quantity': quantity,
          if (imageUrl != null) 'imageUrl': imageUrl,
        },
      });
      
      debugPrint('updateProductInfo response: ${response.statusCode}');
      return response.statusCode == 200 || response.statusCode == 201;
    } on DioException catch (e) {
      debugPrint('Error updating product info: $e');
      debugPrint('Response data: ${e.response?.data}');
      return false;
    }
  }
  
  /// Загрузить изображение
  /// [type] - тип загружаемого изображения: 'product-info', 'general', etc.
  Future<String?> _uploadImage(File file, [String type = 'general']) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          file.path,
          filename: file.path.split(Platform.pathSeparator).last,
        ),
        'type': type,
      });
      
      final response = await _apiClient.post('/photos/upload', data: formData);
      
      debugPrint('Upload image response: ${response.statusCode}');
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data as Map<String, dynamic>;
        return data['url'] as String?;
      }
      return null;
    } on DioException catch (e) {
      debugPrint('Error uploading image: $e');
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
      final response = await _apiClient.patch('/tracks/$trackId', data: {
        'note': comment,
      });
      return response.statusCode == 200;
    } on DioException catch (e) {
      debugPrint('Error adding track comment: $e');
      return false;
    }
  }
}

/// Провайдер для API сервиса треков
final tracksApiServiceProvider = Provider<TracksApiService>((ref) {
  return TracksApiService(ref);
});
