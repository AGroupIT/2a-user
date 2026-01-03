class PhotoItem {
  final String url;
  final DateTime date;
  final String? trackingNumber;
  final String? assemblyNumber;

  const PhotoItem({
    required this.url,
    required this.date,
    this.trackingNumber,
    this.assemblyNumber,
  });

  bool get isVideo {
    final lower = url.toLowerCase();
    return lower.endsWith('.mp4') ||
        lower.endsWith('.m4v') ||
        lower.endsWith('.webm') ||
        lower.endsWith('.mov');
  }
}
