import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twoalogistic_shared/twoalogistic_shared.dart';
import 'package:twoalogisticcabineuser/src/core/network/api_client.dart';
import 'package:twoalogisticcabineuser/src/core/services/websocket_provider.dart';
import 'package:twoalogisticcabineuser/src/features/photos/data/photos_provider.dart';
import 'package:twoalogisticcabineuser/src/features/tracks/data/tracks_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Pagination silent refresh', () {
    test(
      'tracks keep loaded pages when silent refresh finishes late',
      () async {
        final apiClient = _TracksRaceApiClient();
        final ws = _FakeWebSocketService();
        final container = ProviderContainer(
          overrides: [
            apiClientProvider.overrideWithValue(apiClient),
            webSocketServiceProvider.overrideWithValue(ws),
          ],
        );
        addTearDown(container.dispose);
        addTearDown(ws.dispose);

        final provider = paginatedTracksProvider('2A-TEST');
        final subscription = container.listen<PaginatedTracksNotifier>(
          provider,
          (_, _) {},
          fireImmediately: true,
        );
        addTearDown(subscription.close);

        final notifier = container.read(provider);
        await _waitUntil(() => notifier.state.tracks.length == 50);

        final silentRefresh = notifier.loadInitial(silent: true);
        await _waitUntil(() => apiClient.silentRefreshRequested);

        final loadMore = notifier.loadMore();
        await _waitUntil(() => apiClient.loadMoreRequested);

        apiClient.completeLoadMore();
        await loadMore;
        expect(notifier.state.tracks.length, 75);
        expect(notifier.state.hasMore, isFalse);

        apiClient.completeSilentRefresh();
        await silentRefresh;

        expect(notifier.state.tracks.length, 75);
        expect(notifier.state.hasMore, isFalse);
      },
    );

    test(
      'photos keep loaded pages when silent refresh finishes late',
      () async {
        final apiClient = _PhotosRaceApiClient();
        final ws = _FakeWebSocketService();
        final container = ProviderContainer(
          overrides: [
            apiClientProvider.overrideWithValue(apiClient),
            webSocketServiceProvider.overrideWithValue(ws),
          ],
        );
        addTearDown(container.dispose);
        addTearDown(ws.dispose);

        final provider = paginatedPhotosProvider('2A-TEST');
        final subscription = container.listen<PaginatedPhotosNotifier>(
          provider,
          (_, _) {},
          fireImmediately: true,
        );
        addTearDown(subscription.close);

        final notifier = container.read(provider);
        await _waitUntil(() => notifier.state.photos.length == 12);

        ws.emitDelta('tracks');
        await _waitUntil(() => apiClient.silentRefreshRequested);

        final loadMore = notifier.loadMore();
        await _waitUntil(() => apiClient.loadMoreRequested);

        apiClient.completeLoadMore();
        await loadMore;
        expect(notifier.state.photos.length, 24);
        expect(notifier.state.hasMore, isFalse);

        apiClient.completeSilentRefresh();
        await _waitUntil(() => apiClient.silentRefreshCompleted);

        expect(notifier.state.photos.length, 24);
        expect(notifier.state.hasMore, isFalse);
      },
    );
  });
}

Future<void> _waitUntil(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 2),
}) async {
  final stopwatch = Stopwatch()..start();
  while (stopwatch.elapsed < timeout) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('Condition was not met in time');
}

class _TracksRaceApiClient extends ApiClient {
  int _firstPageRequests = 0;
  bool silentRefreshRequested = false;
  bool silentRefreshCompleted = false;
  bool loadMoreRequested = false;

  final _silentRefresh = Completer<Response<dynamic>>();
  final _loadMore = Completer<Response<dynamic>>();

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    if (path != '/tracks') {
      throw StateError('Unexpected path: $path');
    }

    final skip = queryParameters?['skip'] as int?;
    final take = queryParameters?['take'] as int?;

    if (skip == 0 && take == 50) {
      _firstPageRequests += 1;
      if (_firstPageRequests == 1) {
        return _response<T>(path, _tracksPayload(1, 50, total: 75));
      }
      silentRefreshRequested = true;
      final response = await _silentRefresh.future;
      silentRefreshCompleted = true;
      return _castResponse<T>(response);
    }

