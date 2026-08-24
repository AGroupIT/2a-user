enum AssemblyScanSessionStatus {
  starting,
  recording,
  reconnecting,
  stopping,
  processing,
  ready,
  partial,
  failed,
  unknown;

  factory AssemblyScanSessionStatus.fromCode(String? code) {
    return switch (code) {
      'starting' => starting,
      'recording' => recording,
      'reconnecting' => reconnecting,
      'stopping' => stopping,
      'processing' => processing,
      'ready' => ready,
      'partial' => partial,
      'failed' => failed,
      _ => unknown,
    };
  }
}

class AssemblyScanVideo {
  final String id;
  final int partIndex;
  final String mimeType;
  final int? sizeBytes;
  final int? durationMs;
  final int recordingOffsetMs;
  final String status;

  const AssemblyScanVideo({
    required this.id,
    required this.partIndex,
    required this.mimeType,
    required this.sizeBytes,
    required this.durationMs,
    required this.recordingOffsetMs,
    required this.status,
  });

  bool get isReady => status == 'ready';

  int? get recordingEndMs {
    final duration = durationMs;
    return duration == null ? null : recordingOffsetMs + duration;
  }

  factory AssemblyScanVideo.fromJson(Map<String, dynamic> json) {
    return AssemblyScanVideo(
      id: json['id']?.toString() ?? '',
      partIndex: _asInt(json['partIndex']) ?? 0,
      mimeType: json['mimeType']?.toString() ?? 'video/mp4',
      sizeBytes: _asInt(json['sizeBytes']),
      durationMs: _asInt(json['durationMs']),
      recordingOffsetMs: _asInt(json['recordingOffsetMs']) ?? 0,
      status: json['status']?.toString() ?? 'pending',
    );
  }
}

class AssemblyScanMarker {
  final String id;
  final int? trackId;
  final String trackNumber;
  final String? productName;
  final DateTime scannedAt;
  final DateTime? clientCapturedAt;
  final int sessionOffsetMs;
  final String? videoId;
  final int? videoOffsetMs;

  const AssemblyScanMarker({
    required this.id,
    required this.trackId,
    required this.trackNumber,
    required this.productName,
    required this.scannedAt,
    required this.clientCapturedAt,
    required this.sessionOffsetMs,
    required this.videoId,
    required this.videoOffsetMs,
  });

