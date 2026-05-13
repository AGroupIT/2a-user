import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/invoices/data/invoices_provider.dart';
import '../../features/news/data/news_provider.dart';
import '../../features/notifications/application/notifications_controller.dart';
import '../../features/photos/data/photos_provider.dart';
import '../../features/profile/data/profile_provider.dart';
import '../../features/rules/data/rules_provider.dart';
import '../../features/tariffs/data/tariffs_provider.dart';
import '../../features/assemblies/data/assemblies_provider.dart'
    as user_assemblies;
import '../../features/clients/application/client_codes_controller.dart';
import '../../features/sp_finance/data/sp_provider.dart';
import '../../features/tracks/data/assemblies_provider.dart';
import '../../features/tracks/data/tracks_provider.dart';
import 'websocket_provider.dart';

/// Провайдер для автоматической синхронизации данных через WebSocket дельты.
///
/// Слушает delta events и инвалидирует соответствующие FutureProvider'ы,
/// чтобы экраны автоматически обновлялись при изменении данных на сервере.
///
/// Замена для AutoRefreshMixin (60-секундный polling).
final deltaSyncProvider = Provider<void>((ref) {
  final wsService = ref.read(webSocketServiceProvider);

  // Debounce: собираем типы дельт за 500ms и обрабатываем разом
  final pendingTypes = <String>{};
  Timer? debounceTimer;

  void scheduleFlush(String type) {
    pendingTypes.add(type);
    debounceTimer?.cancel();
    debounceTimer = Timer(const Duration(milliseconds: 500), () {
      for (final t in pendingTypes) {
        _handleDeltaType(ref, t);
      }
      pendingTypes.clear();
    });
  }

  // Listen to delta events (room-based, preferred)
  final deltaSub = wsService.deltas.listen((delta) {
    debugPrint('[DeltaSync] Delta: ${delta.type} ${delta.action} ${delta.id}');
    scheduleFlush(delta.type);
  });

  // Listen to delta_batch events (mass operations)
  final deltaBatchSub = wsService.deltaBatches.listen((batch) {
    debugPrint(
      '[DeltaSync] DeltaBatch: ${batch.type} ${batch.items.length} items',
    );
    scheduleFlush(batch.type);
  });

  // Listen to data_changed events (broadcast, fallback)
  final dataChangedSub = wsService.dataChanged.listen((data) {
    final type = data['type'] as String?;
    if (type != null) {
      debugPrint('[DeltaSync] DataChanged: $type');
      scheduleFlush(type);
    }
  });

  // При reconnect — инвалидируем все
  final reconnectSub = wsService.reconnected.listen((_) {
    debugPrint('[DeltaSync] WS reconnected — invalidating all providers');
    _invalidateAll(ref);
  });

  ref.onDispose(() {
    deltaSub.cancel();
    deltaBatchSub.cancel();
    dataChangedSub.cancel();
    reconnectSub.cancel();
    debounceTimer?.cancel();
  });
});

void _handleDeltaType(Ref ref, String type) {
  switch (type) {
    case 'tracks':
      // PaginatedTracksNotifier использует custom listener pattern,
      // для FutureProvider'ов — invalidate
      ref.invalidate(tracksDigestProvider);
      ref.invalidate(tracksCountProvider);
      ref.invalidate(tracksWithoutAssemblyCountProvider);
      return;

    case 'assemblies':
    case 'warehouse_assemblies':
      ref.invalidate(assembliesListProvider);
      ref.invalidate(assembliesDigestProvider);
      ref.invalidate(assembliesCountProvider);
      ref.invalidate(user_assemblies.assembliesListProvider);
      ref.invalidate(user_assemblies.assembliesCountProvider);
      // SP finance assemblies (NotifierProvider — reload instead of invalidate)
      ref.read(spAssembliesControllerProvider.notifier).loadAssemblies();
      return;

    case 'invoices':
      ref.invalidate(invoicesListProvider);
      ref.invalidate(invoicesDigestProvider);
      ref.invalidate(invoicesCountProvider);
      // Инвалидируем детальные провайдеры (family) — нужно для мгновенного
      // обновления открытого инвойса, например, на экране оплаты.
      ref.invalidate(invoiceByIdProvider);
      return;

    case 'news':
      ref.invalidate(newsListProvider);
      return;

    case 'tariffs':
      ref.invalidate(userTariffsProvider);
      return;

    case 'service_rules':
      ref.invalidate(rulesListProvider);
      return;

    case 'photo_requests':
      ref.invalidate(photosTotalCountProvider);
      ref.invalidate(photosRecentProvider);
      ref.invalidate(photosDaysProvider);
      ref.invalidate(photosByDateProvider);
      ref.invalidate(photosSearchProvider);
      // Фотозапросы вложены в треки — обновляем digest
      ref.invalidate(tracksDigestProvider);
      return;

    case 'questions':
      // Вопросы вложены в треки — обновляем digest
      ref.invalidate(tracksDigestProvider);
      return;

    case 'notifications':
      ref.read(notificationsControllerProvider.notifier).refreshDebounced();
      return;
  }
}

/// Принудительное обновление клиентских данных после восстановления сети.
///
/// Вызывается из App при возврате из background/sleep и из WS reconnect-flow.
/// Держим это в одном месте, чтобы не расходились списки провайдеров.
void invalidateClientDataProviders(WidgetRef ref) => _invalidateAllFor(ref);

void _invalidateAll(Ref ref) => _invalidateAllFor(ref);

void _invalidateAllFor(dynamic ref) {
  ref.invalidate(clientProfileProvider);
  ref.invalidate(clientStatsProvider);
  ref.invalidate(clientCodesControllerProvider);
  ref.invalidate(tracksDigestProvider);
  ref.invalidate(tracksCountProvider);
  ref.invalidate(tracksWithoutAssemblyCountProvider);
  ref.invalidate(assembliesListProvider);
  ref.invalidate(assembliesDigestProvider);
  ref.invalidate(assembliesCountProvider);
  ref.invalidate(user_assemblies.assembliesListProvider);
  ref.invalidate(user_assemblies.assembliesCountProvider);
  ref.read(spAssembliesControllerProvider.notifier).loadAssemblies();
  ref.invalidate(invoicesListProvider);
  ref.invalidate(invoicesDigestProvider);
  ref.invalidate(invoicesCountProvider);
  ref.invalidate(newsListProvider);
  ref.invalidate(userTariffsProvider);
  ref.invalidate(rulesListProvider);
  ref.invalidate(photosTotalCountProvider);
  ref.invalidate(photosRecentProvider);
  ref.invalidate(photosDaysProvider);
  ref.invalidate(photosByDateProvider);
  ref.invalidate(photosSearchProvider);
}
