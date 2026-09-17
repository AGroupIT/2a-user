import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/persistence/shared_preferences_provider.dart';
import '../../../core/ui/app_layout.dart';
import '../../../core/utils/locale_text.dart';
import '../../auth/data/auth_provider.dart';
import '../data/training_progress.dart';
import '../application/training_tour_provider.dart';
import 'training_screen.dart';
import 'training_tour_steps.dart';
import 'assembly_practice_steps.dart';

class TrainingEntryScreen extends ConsumerWidget {
  final String? initialLessonId;
  final bool initialPractice;

  const TrainingEntryScreen({
    super.key,
    this.initialLessonId,
    this.initialPractice = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    if (auth.clientId == null) {
      return Center(
        child: Text(tr(context, ru: 'Загружаем кабинет…', zh: '正在加载账户…')),
      );
    }
    final accountKey = '${auth.userDomain ?? ''}:${auth.clientId}';
    return TrainingScreen(
      key: ValueKey('$accountKey:$initialLessonId:$initialPractice'),
      initialLessonId: initialLessonId,
      initialPractice: initialPractice,
      onStartPractice: () {
        ref.read(trainingTourControllerProvider)?.stop();
        context.go(assemblyPracticeRoute);
      },
      onStartTour: () {
        ref
            .read(trainingTourControllerProvider)
            ?.start(trainingTourSteps(context).map((step) => step.id).toList());
      },
      onShowInApp: (lessonId, stepIndex) {
        if (lessonId == 'assembly') {
          ref.read(trainingTourControllerProvider)?.stop();
          context.go(assemblyPracticeRoute);
          return;
        }
        ref
            .read(trainingTourControllerProvider)
            ?.start(
              trainingTourSteps(context)
                  .where((step) => step.lessonId == lessonId)
                  .map((step) => step.id)
                  .toList(),
              initialStepId: '$lessonId:$stepIndex',
            );
      },
      store: TrainingProgressStore(
        ref.watch(sharedPreferencesProvider),
        accountKey: accountKey,
      ),
      // AppScaffold already reserves the status bar inset.
      topPadding: AppLayout.useSideNavigation(context)
          ? 0
          : AppLayout.topBarTopMarginFor(context) +
                AppLayout.topBarHeightFor(context) +
                AppLayout.topBarBottomGapFor(context),
    );
  }
}
