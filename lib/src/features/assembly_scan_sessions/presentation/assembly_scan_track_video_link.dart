import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/locale_text.dart';
import '../../tracks/domain/track_item.dart';
import '../data/assembly_scan_sessions_provider.dart';
import '../domain/assembly_scan_session.dart';
import 'assembly_scan_session_screen.dart';

/// Shows a track-to-video shortcut only when the client-scoped session response
/// contains an immutable scan marker for this track.
class AssemblyScanTrackVideoLink extends ConsumerWidget {
  final int assemblyId;
  final String assemblyNumber;
  final TrackItem track;

  const AssemblyScanTrackVideoLink({
    super.key,
    required this.assemblyId,
    required this.assemblyNumber,
    required this.track,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(assemblyScanSessionsProvider(assemblyId));
    return sessions.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (sessions) {
        final target = _findTrackVideoTarget(sessions, track);
        if (target == null) return const SizedBox.shrink();
        return TextButton.icon(
          onPressed: () => _openSession(context, target),
          icon: const Icon(Icons.play_circle_outline_rounded, size: 18),
          label: Text(tr(context, ru: 'К видео сканирования', zh: '查看扫描视频')),
        );
      },
    );
  }

  void _openSession(BuildContext context, _TrackVideoTarget target) {
    showAssemblyScanSessionSheet(
      context,
      assemblyId: assemblyId,
      assemblyNumber: assemblyNumber,
      sessionId: target.session.id,
      approachNumber: _approachNumber(target.session, target.sessions),
      initialMarkerId: target.marker.id,
    );
  }
}

class _TrackVideoTarget {
  final AssemblyScanSession session;
  final AssemblyScanMarker marker;
  final List<AssemblyScanSession> sessions;

  const _TrackVideoTarget({
    required this.session,
    required this.marker,
    required this.sessions,
  });
}

_TrackVideoTarget? _findTrackVideoTarget(
  List<AssemblyScanSession> sessions,
  TrackItem track,
) {
  final sortedSessions = [...sessions]
    ..sort((left, right) => right.startedAt.compareTo(left.startedAt));
  for (final session in sortedSessions) {
    for (final marker in session.markers) {
      final matchesId = track.id != null && marker.trackId == track.id;
      final matchesCode = marker.trackNumber == track.code;
      if ((matchesId || matchesCode) &&
          session.videoForMarker(marker) != null) {
        return _TrackVideoTarget(
          session: session,
          marker: marker,
          sessions: sessions,
        );
      }
    }
  }
  return null;
}

int _approachNumber(
  AssemblyScanSession target,
  List<AssemblyScanSession> sessions,
) {
  final chronological = [...sessions]
    ..sort((left, right) => left.startedAt.compareTo(right.startedAt));
  final index = chronological.indexWhere((session) => session.id == target.id);
  return index < 0 ? 1 : index + 1;
}
