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
}

