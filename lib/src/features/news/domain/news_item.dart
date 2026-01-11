import '../../../core/network/api_config.dart';

class NewsItem {
  final String slug;
  final String title;
  final String excerpt;

  /// Markdown content for rich text rendering
  final String content;
  final DateTime publishedAt;

  /// Optional cover image URL
  final String? imageUrl;

  const NewsItem({
    required this.slug,
    required this.title,
    required this.excerpt,
    required this.content,
    required this.publishedAt,
    this.imageUrl,
  });

  factory NewsItem.fromJson(Map<String, dynamic> json) {
    // Обрабатываем imageUrl - добавляем базовый URL если путь относительный
    String? imageUrl = json['imageUrl'] as String?;
    if (imageUrl != null &&
        imageUrl.isNotEmpty &&
        !imageUrl.startsWith('http')) {
      imageUrl = ApiConfig.getMediaUrl(imageUrl);
    }

    final content = json['content'] as String? ?? '';

    return NewsItem(
      slug: json['id'].toString(),
      title: json['title'] as String? ?? '',
      excerpt: _extractExcerpt(content),
      content: content,
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
