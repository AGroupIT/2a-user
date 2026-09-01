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

final searchControllerProvider =
    AsyncNotifierProvider<SearchController, List<SearchResult>>(
      SearchController.new,
    );

class SearchController extends AsyncNotifier<List<SearchResult>> {
  @override
  Future<List<SearchResult>> build() async => const [];

  /// Ищет только nocode-треки своего агента.
  Future<void> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      state = const AsyncValue.data([]);
      return;
    }

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(searchRepositoryProvider);
      return repo.searchNoCodeTracks(trimmed);
    });
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
        final updated = current.map((item) {
          if (item.id == trackId) {
            return SearchResult(
              id: item.id,
              trackCode: item.trackCode,
              status: item.status,
              statusZh: item.statusZh,
              statusColor: item.statusColor,
              updatedAt: item.updatedAt,
              clientCode: item.clientCode,
              clientCodeId: item.clientCodeId,
              isNocode: item.isNocode,
              hasQuestion: true,
              hasPendingQuestion: true,
              showBindButton: false,
            );
          }
          return item;
        }).toList();
        state = AsyncValue.data(updated);
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
