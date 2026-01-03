class TrackItem {
  final String code;
  final String status;
  final DateTime date;
  final String? groupId;
  final TrackGroup? group;
  final String? comment;
  final DateTime? photoRequestAt;
  final String? photoRequestComment;
  final PhotoTaskStatus? photoTaskStatus;
  final DateTime? photoTaskUpdatedAt;
  final List<String> photoReportUrls;
  final List<String> groupScalePhotos;

  const TrackItem({
    required this.code,
    required this.status,
    required this.date,
    this.groupId,
    this.group,
    this.comment,
    this.photoRequestAt,
    this.photoRequestComment,
    this.photoTaskStatus,
    this.photoTaskUpdatedAt,
    this.photoReportUrls = const [],
    this.groupScalePhotos = const [],
  });
}

class TrackGroup {
  final String id;
  final String? status;
  final List<String> packing;
  final String category;
  final bool insurance;
  final double? insuranceAmount;
  final DateTime createdAt;

  const TrackGroup({
    required this.id,
    this.status,
    required this.packing,
    required this.category,
    required this.insurance,
    this.insuranceAmount,
    required this.createdAt,
  });
}

enum PhotoTaskStatus {
  newTask,
  done,
  cancelled;

  String get label {
    switch (this) {
      case PhotoTaskStatus.newTask:
        return 'NEW';
      case PhotoTaskStatus.done:
        return 'DONE';
      case PhotoTaskStatus.cancelled:
        return 'CANCELLED';
    }
  }
}
