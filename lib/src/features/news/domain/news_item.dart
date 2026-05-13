import '../../../core/network/api_config.dart';
import '../../../core/utils/delta_converter.dart';

class NewsItem {
  final String slug;
  final String title;
  final String excerpt;

  /// Raw article content. It may be Quill Delta JSON or plain text.
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

    final rawContent = json['content'] as String? ?? '';
    return NewsItem(
      slug: json['id'].toString(),
      title: json['title'] as String? ?? '',
      excerpt: _extractExcerpt(rawContent),
      content: rawContent,
      publishedAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      imageUrl: imageUrl,
    );
  }

  /// Извлекает первые ~150 символов для превью
  static String _extractExcerpt(String content) {
    final plainText = DeltaConverter.toPlainText(content);

    // Убираем markdown разметку для чистого текста
    final cleaned = plainText
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
