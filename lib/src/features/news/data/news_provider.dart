import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_config.dart';
import '../../auth/data/auth_provider.dart';
import '../domain/news_item.dart';

/// Провайдер для получения agentId из данных клиента
final clientAgentIdProvider = Provider<int?>((ref) {
  final authState = ref.watch(authProvider);
  final clientData = authState.clientData;
  if (clientData == null) return null;

  final agent = clientData['agent'] as Map<String, dynamic>?;
  return agent?['id'] as int?;
});

/// Провайдер для получения списка новостей
final newsListProvider = FutureProvider<List<NewsItem>>((ref) async {
  final apiClient = ref.read(apiClientProvider);
  final agentId = ref.watch(clientAgentIdProvider);

  if (agentId == null) {
    debugPrint('News: agentId is null, returning empty list');
    return [];
  }

  try {
    final response = await apiClient.get(
      '/news',
      queryParameters: {
        'agentId': agentId,
        'status': 'published', // Показываем только опубликованные
        'take': 50,
      },
    );

    if (response.statusCode == 200 && response.data != null) {
      final data = response.data as Map<String, dynamic>;
      final newsJson = data['data'] as List<dynamic>? ?? [];

      return newsJson
          .map((json) => NewsItem.fromJson(json as Map<String, dynamic>))
          .toList();
    }
    return [];
  } on DioException catch (e) {
    debugPrint('Error loading news: $e');
    return [];
  }
});

/// Провайдер для получения одной новости по ID
final newsItemProvider = FutureProvider.family<NewsItem?, String>((
  ref,
  idOrSlug,
) async {
  // Сначала пробуем получить из списка
  final newsList = await ref.watch(newsListProvider.future);

  // Ищем по id (преобразуем slug в int если возможно)
  final id = int.tryParse(idOrSlug);
  if (id != null) {
    return newsList.cast<NewsItem?>().firstWhere(
      (n) => n?.slug == idOrSlug,
      orElse: () => null,
    );
  }

  return newsList.cast<NewsItem?>().firstWhere(
    (n) => n?.slug == idOrSlug,
    orElse: () => null,
  );
});

/// Расширение модели NewsItem для парсинга из API
extension NewsItemFromJson on NewsItem {
  static NewsItem fromJson(Map<String, dynamic> json) {
    // Обрабатываем imageUrl - добавляем базовый URL если путь относительный
    String? imageUrl = json['imageUrl'] as String?;
    if (imageUrl != null &&
        imageUrl.isNotEmpty &&
        !imageUrl.startsWith('http')) {
      imageUrl = ApiConfig.getMediaUrl(imageUrl);
    }

    return NewsItem(
      slug: json['id'].toString(),
      title: json['title'] as String? ?? '',
      excerpt: _extractExcerpt(json['content'] as String? ?? ''),
      content: json['content'] as String? ?? '',
      publishedAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      imageUrl: imageUrl,
    );
  }

  /// Извлекает первые ~150 символов для превью
  static String _extractExcerpt(String content) {
    // Убираем markdown разметку для чистого текста
    final cleaned = content
        .replaceAll(RegExp(r'#{1,6}\s*'), '') // заголовки
        .replaceAll(RegExp(r'\*{1,2}'), '') // bold/italic
        .replaceAll(RegExp(r'`{1,3}'), '') // code
        .replaceAll(RegExp(r'\[([^\]]+)\]\([^)]+\)'), r'$1') // links
        .replaceAll(RegExp(r'>\s*'), '') // blockquotes
        .replaceAll(RegExp(r'[-*]\s+'), '') // lists
        .replaceAll(RegExp(r'\n+'), ' ') // newlines
        .trim();

    if (cleaned.length <= 150) return cleaned;
    return '${cleaned.substring(0, 147)}...';
  }
}
