class SearchResult {
  final String trackCode;
  final String status;
  final DateTime updatedAt;
  final String? clientCode;

  const SearchResult({
    required this.trackCode,
    required this.status,
    required this.updatedAt,
    this.clientCode,
  });
}

