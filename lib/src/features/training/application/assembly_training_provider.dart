import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/assembly_training_session.dart';
import '../../../core/persistence/shared_preferences_provider.dart';
import '../../auth/data/auth_provider.dart';
import '../data/training_tour_controller.dart';
import '../presentation/training_target.dart';

/// Shared only by the active practice route and its existing tour overlay.
final assemblyTrainingSessionProvider =
    Provider.autoDispose<AssemblyTrainingSession>((ref) {
      final session = AssemblyTrainingSession(
        registry: ref.watch(trainingTargetRegistryProvider),
      );
      ref.onDispose(session.dispose);
      return session;
    });

// Practice has its own progress key; it cannot overwrite the main tour resume.
final assemblyPracticeControllerProvider = Provider<TrainingTourController?>((
  ref,
) {
  final identity = ref.watch(
    authProvider.select(
      (auth) => (auth.isLoggedIn, auth.userDomain, auth.clientId),
    ),
  );
  if (!identity.$1 || identity.$3 == null) return null;
  final controller = TrainingTourController(
    ref.watch(sharedPreferencesProvider),
    scopeKey: '${identity.$2}:${identity.$3}:assembly-practice',
  );
  ref.onDispose(controller.dispose);
  return controller;
});
