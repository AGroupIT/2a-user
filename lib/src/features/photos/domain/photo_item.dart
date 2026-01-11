import '../../../core/network/api_config.dart';

class PhotoItem {
  final int? id;
  final String url;
  final DateTime date;
  final String? trackingNumber;
  final String? assemblyNumber;

  const PhotoItem({
    this.id,
    required this.url,
    required this.date,
    this.trackingNumber,
    this.assemblyNumber,
  });

  factory PhotoItem.fromJson(Map<String, dynamic> json) {
    // Получаем URL и формируем полный путь если относительный
    final rawUrl = json['url'] as String? ?? json['thumbnailUrl'] as String? ?? '';
    final fullUrl = ApiConfig.getMediaUrl(rawUrl);
    
    return PhotoItem(
      id: json['id'] as int?,
      url: fullUrl,
      date: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      trackingNumber: json['trackNumber'] as String? ?? json['track']?['trackNumber'] as String?,
      assemblyNumber: json['assembly']?['number'] as String?,
    );
  }

  bool get isVideo {
    final lower = url.toLowerCase();
    return lower.endsWith('.mp4') ||
        lower.endsWith('.m4v') ||
        lower.endsWith('.webm') ||
        lower.endsWith('.mov');
  }
}
