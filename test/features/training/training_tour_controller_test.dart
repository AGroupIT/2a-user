import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:twoalogisticcabineuser/src/features/training/data/training_tour_controller.dart';

class _ControlledPreferences extends Mock implements SharedPreferences {
  _ControlledPreferences(this.preferences);

  final SharedPreferences preferences;

  final writes = <Completer<bool>>[];
  final values = <String>[];

  @override
  String? getString(String key) => preferences.getString(key);

  @override
  Future<bool> setString(String key, String value) async {
    final completion = Completer<bool>();
    writes.add(completion);
    values.add(value);
    if (!await completion.future) return false;
    return preferences.setString(key, value);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const steps = ['tracks:0', 'assembly:0', 'payments:0'];

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'stopped excursion persists its position and resumes after recreation',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final first = TrainingTourController(prefs, scopeKey: 'client-a');
      first.start(steps);
      first.next();
      first.stop();
      await first.settled;
      expect(first.active, isFalse);
      first.dispose();

      await prefs.reload();
      final restored = TrainingTourController(prefs, scopeKey: 'client-a');
      addTearDown(restored.dispose);
      expect(restored.resumeId, 'assembly:0');
      restored.start(steps);
      expect(restored.currentId, 'assembly:0');
      expect(restored.viewed, {'tracks:0'});
      expect(restored.active, isTrue);
      await restored.settled;
    },
  );

  test(
    'previous preserves viewing history while skip does not mark viewed',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final controller = TrainingTourController(prefs, scopeKey: 'client-a');
      addTearDown(controller.dispose);
      controller.start(steps);
      controller.previous();
      expect(controller.index, 0);
      controller.next();
      controller.next(skip: true);
      expect(controller.currentId, 'payments:0');
      expect(controller.viewed, {'tracks:0'});
      controller.previous();
      expect(controller.currentId, 'assembly:0');
      expect(controller.viewed, {'tracks:0'});
      controller.next();
      expect(controller.viewed, {'tracks:0', 'assembly:0'});
      await controller.settled;
    },
  );

  test(
    'completion saves explanations only and preserves business preferences',
    () async {
      SharedPreferences.setMockInitialValues({
        'terms_accepted': true,
        'assembly_created': false,
        'payment_completed': false,
        'client_code': 'A-123',
      });
      final prefs = await SharedPreferences.getInstance();
      final controller = TrainingTourController(prefs, scopeKey: 'client-a');
      addTearDown(controller.dispose);
      controller.start(steps);
      controller.next();
      controller.next();
      controller.next();
      controller.next();
      await controller.settled;
      expect(controller.complete, isTrue);
      expect(controller.viewed, steps.toSet());
      final snapshot =
          jsonDecode(prefs.getString(controller.storageKey)!) as Map;
      expect(snapshot.keys.toSet(), {'step', 'viewed'});
      expect(prefs.getBool('terms_accepted'), isTrue);
      expect(prefs.getBool('assembly_created'), isFalse);
      expect(prefs.getBool('payment_completed'), isFalse);
      expect(prefs.getString('client_code'), 'A-123');
      expect(prefs.getKeys(), {
        'terms_accepted',
        'assembly_created',
        'payment_completed',
        'client_code',
        controller.storageKey,
      });
    },
  );

  test(
    'finished excursion starts from the beginning on the next visit',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final controller = TrainingTourController(prefs, scopeKey: 'finished');
      addTearDown(controller.dispose);
      controller.start(steps);
      for (final _ in steps) {
        controller.next();
      }
      controller.stop();
      await controller.settled;
      final restored = TrainingTourController(prefs, scopeKey: 'finished');
      addTearDown(restored.dispose);
      expect(restored.resumeId, isNull);
      restored.start(steps);
      expect(restored.currentId, steps.first);
      expect(restored.viewed, steps.toSet());
      controller.start(steps);
      expect(controller.currentId, steps.first);
      await controller.settled;
      await restored.settled;
    },
  );

  test(
    'rapid next calls serialize storage writes and latest position survives',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final store = _ControlledPreferences(prefs);
      final controller = TrainingTourController(store, scopeKey: 'client-a');
      addTearDown(controller.dispose);
      controller.start(steps);
      controller.next();
      controller.next();
      await Future<void>.delayed(Duration.zero);
      expect(store.writes, hasLength(1));
      expect(jsonDecode(store.values.single)['step'], 'tracks:0');
      store.writes[0].complete(true);
      await Future<void>.delayed(Duration.zero);
      expect(store.writes, hasLength(2));
      expect(jsonDecode(store.values[1])['step'], 'assembly:0');
      store.writes[1].complete(true);
      await Future<void>.delayed(Duration.zero);
      expect(store.writes, hasLength(3));
      store.writes[2].complete(true);
      await controller.settled;
      await prefs.reload();
      final restored = TrainingTourController(prefs, scopeKey: 'client-a');
      addTearDown(restored.dispose);
      expect(restored.resumeId, 'payments:0');
      expect(restored.viewed, {'tracks:0', 'assembly:0'});
    },
  );

  test('account scope isolates position and viewing history', () async {
    final prefs = await SharedPreferences.getInstance();
    final a = TrainingTourController(prefs, scopeKey: 'account/a:code');
    final b = TrainingTourController(prefs, scopeKey: 'account/b:code');
    addTearDown(a.dispose);
    addTearDown(b.dispose);
    a.start(steps);
    a.next();
    b.start(steps);
    await Future.wait([a.settled, b.settled]);
    expect(a.storageKey, isNot(b.storageKey));
    expect(b.currentId, 'tracks:0');
    expect(b.viewed, isEmpty);
    final restored = TrainingTourController(prefs, scopeKey: 'account/a:code');
    addTearDown(restored.dispose);
    expect(restored.resumeId, 'assembly:0');
    expect(restored.viewed, {'tracks:0'});
  });

  for (final malformed in <Object>[
    '{broken',
    17,
    '[]',
    '{"step":42,"viewed":false}',
  ]) {
    test('malformed preferences recover: $malformed', () async {
      SharedPreferences.setMockInitialValues({
        'training_tour_v1_client-a': malformed,
      });
      final prefs = await SharedPreferences.getInstance();
      final controller = TrainingTourController(prefs, scopeKey: 'client-a');
      addTearDown(controller.dispose);
      controller.start(steps);
      expect(controller.currentId, 'tracks:0');
      expect(controller.viewed, isEmpty);
      await controller.settled;
    });
  }

  test(
    'removed resume step falls back safely and explicit restart wins',
    () async {
      SharedPreferences.setMockInitialValues({
        'training_tour_v1_client-a':
            '{"step":"removed:0","viewed":["tracks:0",42]}',
      });
      final prefs = await SharedPreferences.getInstance();
      final controller = TrainingTourController(prefs, scopeKey: 'client-a');
      addTearDown(controller.dispose);
      controller.start(steps);
      expect(controller.currentId, 'tracks:0');
      expect(controller.viewed, {'tracks:0'});
      controller.start(steps, initialStepId: 'payments:0');
      expect(controller.currentId, 'payments:0');
      controller.start(steps, resume: false);
      expect(controller.currentId, 'tracks:0');
      await controller.settled;
    },
  );

  test(
    'disposing during a failed pending save does not notify listeners',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final store = _ControlledPreferences(prefs);
      final controller = TrainingTourController(store, scopeKey: 'client-a');
      var notifications = 0;
      controller.addListener(() => notifications++);
      controller.start(steps);
      await Future<void>.delayed(Duration.zero);
      expect(store.writes, hasLength(1));
      final beforeDispose = notifications;
      controller.dispose();
      store.writes.single.complete(false);
      await expectLater(controller.settled, completes);
      expect(notifications, beforeDispose);
    },
  );
}