    if (skip == 50 && take == 50) {
      loadMoreRequested = true;
      return _castResponse<T>(await _loadMore.future);
    }

    throw StateError('Unexpected tracks query: $queryParameters');
  }

  void completeSilentRefresh() {
    _silentRefresh.complete(
      _response<dynamic>('/tracks', _tracksPayload(1, 50, total: 75)),
    );
  }

  void completeLoadMore() {
    _loadMore.complete(
      _response<dynamic>('/tracks', _tracksPayload(51, 75, total: 75)),
    );
  }
}

class _PhotosRaceApiClient extends ApiClient {
  int _firstPageRequests = 0;
  bool silentRefreshRequested = false;
  bool silentRefreshCompleted = false;
  bool loadMoreRequested = false;

  final _silentRefresh = Completer<Response<dynamic>>();
  final _loadMore = Completer<Response<dynamic>>();

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    if (path != '/photos') {
      throw StateError('Unexpected path: $path');
    }

    final skip = queryParameters?['skip'] as int?;
    final take = queryParameters?['take'] as int?;

    if (skip == 0 && take == 12) {
      _firstPageRequests += 1;
      if (_firstPageRequests == 1) {
        return _response<T>(path, _photosPayload(1, 12, total: 24));
      }
      silentRefreshRequested = true;
      final response = await _silentRefresh.future;
      silentRefreshCompleted = true;
      return _castResponse<T>(response);
    }

    if (skip == 12 && take == 12) {
      loadMoreRequested = true;
      return _castResponse<T>(await _loadMore.future);
    }

    throw StateError('Unexpected photos query: $queryParameters');
  }

  void completeSilentRefresh() {
    _silentRefresh.complete(
      _response<dynamic>('/photos', _photosPayload(1, 12, total: 24)),
    );
  }

  void completeLoadMore() {
    _loadMore.complete(
      _response<dynamic>('/photos', _photosPayload(13, 24, total: 24)),
    );
  }
}

class _FakeWebSocketService extends WebSocketService {
  _FakeWebSocketService() : super(serverUrl: 'http://localhost');

  final _deltas = StreamController<DeltaEvent>.broadcast();
  final _dataChanged = StreamController<Map<String, dynamic>>.broadcast();
  final _reconnected = StreamController<void>.broadcast();

  @override
  Stream<DeltaEvent> get deltas => _deltas.stream;

  @override
  Stream<Map<String, dynamic>> get dataChanged => _dataChanged.stream;

  @override
  Stream<void> get reconnected => _reconnected.stream;

  void emitDelta(String type) {
    _deltas.add(
      DeltaEvent(
        type: type,
        action: 'updated',
        id: '1',
        timestamp: DateTime.now(),
      ),
    );
  }

  @override
  void dispose() {
    _deltas.close();
    _dataChanged.close();
    _reconnected.close();
  }
}

Response<T> _response<T>(String path, Map<String, dynamic> data) {
  return Response<T>(
    data: data as T,
    statusCode: 200,
    requestOptions: RequestOptions(path: path),
  );
}

Response<T> _castResponse<T>(Response<dynamic> response) {
  return Response<T>(
    data: response.data as T,
    statusCode: response.statusCode,
    requestOptions: response.requestOptions,
  );
}

Map<String, dynamic> _tracksPayload(
  int startId,
  int endId, {
  required int total,
}) {
  return {
    'data': [
      for (var id = startId; id <= endId; id++)
        {
          'id': id,
          'trackNumber': 'TRK$id',
          'status': 'pending',
          'createdAt': DateTime(2026, 1, 1, 0, id).toIso8601String(),
          'updatedAt': DateTime(2026, 1, 1, 0, id).toIso8601String(),
          'photos': <dynamic>[],
          'productInfo': <dynamic>[],
          'photoRequests': <dynamic>[],
          'questions': <dynamic>[],
          'statusHistory': <dynamic>[],
        },
    ],
    'total': total,
  };
}

Map<String, dynamic> _photosPayload(
  int startId,
  int endId, {
  required int total,
}) {
  return {
    'data': [
      for (var id = startId; id <= endId; id++)
        {
          'id': id,
          'url': '/uploads/photo-$id.jpg',
          'createdAt': DateTime(2026, 1, 1, 0, id).toIso8601String(),
        },
    ],
    'total': total,
  };
}
