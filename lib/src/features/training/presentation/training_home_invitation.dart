import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/persistence/shared_preferences_provider.dart';
import '../../../core/ui/app_colors.dart';
import '../../../core/utils/locale_text.dart';
import '../../auth/data/auth_provider.dart';
import '../application/training_tour_provider.dart';
import 'training_tour_steps.dart';
import 'training_ui.dart';

class TrainingHomeInvitation extends ConsumerWidget {
  const TrainingHomeInvitation({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identity = ref.watch(
      authProvider.select((auth) => (auth.userDomain, auth.clientId)),
    );
    if (identity.$2 == null) return const SizedBox.shrink();
    final scope = '${identity.$1 ?? ''}:${identity.$2}';
    return TrainingInvitationCard(
      key: ValueKey(scope),
      preferences: ref.watch(sharedPreferencesProvider),
      accountKey: scope,
      onStart: () => ref
          .read(trainingTourControllerProvider)
          ?.start(trainingTourSteps(context).map((step) => step.id).toList()),
    );
  }
}

class TrainingInvitationCard extends StatefulWidget {
  final SharedPreferences preferences;
  final String accountKey;
  final VoidCallback onStart;

  const TrainingInvitationCard({
    super.key,
    required this.preferences,
    required this.accountKey,
    required this.onStart,
  });

  @override
  State<TrainingInvitationCard> createState() => _TrainingInvitationCardState();
}

class _TrainingInvitationCardState extends State<TrainingInvitationCard> {
  bool _hidden = false;
  bool _saving = false;
  bool _error = false;

  String get _key =>
      'training_invitation_v1_${Uri.encodeComponent(widget.accountKey)}';

  @override
  void initState() {
    super.initState();
    _hidden = widget.preferences.getBool(_key) ?? false;
  }

  Future<void> _hide() async {
    setState(() => _saving = true);
    var ok = false;
    try {
      ok = await widget.preferences.setBool(_key, true);
    } catch (_) {
      ok = false;
    }
    if (!mounted) return;
    setState(() {
      _hidden = ok;
      _saving = false;
      _error = !ok;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_hidden) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: TrainingUi.cardDecoration,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: context.brandPrimary.withValues(alpha: 0.09),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    Icons.school_rounded,
                    color: context.brandPrimary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    tr(
                      context,
                      ru: 'Познакомьтесь с приложением',
                      zh: '了解应用功能',
                    ),
                    style: TrainingUi.title.copyWith(
                      fontSize: 16,
                      height: 1.15,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              tr(
                context,
                ru: 'Где тарифы и самовыкуп? Как отправить треки на сборку? Покажем прямо на экранах.',
                zh: '运价和自助采购在哪里？如何提交集运？我们将在页面中为您演示。',
              ),
              style: TrainingUi.body,
            ),
            if (_error)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  tr(
                    context,
                    ru: 'Не удалось сохранить выбор. Попробуйте ещё раз.',
                    zh: '无法保存设置，请重试。',
                  ),
                  style: TrainingUi.caption.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('training-home-start'),
                onPressed: _saving ? null : widget.onStart,
                style: TrainingUi.primaryButton(context),
                child: Text(
                  tr(context, ru: 'Начать экскурсию', zh: '开始导览'),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            Align(
              alignment: Alignment.center,
              child: TextButton(
                key: const Key('training-home-dismiss'),
                onPressed: _saving ? null : _hide,
                style: TrainingUi.textButton(context),
                child: Text(
                  tr(context, ru: 'Больше не показывать', zh: '不再显示'),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            Text(
              tr(
                context,
                ru: 'Обучение всегда доступно в меню «Ещё».',
                zh: '您可随时在“更多”菜单中进入学习。',
              ),
              style: TrainingUi.caption,
            ),
          ],
        ),
      ),
    );
  }
}
