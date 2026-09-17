import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/persistence/shared_preferences_provider.dart';
import '../../auth/data/auth_provider.dart';
import '../../clients/application/client_codes_controller.dart';
import '../data/training_tour_controller.dart';

final trainingTourControllerProvider = Provider<TrainingTourController?>((ref) {
  final identity = ref.watch(
    authProvider.select(
      (auth) => (auth.isLoggedIn, auth.userDomain, auth.clientId),
    ),
  );
  final code = ref.watch(activeClientCodeProvider);
  if (!identity.$1 || identity.$3 == null) return null;
  final controller = TrainingTourController(
    ref.watch(sharedPreferencesProvider),
    scopeKey: '${identity.$2 ?? ''}:${identity.$3}:${code ?? ''}',
  );
  ref.onDispose(controller.dispose);
  return controller;
});
