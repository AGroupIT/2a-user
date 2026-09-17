/// Reads the optional paged envelope while accepting older server responses.
/// Callers keep their existing complete-list API; each request is bounded.
Future<List<Map<String, dynamic>>> loadPagedList({
  required Future<Object?> Function(Map<String, dynamic> query) fetchPage,
  String listKey = 'data',
  Map<String, dynamic> query = const {},
}) async {
  final result = <Map<String, dynamic>>[];
  var skip = 0;
  while (true) {
    final body = await fetchPage({
      ...query,
      'format': 'page',
      'limit': 50,
      'skip': skip,
    });
    final rows = body is List
        ? body
        : body is Map
        ? body[listKey]
        : null;
    if (rows is! List) throw const FormatException('Invalid list response');
    result.addAll(
      rows.map((row) {
        if (row is! Map) throw const FormatException('Invalid list item');
        return Map<String, dynamic>.from(row);
      }),
    );
    final pagination = body is Map ? body['pagination'] : null;
    // Older backends ignore format/limit and return their existing full body.
    if (pagination is! Map || pagination['hasMore'] != true) return result;
    final next = pagination['nextSkip'];
    if (rows.isEmpty || next is! int || next <= skip) {
      throw const FormatException('Pagination did not advance');
    }
    skip = next;
  }
}
