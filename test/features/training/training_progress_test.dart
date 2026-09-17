import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:twoalogisticcabineuser/src/features/training/data/training_progress.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'resumes exact reading step and distinguishes skip from completion',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final store = TrainingProgressStore(prefs, accountKey: 'company:42');
      final progress = const TrainingProgress()
          .visit('tracks', 2, status: TrainingLessonStatus.skipped)
          .visit('assembly', 3, status: TrainingLessonStatus.read);
      expect(await store.save(progress), isTrue);
      final restored = TrainingProgressStore(
        prefs,
        accountKey: 'company:42',
      ).read();
      expect(restored.lastLessonId, 'assembly');
      expect(restored.steps['assembly'], 3);
      expect(restored.statuses['tracks'], TrainingLessonStatus.skipped);
      expect(restored.statuses['assembly'], TrainingLessonStatus.read);
    },
  );

  test(
    'keeps user/domain progress isolated and old tutorial flags untouched',
    () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('tutorial_tracks', true);
      final first = TrainingProgressStore(prefs, accountKey: 'a:42');
      await first.save(const TrainingProgress().visit('tracks', 1));
      expect(
        TrainingProgressStore(prefs, accountKey: 'b:42').read().steps,
        isEmpty,
      );
      expect(
        TrainingProgressStore(prefs, accountKey: 'a:43').read().steps,
        isEmpty,
      );
      expect(prefs.getBool('tutorial_tracks'), isTrue);
      expect(first.read().steps['tracks'], 1);
    },
  );

  test('reading and skipping do not erase exercise success', () {
    final progress = const TrainingProgress()
        .visit('assembly', 0, status: TrainingLessonStatus.practiced)
        .visit('assembly', 1, status: TrainingLessonStatus.read)
        .visit('assembly', 2, status: TrainingLessonStatus.skipped);
    expect(progress.statuses['assembly'], TrainingLessonStatus.practiced);
    final read = const TrainingProgress()
        .visit('tracks', 0, status: TrainingLessonStatus.read)
        .visit('tracks', 1);
    expect(read.statuses['tracks'], TrainingLessonStatus.read);
  });

  test('invalid storage recovers without touching other preferences', () async {
    final prefs = await SharedPreferences.getInstance();
    final store = TrainingProgressStore(prefs, accountKey: 'a:42');
    await prefs.setString(store.storageKey, '{broken');
    expect(store.read().steps, isEmpty);
    await prefs.setInt(store.storageKey, 3);
    expect(store.read().statuses, isEmpty);
    final parsed = TrainingProgress.fromJson({
      'lastLessonId': 5,
      'steps': {'negative': -1, 'text': '2', 'assembly': 2},
      'statuses': {'unknown': 'futureValue', 'assembly': 'read'},
    });
    expect(parsed.lastLessonId, isNull);
    expect(parsed.steps, {'assembly': 2});
    expect(parsed.statuses, {'assembly': TrainingLessonStatus.read});
  });
}
