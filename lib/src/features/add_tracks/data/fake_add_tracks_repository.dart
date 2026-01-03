import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/add_tracks_result.dart';

abstract class AddTracksRepository {
  Future<AddTracksResult> addTracks({
    required String clientCode,
    required List<String> trackCodes,
  });
}

final addTracksRepositoryProvider = Provider<AddTracksRepository>((ref) {
  return FakeAddTracksRepository();
});

class FakeAddTracksRepository implements AddTracksRepository {
  @override
  Future<AddTracksResult> addTracks({
    required String clientCode,
    required List<String> trackCodes,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    final rng = Random(clientCode.hashCode ^ trackCodes.length);

    int added = 0;
    final skipped = <SkippedTrack>[];

    for (final code in trackCodes) {
      if (code.length < 5) {
        skipped.add(SkippedTrack(code: code, reason: 'Слишком короткий трек'));
        continue;
      }
      if (rng.nextInt(10) == 0) {
        skipped.add(SkippedTrack(code: code, reason: 'Уже существует в базе'));
        continue;
      }
      added += 1;
    }

    return AddTracksResult(added: added, skipped: skipped);
  }
}

