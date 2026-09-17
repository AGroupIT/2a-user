import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/persistence/shared_preferences_provider.dart';
import '../../../core/utils/locale_text.dart';
import '../../auth/data/auth_provider.dart';
import '../../tracks/presentation/tracks_screen.dart';
import '../application/assembly_training_provider.dart';
import '../data/assembly_training_session.dart';
import '../data/training_progress.dart';
import '../data/training_tour_controller.dart';
import 'assembly_practice_steps.dart';

/// The production screen, using a disposable local data session.
class AssemblyPracticeScreen extends ConsumerStatefulWidget {
  const AssemblyPracticeScreen({super.key});

  @override
  ConsumerState<AssemblyPracticeScreen> createState() =>
      _AssemblyPracticeScreenState();
}

class _AssemblyPracticeScreenState
    extends ConsumerState<AssemblyPracticeScreen> {
  late final AssemblyTrainingSession _session;
  TrainingTourController? _controller;
  late final TrainingProgressStore _store;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _session = ref.read(assemblyTrainingSessionProvider);
    _controller = ref.read(assemblyPracticeControllerProvider);
    final auth = ref.read(authProvider);
    _store = TrainingProgressStore(
      ref.read(sharedPreferencesProvider),
      accountKey: '${auth.userDomain ?? ''}:${auth.clientId}',
    );
    _session.addListener(_recordCompletion);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _controller?.start(
        assemblyPracticeSteps(context).map((step) => step.id).toList(),
        resume: false,
      );
    });
  }

  Future<void> _recordCompletion() async {
    if (_saved || !_session.assemblyCreated) return;
    _saved = true;
    var saved = false;
    try {
      saved = await _store.save(
        _store.read().visit(
          'assembly',
          5,
          status: TrainingLessonStatus.practiced,
        ),
      );
    } catch (_) {
      saved = false;
    }
    if (!mounted) return;
    _saved = saved;
    if (!saved) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(
              context,
              ru: 'Не удалось сохранить прохождение. Повторите сохранение.',
              zh: '无法保存练习进度，请重试。',
            ),
          ),
          action: SnackBarAction(
            label: tr(context, ru: 'Повторить', zh: '重试'),
            onPressed: _recordCompletion,
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _session.removeListener(_recordCompletion);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(assemblyTrainingSessionProvider);
    return UncontrolledProviderScope(
      container: session.container,
      child: const TracksScreen(),
    );
  }
}
