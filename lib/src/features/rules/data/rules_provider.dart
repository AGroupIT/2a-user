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

/// Провайдер для получения одного правила по ID
final ruleItemProvider = FutureProvider.family<RuleItem?, String>((
  ref,
  idOrSlug,
) async {
  // Получаем из списка
  final rulesList = await ref.watch(rulesListProvider.future);

  return rulesList.cast<RuleItem?>().firstWhere(
    (r) => r?.slug == idOrSlug,
    orElse: () => null,
  );
});
