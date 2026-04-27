import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../news/data/news_provider.dart';
import '../domain/rule_item.dart';

/// Провайдер для получения списка правил
final rulesListProvider = FutureProvider<List<RuleItem>>((ref) async {
  final apiClient = ref.read(apiClientProvider);
  final agentId = ref.watch(clientAgentIdProvider);

  if (agentId == null) {
    debugPrint('Rules: agentId is null, returning empty list');
    return [];
  }

  try {
    final response = await apiClient.get(
      '/service-rules',
      queryParameters: {
        'agentId': agentId,
        'status': 'published', // Показываем только опубликованные
        'take': 50,
      },
    );

    if (response.statusCode == 200 && response.data != null) {
      final data = response.data as Map<String, dynamic>;
      final rulesJson = data['data'] as List<dynamic>? ?? [];

      return rulesJson
          .map((json) => RuleItem.fromJson(json as Map<String, dynamic>))
          .toList();
    }
    return [];
  } on DioException catch (e) {
    debugPrint('Error loading rules: $e');
    return [];
  }
});

/// Провайдер для получения одного правила по ID/slug.
///
/// PU-M9: сначала прямой fetch GET `/service-rules/:id`, fallback на
/// поиск в загруженном списке. Зачем: detail screen, открытый по push
/// или deep link, мог быть пустым, если правило вне первых 50 или
/// список ещё не загружен.
final ruleItemProvider = FutureProvider.family<RuleItem?, String>((
  ref,
  idOrSlug,
) async {
  final apiClient = ref.read(apiClientProvider);

  final id = int.tryParse(idOrSlug);
  if (id != null) {
    try {
      final response = await apiClient.get('/service-rules/$id');
      if (response.statusCode == 200 && response.data != null) {
        // Backend отдаёт плоский объект (не `{data: ...}`), как list-эндпоинт.
        final raw = response.data as Map<String, dynamic>;
        return RuleItem.fromJson(raw);
      }
    } on DioException catch (e) {
      debugPrint('Rule fetchById fallback: $e');
    }
  }

  // Fallback: ищем в уже загруженном списке.
  final rulesList = await ref.watch(rulesListProvider.future);
  return rulesList.cast<RuleItem?>().firstWhere(
    (r) => r?.slug == idOrSlug,
    orElse: () => null,
  );
});
