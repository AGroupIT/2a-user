import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

enum TrainingLessonStatus { inProgress, read, skipped, practiced }

class TrainingProgress {
  final String? lastLessonId;
  final Map<String, int> steps;
  final Map<String, TrainingLessonStatus> statuses;

  const TrainingProgress({
    this.lastLessonId,
    this.steps = const {},
    this.statuses = const {},
  });

  TrainingProgress visit(String id, int step, {TrainingLessonStatus? status}) {
    final previous = statuses[id];
    // Reviewing a lesson never erases an already completed exercise/read.
    final nextStatus = previous == TrainingLessonStatus.practiced
        ? TrainingLessonStatus.practiced
        : previous == TrainingLessonStatus.read &&
              (status == null || status == TrainingLessonStatus.skipped)
        ? TrainingLessonStatus.read
        : status ?? previous ?? TrainingLessonStatus.inProgress;
    return TrainingProgress(
      lastLessonId: id,
      steps: {...steps, id: step},
      statuses: {...statuses, id: nextStatus},
    );
  }

  Map<String, Object?> toJson() => {
    'lastLessonId': lastLessonId,
    'steps': steps,
    'statuses': statuses.map((key, value) => MapEntry(key, value.name)),
  };

  factory TrainingProgress.fromJson(Map<String, dynamic> json) {
    final steps = <String, int>{};
    final statuses = <String, TrainingLessonStatus>{};
    final rawSteps = json['steps'];
    if (rawSteps is Map) {
      for (final entry in rawSteps.entries) {
        if (entry.key is String && entry.value is int && entry.value >= 0) {
          steps[entry.key as String] = entry.value as int;
        }
      }
    }
    final rawStatuses = json['statuses'];
    if (rawStatuses is Map) {
      for (final entry in rawStatuses.entries) {
        for (final status in TrainingLessonStatus.values) {
          if (entry.key is String && entry.value == status.name) {
            statuses[entry.key as String] = status;
          }
        }
      }
    }
    return TrainingProgress(
      lastLessonId: json['lastLessonId'] is String
          ? json['lastLessonId'] as String
          : null,
      steps: steps,
      statuses: statuses,
    );
  }
}

/// Device-local prototype progress. Does not use/reset the old demo-mode flags.
class TrainingProgressStore {
  final SharedPreferences preferences;
  final String accountKey;

  TrainingProgressStore(this.preferences, {required this.accountKey});

  String get storageKey => 'training_v1_${Uri.encodeComponent(accountKey)}';

  TrainingProgress read() {
    try {
      final raw = preferences.getString(storageKey);
      if (raw == null) return const TrainingProgress();
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) return const TrainingProgress();
      return TrainingProgress.fromJson(json);
    } on FormatException {
      return const TrainingProgress();
    } on TypeError {
      return const TrainingProgress();
    }
  }

  Future<bool> save(TrainingProgress progress) =>
      preferences.setString(storageKey, jsonEncode(progress.toJson()));
}
