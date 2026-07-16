import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'update_service.dart';

typedef AppUpdateChecker = Future<UpdateInfo?> Function();

final appUpdateCheckerProvider = Provider<AppUpdateChecker>((ref) {
  return () => UpdateService.checkForUpdate(rethrowErrors: true);
});

enum AppUpdateGatePhase { idle, checking, optional, required }

@immutable
class AppUpdateGateState {
  final AppUpdateGatePhase phase;
  final UpdateInfo? update;

  const AppUpdateGateState({this.phase = AppUpdateGatePhase.idle, this.update});
}

final appUpdateGateProvider =
    NotifierProvider<AppUpdateGateNotifier, AppUpdateGateState>(
      AppUpdateGateNotifier.new,
    );

class AppUpdateGateNotifier extends Notifier<AppUpdateGateState> {
  bool _isChecking = false;

  @override
  AppUpdateGateState build() => const AppUpdateGateState();

  Future<void> check({required String reason}) async {
    if (_isChecking || state.phase == AppUpdateGatePhase.required) return;
    _isChecking = true;

    if (state.phase == AppUpdateGatePhase.idle) {
      state = const AppUpdateGateState(phase: AppUpdateGatePhase.checking);
    }

    try {
      final update = await ref.read(appUpdateCheckerProvider).call();
      if (state.phase == AppUpdateGatePhase.required) return;
      if (update == null) {
        state = const AppUpdateGateState();
        return;
      }

      if (update.isForced) {
        state = AppUpdateGateState(
          phase: AppUpdateGatePhase.required,
          update: update,
        );
        return;
      }

      final dismissed = await UpdateService.isDismissedRecently(
        update.latestVersion,
      );
      if (state.phase == AppUpdateGatePhase.required) return;
      state = dismissed
          ? const AppUpdateGateState()
          : AppUpdateGateState(
              phase: AppUpdateGatePhase.optional,
              update: update,
            );
    } catch (error) {
      debugPrint('[AppUpdateGate] Check failed ($reason): $error');
      if (state.phase != AppUpdateGatePhase.required) {
        state = const AppUpdateGateState();
      }
    } finally {
      _isChecking = false;
    }
  }

  void requireFromServer(Map<String, dynamic> payload) {
    if (payload['code'] != 'APP_UPDATE_REQUIRED') return;
    final update = UpdateService.fromServerPayload(payload);
    if (update == null) return;
    state = AppUpdateGateState(
      phase: AppUpdateGatePhase.required,
      update: update,
    );
  }

  Future<void> dismissOptional() async {
    final update = state.update;
    if (state.phase != AppUpdateGatePhase.optional || update == null) return;
    await UpdateService.dismissVersion(update.latestVersion);
    if (state.phase == AppUpdateGatePhase.optional &&
        state.update?.latestVersion == update.latestVersion) {
      state = const AppUpdateGateState();
    }
  }
}
