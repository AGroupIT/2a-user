class AddTracksResult {
  final int added;
  final List<SkippedTrack> skipped;

  const AddTracksResult({
    required this.added,
    required this.skipped,
  });
}

class SkippedTrack {
  final String code;
  final String reason;

  const SkippedTrack({required this.code, required this.reason});
}

