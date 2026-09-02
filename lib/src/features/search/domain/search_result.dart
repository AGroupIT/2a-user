import '../../photos/domain/photo_item.dart';

class SearchResult {
  final int id;
  final String trackCode;
  final String status;
  final String? statusZh;
  final String? statusColor;
  final DateTime updatedAt;
  final String? clientCode;
  final int? clientCodeId;
  final bool isNocode;
  final bool hasQuestion;
  final bool hasPendingQuestion;
  final bool showBindButton;
  final bool hasPhotoReportRequest;
  final String? photoReportStatus;
  final List<PhotoItem> photoReportPhotos;

  const SearchResult({
    required this.id,
    required this.trackCode,
    required this.status,
    this.statusZh,
    this.statusColor,
    required this.updatedAt,
    this.clientCode,
    this.clientCodeId,
    this.isNocode = false,
    this.hasQuestion = false,
    this.hasPendingQuestion = false,
    this.showBindButton = false,
    this.hasPhotoReportRequest = false,
    this.photoReportStatus,
    this.photoReportPhotos = const [],
  });

  factory SearchResult.fromJson(Map<String, dynamic> json) {
    final trackNumber = json['trackNumber'] as String;
    final rawPhotos = json['photoReportPhotos'];

    return SearchResult(
      id: json['id'] as int,
      trackCode: trackNumber,
      status: json['status'] as String? ?? 'Неизвестно',
      statusZh: json['statusZh'] as String?,
      statusColor: json['statusColor'] as String?,
      updatedAt:
          DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
          DateTime.now(),
      clientCode: json['clientCode'] as String?,
      clientCodeId: json['clientCodeId'] as int?,
      isNocode: json['isNocode'] as bool? ?? false,
      hasQuestion: json['hasQuestion'] as bool? ?? false,
      hasPendingQuestion: json['hasPendingQuestion'] as bool? ?? false,
      showBindButton: json['showBindButton'] as bool? ?? false,
      hasPhotoReportRequest: json['hasPhotoReportRequest'] as bool? ?? false,
      photoReportStatus: json['photoReportStatus'] as String?,
      photoReportPhotos: rawPhotos is List
          ? rawPhotos
                .whereType<Map>()
                .map(
                  (photo) => PhotoItem.fromJson({
                    ...Map<String, dynamic>.from(photo),
                    'trackNumber': trackNumber,
                  }),
                )
                .where((photo) => photo.url.isNotEmpty)
                .toList(growable: false)
          : const [],
    );
  }

  SearchResult copyWith({
    bool? hasQuestion,
    bool? hasPendingQuestion,
    bool? showBindButton,
  }) {
    return SearchResult(
      id: id,
      trackCode: trackCode,
      status: status,
      statusZh: statusZh,
      statusColor: statusColor,
      updatedAt: updatedAt,
      clientCode: clientCode,
      clientCodeId: clientCodeId,
      isNocode: isNocode,
      hasQuestion: hasQuestion ?? this.hasQuestion,
      hasPendingQuestion: hasPendingQuestion ?? this.hasPendingQuestion,
      showBindButton: showBindButton ?? this.showBindButton,
      hasPhotoReportRequest: hasPhotoReportRequest,
      photoReportStatus: photoReportStatus,
      photoReportPhotos: photoReportPhotos,
    );
  }
}
