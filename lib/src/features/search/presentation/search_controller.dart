import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/fake_search_repository.dart';
import '../domain/search_result.dart';

String trackBindingRequestErrorMessage(
  TrackBindingRequestErrorCode? code, {
  required bool isZh,
}) {
  return switch (code ?? TrackBindingRequestErrorCode.unknown) {
    TrackBindingRequestErrorCode.trackNotFound =>
      isZh
          ? '未找到该运单，请重新搜索。'
          : 'Трек больше не найден. Выполните поиск ещё раз.',
    TrackBindingRequestErrorCode.trackNotAvailable =>
      isZh
          ? '该运单已绑定或不再可申请。'
          : 'Трек уже привязан или больше недоступен для заявки.',
    TrackBindingRequestErrorCode.requestExists =>
      isZh ? '该运单的绑定申请已发送。' : 'Запрос на привязку этого трека уже отправлен.',
    TrackBindingRequestErrorCode.clientCodeRequired ||
    TrackBindingRequestErrorCode.clientCodeNotOwned ||
    TrackBindingRequestErrorCode.clientCodeMismatch =>
      isZh
          ? '当前客户代码不可用，请刷新账户数据后重试。'
          : 'Текущий код клиента недоступен. Обновите данные и попробуйте снова.',
    TrackBindingRequestErrorCode.proofRequired =>
      isZh ? '请先上传物流证明。' : 'Сначала загрузите подтверждение логистики.',
    TrackBindingRequestErrorCode.unauthorized =>
      isZh
          ? '会话已过期，请重新登录。'
          : 'Сессия устарела. Войдите заново и повторите попытку.',
    TrackBindingRequestErrorCode.unknown =>
      isZh
          ? '发送申请失败，请稍后重试。'
          : 'Не удалось отправить запрос. Попробуйте ещё раз.',
  };
}

class NoCodeCatalogState {
  const NoCodeCatalogState({
    this.items = const [],
    this.total = 0,
    this.hasMore = false,
    this.query = '',
    this.isLoadingMore = false,
    this.loadMoreError,
  });

  final List<SearchResult> items;
  final int total;
  final bool hasMore;
  final String query;
  final bool isLoadingMore;
  final Object? loadMoreError;

  NoCodeCatalogState copyWith({
    List<SearchResult>? items,
    int? total,
    bool? hasMore,
    String? query,
    bool? isLoadingMore,
    Object? loadMoreError,
    bool clearLoadMoreError = false,
  }) {
    return NoCodeCatalogState(
      items: items ?? this.items,
      total: total ?? this.total,
      hasMore: hasMore ?? this.hasMore,
      query: query ?? this.query,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      loadMoreError: clearLoadMoreError
          ? null
          : loadMoreError ?? this.loadMoreError,
    );
  }
}

final searchControllerProvider =
    AsyncNotifierProvider<SearchController, NoCodeCatalogState>(
      SearchController.new,
    );

class SearchController extends AsyncNotifier<NoCodeCatalogState> {
  static const _pageSize = 20;
  int _requestVersion = 0;

  @override
  Future<NoCodeCatalogState> build() async {
    final page = await ref
        .read(searchRepositoryProvider)
        .fetchNoCodeTracks(take: _pageSize);
    return NoCodeCatalogState(
      items: page.items,
      total: page.total,
      hasMore: page.hasMore,
    );
  }

  /// Фильтрует серверный каталог NOCODE. Пустой запрос возвращает весь каталог.
  Future<void> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isNotEmpty && trimmed.length < 3) return;

    final requestVersion = ++_requestVersion;
    state = const AsyncValue.loading();
    final next = await AsyncValue.guard(() async {
      final repo = ref.read(searchRepositoryProvider);
      final page = await repo.fetchNoCodeTracks(
        query: trimmed,
        take: _pageSize,
      );
      return NoCodeCatalogState(
        items: page.items,
        total: page.total,
        hasMore: page.hasMore,
        query: trimmed,
      );
    });
    if (requestVersion == _requestVersion) state = next;
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null ||
        !current.hasMore ||
        current.isLoadingMore ||
        state.isLoading) {
      return;
    }

    state = AsyncValue.data(
      current.copyWith(isLoadingMore: true, clearLoadMoreError: true),
    );
    try {
      final page = await ref
          .read(searchRepositoryProvider)
          .fetchNoCodeTracks(
            query: current.query,
            skip: current.items.length,
            take: _pageSize,
          );
      final latest = state.value;
      if (latest == null || latest.query != current.query) return;

      final existingIds = latest.items.map((item) => item.id).toSet();
      final newItems = page.items
          .where((item) => existingIds.add(item.id))
          .toList(growable: false);
      state = AsyncValue.data(
        latest.copyWith(
          items: [...latest.items, ...newItems],
          total: page.total,
          hasMore: page.hasMore,
          isLoadingMore: false,
          clearLoadMoreError: true,
        ),
      );
    } catch (error) {
      final latest = state.value;
      if (latest == null || latest.query != current.query) return;
      state = AsyncValue.data(
        latest.copyWith(isLoadingMore: false, loadMoreError: error),
      );
    }
  }

  /// Загружает фото и возвращает URL. null при ошибке.
  Future<String?> uploadBindingPhoto(Uint8List bytes, String fileName) {
    final repo = ref.read(searchRepositoryProvider);
    return repo.uploadBindingPhoto(bytes, fileName);
  }

  Future<TrackBindingRequestResult> requestBinding({
    required int trackId,
    required String trackNumber,
    required String clientCode,
    required int clientId,
    required int? clientCodeId,
    String? currentClientCode,
    required String photoUrl,
  }) async {
    try {
      final repo = ref.read(searchRepositoryProvider);
      await repo.requestBinding(
        trackId: trackId,
        trackNumber: trackNumber,
        clientCode: clientCode,
        clientId: clientId,
        clientCodeId: clientCodeId,
        currentClientCode: currentClientCode,
        photoUrl: photoUrl,
      );

      // Локально помечаем трек как имеющий pending-вопрос.
      final current = state.value;
      if (current != null) {
        final updated = current.items.map((item) {
          if (item.id == trackId) {
            return item.copyWith(
              hasQuestion: true,
              hasPendingQuestion: true,
              showBindButton: false,
            );
          }
          return item;
        }).toList();
        state = AsyncValue.data(current.copyWith(items: updated));
      }

      return const TrackBindingRequestResult.success();
    } on TrackBindingRequestException catch (error) {
      return TrackBindingRequestResult.failure(error.code);
    } catch (_) {
      return const TrackBindingRequestResult.failure(
        TrackBindingRequestErrorCode.unknown,
      );
    }
  }
}
