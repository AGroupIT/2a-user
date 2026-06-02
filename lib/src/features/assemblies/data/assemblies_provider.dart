import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/cache/stale_data_cache.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/demo_mode_provider.dart';
import '../domain/assembly_item.dart';

/// Провайдер для получения списка сборок по коду клиента
final assembliesListProvider =
    FutureProvider.family<List<AssemblyItem>, String>((ref, clientCode) async {
      final apiClient = ref.read(apiClientProvider);

      try {
        final queryParams = {'clientCode': clientCode, 'take': 100};
        final data = await StaleDataCache.getJson(
          ref: ref,
          cacheKey: StaleDataCache.buildKey('assemblies_list', queryParams),
          label: 'сборки',
          request: () =>
              apiClient.get('/assemblies', queryParameters: queryParams),
        );

        // API возвращает assemblies, не data
        final assembliesJson = data['assemblies'] as List<dynamic>? ?? [];

        return assembliesJson
            .map((json) => AssemblyItem.fromJson(json as Map<String, dynamic>))
            .toList();
      } catch (e) {
        debugPrint('Error loading assemblies: $e');
        return [];
      }
    });

/// Последние сборки для блока дайджеста на главной.
final assembliesDigestProvider =
    FutureProvider.family<List<AssemblyItem>, String>((ref, clientCode) async {
      if (ref.watch(demoModeProvider)) return <AssemblyItem>[];
      final apiClient = ref.read(apiClientProvider);

      try {
        final queryParams = {
          'clientCode': clientCode,
          'take': 10,
          'sortBy': 'updatedAt',
          'sortDirection': 'desc',
        };
        final data = await StaleDataCache.getJson(
          ref: ref,
          cacheKey: StaleDataCache.buildKey('assemblies_digest', queryParams),
          label: 'последние сборки',
          request: () =>
              apiClient.get('/assemblies', queryParameters: queryParams),
        );

        final assembliesJson = data['assemblies'] as List<dynamic>? ?? [];

        final assemblies = assembliesJson
            .map((json) => AssemblyItem.fromJson(json as Map<String, dynamic>))
            .toList();

        assemblies.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        return assemblies;
      } catch (e) {
        debugPrint('Error loading assemblies digest: $e');
        return [];
      }
    });

/// Провайдер количества сборок для карточки на главном экране.
/// Считаются только сборки в активной обработке: new / in_warehouse / in_assembly.
final assembliesCountProvider = FutureProvider.family<int, String>((
  ref,
  clientCode,
) async {
  final apiClient = ref.read(apiClientProvider);

  try {
    final queryParams = {
      'clientCode': clientCode,
      'take': 1,
      'statuses': 'new,in_warehouse,in_assembly',
    };
    final data = await StaleDataCache.getJson(
      ref: ref,
      cacheKey: StaleDataCache.buildKey('assemblies_count', queryParams),
      label: 'количество сборок',
      request: () => apiClient.get('/assemblies', queryParameters: queryParams),
    );

    // total находится в pagination
    final pagination = data['pagination'] as Map<String, dynamic>?;
    return pagination?['total'] as int? ?? 0;
  } catch (e) {
    debugPrint('Error loading assemblies count: $e');
    return 0;
  }
});

/// Количество сборок, созданных за последние 7 дней.
final assembliesWeeklyCountProvider = FutureProvider.family<int, String>((
  ref,
  clientCode,
) async {
  if (ref.watch(demoModeProvider)) return 0;
  final apiClient = ref.read(apiClientProvider);
  final weekStart = DateTime.now().subtract(const Duration(days: 7));

  try {
    final queryParams = {
      'clientCode': clientCode,
      'take': 1,
      'dateFrom': weekStart.toUtc().toIso8601String(),
    };
    final data = await StaleDataCache.getJson(
      ref: ref,
      cacheKey: StaleDataCache.buildKey('assemblies_weekly_count', {
        'clientCode': clientCode,
        'dateFromDay': weekStart.toUtc().toIso8601String().substring(0, 10),
      }),
      label: 'сборки за неделю',
      request: () => apiClient.get('/assemblies', queryParameters: queryParams),
    );

    final pagination = data['pagination'] as Map<String, dynamic>?;
    return pagination?['total'] as int? ?? 0;
  } catch (e) {
    debugPrint('Error loading weekly assemblies count: $e');
    return 0;
  }
});