  factory AssemblyScanMarker.fromJson(Map<String, dynamic> json) {
    return AssemblyScanMarker(
      id: json['id']?.toString() ?? '',
      trackId: _asInt(json['trackId']),
      trackNumber: json['trackNumber']?.toString() ?? '',
      productName: json['productName']?.toString(),
      scannedAt:
          _asDateTime(json['scannedAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      clientCapturedAt: _asDateTime(json['clientCapturedAt']),
      sessionOffsetMs: _asInt(json['sessionOffsetMs']) ?? 0,
      videoId: json['videoId']?.toString(),
      videoOffsetMs: _asInt(json['videoOffsetMs']),
    );
  }
}

class AssemblyScanSession {
  final String id;
  final int assemblyId;
  final int? employeeId;
  final String? employeeName;
  final String statusCode;
  final AssemblyScanSessionStatus status;
  final DateTime startedAt;
  final DateTime? recordingStartedAt;
  final DateTime? endedAt;
  final int? durationMs;
  final String? stopReason;
  final String? interruptionReason;
  final bool hasKnownGap;
  final int videoCount;
  final int scanCount;
  final List<AssemblyScanVideo> videos;
  final List<AssemblyScanMarker> markers;

  const AssemblyScanSession({
    required this.id,
    required this.assemblyId,
    required this.employeeId,
    required this.employeeName,
    required this.statusCode,
    required this.status,
    required this.startedAt,
    required this.recordingStartedAt,
    required this.endedAt,
    required this.durationMs,
    required this.stopReason,
    required this.interruptionReason,
    required this.hasKnownGap,
    required this.videoCount,
    required this.scanCount,
    required this.videos,
    required this.markers,
  });

  bool get isPlayable =>
      (status == AssemblyScanSessionStatus.ready ||
          status == AssemblyScanSessionStatus.partial) &&
      readyVideos.isNotEmpty;

  List<AssemblyScanVideo> get readyVideos =>
      videos.where((video) => video.isReady).toList(growable: false)
        ..sort(_compareVideosByTimeline);

  AssemblyScanVideo? videoForMarker(AssemblyScanMarker marker) {
    final ready = readyVideos;
    if (ready.isEmpty) return null;

    final explicitVideoId = marker.videoId;
    if (explicitVideoId != null) {
      for (final video in ready) {
        if (video.id == explicitVideoId) return video;
      }
      return null;
    }

    for (final video in ready) {
      final end = video.recordingEndMs;
      if (end == null) continue;
      if (marker.sessionOffsetMs >= video.recordingOffsetMs &&
          marker.sessionOffsetMs < end) {
        return video;
      }
    }
    return null;
  }

  Duration markerOffsetInVideo(
    AssemblyScanMarker marker,
    AssemblyScanVideo video,
  ) {
    final explicitOffset = marker.videoId == video.id
        ? marker.videoOffsetMs
        : null;
    final milliseconds =
        explicitOffset ?? marker.sessionOffsetMs - video.recordingOffsetMs;
    return Duration(milliseconds: milliseconds.clamp(0, 1 << 31));
  }

  factory AssemblyScanSession.fromJson(Map<String, dynamic> json) {
    final statusCode = json['status']?.toString() ?? 'unknown';
    final videos = _mapList(json['videos'], AssemblyScanVideo.fromJson)
      ..sort(_compareVideosByTimeline);
    final markers = _mapList(json['scans'], AssemblyScanMarker.fromJson)
      ..sort((a, b) => a.sessionOffsetMs.compareTo(b.sessionOffsetMs));

    return AssemblyScanSession(
      id: json['id']?.toString() ?? '',
      assemblyId: _asInt(json['assemblyId']) ?? 0,
      employeeId: _asInt(json['employeeId']),
      employeeName: json['employeeName']?.toString(),
      statusCode: statusCode,
      status: AssemblyScanSessionStatus.fromCode(statusCode),
      startedAt:
          _asDateTime(json['startedAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      recordingStartedAt: _asDateTime(json['recordingStartedAt']),
      endedAt: _asDateTime(json['endedAt']),
      durationMs: _asInt(json['durationMs']),
      stopReason: json['stopReason']?.toString(),
      interruptionReason: json['interruptionReason']?.toString(),
      hasKnownGap: json['hasKnownGap'] == true,
      videoCount: _asInt(json['videoCount']) ?? videos.length,
      scanCount: _asInt(json['scanCount']) ?? markers.length,
      videos: List.unmodifiable(videos),
      markers: List.unmodifiable(markers),
    );
  }
}

int _compareVideosByTimeline(AssemblyScanVideo left, AssemblyScanVideo right) {
  final byOffset = left.recordingOffsetMs.compareTo(right.recordingOffsetMs);
  if (byOffset != 0) return byOffset;
  return left.partIndex.compareTo(right.partIndex);
}

class AssemblyScanPlaybackToken {
  final Uri url;
  final DateTime expiresAt;

  const AssemblyScanPlaybackToken({required this.url, required this.expiresAt});

  bool get isExpiringSoon =>
      DateTime.now().isAfter(expiresAt.subtract(const Duration(seconds: 30)));

  factory AssemblyScanPlaybackToken.fromJson(Map<String, dynamic> json) {
    final rawUrl = json['url']?.toString() ?? '';
    final expiresInSeconds = _asInt(json['expiresInSeconds']) ?? 0;
    return AssemblyScanPlaybackToken(
      url: Uri.parse(rawUrl),
      expiresAt: DateTime.now().add(Duration(seconds: expiresInSeconds)),
    );
  }
}

List<T> _mapList<T>(dynamic value, T Function(Map<String, dynamic>) parser) {
  if (value is! List) return <T>[];
  return value
      .whereType<Map>()
      .map((item) => parser(Map<String, dynamic>.from(item)))
      .toList();
}

int? _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

DateTime? _asDateTime(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}
