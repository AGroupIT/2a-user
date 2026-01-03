class RuleItem {
  final String slug;
  final String title;
  final String excerpt;
  /// Markdown content for rich text rendering
  final String content;
  final int order;

  const RuleItem({
    required this.slug,
    required this.title,
    required this.excerpt,
    required this.content,
    required this.order,
  });
}
