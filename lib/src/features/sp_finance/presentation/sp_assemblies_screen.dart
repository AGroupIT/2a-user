import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/ui/tutorial_card.dart';
import '../../../core/ui/app_colors.dart';
import '../../../core/ui/app_layout.dart';
import '../../../core/ui/scroll_to_top_button.dart';
import '../../../core/ui/empty_state.dart';
import '../data/sp_models.dart';
import '../data/sp_provider.dart';
import 'sp_finance_ui.dart';

class SpAssembliesScreen extends ConsumerStatefulWidget {
  const SpAssembliesScreen({super.key});

  @override
  ConsumerState<SpAssembliesScreen> createState() => _SpAssembliesScreenState();
}

class _SpAssembliesScreenState extends ConsumerState<SpAssembliesScreen> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _assembliesListKey = GlobalKey();
  final GlobalKey _firstAssemblyKey = GlobalKey();
  @override
  void initState() {
    super.initState();
    // Загружаем сборки сразу при инициализации
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(spAssembliesControllerProvider.notifier).loadAssemblies();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(spAssembliesControllerProvider);
    final topPad = AppLayout.topBarTotalHeight(context);
    final bottomPad = AppLayout.bottomScrollPadding(context);

    if (state.isLoading && state.assemblies.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null && state.assemblies.isEmpty) {
      return EmptyState(
        icon: Icons.error_outline,
        title: 'Ошибка загрузки',
        message: state.error!,
      );
    }

    return TutorialScreenWrapper(
      screenKey: 'sp_assemblies',
      steps: [
        TutorialStep(
          icon: Icons.inventory_2_rounded,
          title: 'Совместные покупки',
          description:
              'Сборка объединяет несколько треков в одну партию. Здесь видны статус и итоговая стоимость каждой группы.',
          targetKey: _assembliesListKey,
        ),
        TutorialStep(
          icon: Icons.group_rounded,
          title: 'Детали сборки',
          description:
              'Нажмите на сборку, чтобы увидеть всех участников, их треки, вес и долю в общем счёте.',
          targetKey: _firstAssemblyKey,
        ),
        TutorialStep(
          icon: Icons.notifications_rounded,
          title: 'Уведомления о статусе',
          description:
              'При изменении статуса сборки вы получите push-уведомление. Статусы: новая → упакована → отправлена.',
          targetKey: _firstAssemblyKey,
        ),
      ],
      child: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () async {
              await ref
                  .read(spAssembliesControllerProvider.notifier)
                  .loadAssemblies();
            },
            color: context.brandPrimary,
            child: ListView(
              controller: _scrollController,
              key: _assembliesListKey,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                16,
                topPad * 0.7 + 16,
                16,
                bottomPad + 16,
              ),
              children: [
                const SpPageHeader(title: 'Совместные покупки'),
                const SizedBox(height: 12),
                const _SpAssembliesHero(),
                const SizedBox(height: 14),
                if (state.assemblies.isEmpty)
                  const _SpEmptyCard()
                else
                  ...state.assemblies.asMap().entries.map((entry) {
                    final card = _AssemblyCard(assembly: entry.value);
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: entry.key == state.assemblies.length - 1
                            ? 0
                            : 12,
                      ),
                      child: entry.key == 0
                          ? KeyedSubtree(key: _firstAssemblyKey, child: card)
                          : card,
                    );
                  }),
              ],
            ),
          ),
          ScrollToTopButton(controller: _scrollController),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}

class _SpAssembliesHero extends StatelessWidget {
  const _SpAssembliesHero();

  @override
  Widget build(BuildContext context) {
    return SpAnimatedHeroSurface(
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
            ),
            child: const Icon(
              Icons.groups_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Финансы совместных покупок',
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'Gilroy',
                    fontSize: 22,
                    height: 1.04,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.25,
                  ),
                ),
                SizedBox(height: 7),
                Text(
                  'Проверяйте участников, заполненность треков, оплату и итоговую прибыль по каждой сборке.',
                  style: TextStyle(
                    color: Color(0xE6FFFFFF),
                    fontFamily: 'Gilroy',
                    fontSize: 13,
                    height: 1.2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SpEmptyCard extends StatelessWidget {
  const _SpEmptyCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: SpFinanceUi.cardDecoration(),
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: context.brandPrimary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              Icons.shopping_cart_outlined,
              size: 26,
              color: context.brandPrimary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Нет совместных покупок',
                  style: SpFinanceUi.sectionTitleStyle,
                ),
                const SizedBox(height: 4),
                const Text(
                  'Заполните СП-данные в треках сборок — они появятся здесь автоматически.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontFamily: 'Gilroy',
                    fontSize: 13,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AssemblyCard extends StatelessWidget {
  final SpAssembly assembly;

  const _AssemblyCard({required this.assembly});

  bool _isTrackComplete(SpTrack track) {
    return track.spParticipantName != null &&
        track.spParticipantName!.isNotEmpty &&
        track.clientPriceYuan != null &&
        track.clientPriceYuan! > 0 &&
        track.netWeightKg != null &&
        track.netWeightKg! > 0 &&
        track.purchaseRate != null &&
        track.purchaseRate! > 0;
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd.MM.yyyy');
    final spTracks = assembly.tracks
        .where(
          (t) => t.spParticipantName != null && t.spParticipantName!.isNotEmpty,
        )
        .toList();
    final incompleteCount = spTracks.where((t) => !_isTrackComplete(t)).length;
    final paidCount = assembly.stats.participants.where((p) => p.isPaid).length;
    final participantsCount = assembly.stats.participants.length;
    final hasProfit = assembly.stats.totalProfitRub >= 0;

    return Container(
      decoration: SpFinanceUi.cardDecoration(),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: () => context.push('/sp-finance/assemblies/${assembly.id}'),
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: context.brandPrimary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Icon(
                        Icons.inventory_2_rounded,
                        color: context.brandPrimary,
                        size: 25,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            assembly.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontFamily: 'Gilroy',
                              fontSize: 18,
                              height: 22 / 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.add_circle_outline_rounded,
                                size: 15,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  dateFormat.format(assembly.createdAt),
                                  style: SpFinanceUi.labelStyle,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    _CompactStatusPill(
                      label: assembly.statusDisplayName,
                      color:
                          SpFinanceUi.parseHexColor(assembly.statusColor) ??
                          context.brandPrimary,
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: SpFinanceUi.softDecoration(context),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _StatItem(
                              icon: Icons.people_rounded,
                              label: 'Участники',
                              value: '$participantsCount',
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _StatItem(
                              icon: Icons.shopping_bag_rounded,
                              label: 'Треки СП',
                              value:
                                  '${assembly.stats.tracksWithSP}/${assembly.stats.tracksTotal}',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _StatItem(
                              icon: Icons.scale_rounded,
                              label: 'Чистый вес',
                              value:
                                  '${assembly.stats.totalNetWeightKg.toStringAsFixed(2)} кг',
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _StatItem(
                              icon: Icons.trending_up_rounded,
                              label: 'Прибыль',
                              value:
                                  '${assembly.stats.totalProfitRub.toStringAsFixed(0)} ₽',
                              color: hasProfit
                                  ? Colors.green.shade700
                                  : Colors.red.shade700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (spTracks.isNotEmpty || participantsCount > 0) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (spTracks.isNotEmpty)
                        _CompactStatusPill(
                          label: incompleteCount == 0
                              ? 'Треки заполнены'
                              : 'Не заполнено $incompleteCount/${spTracks.length}',
                          color: incompleteCount == 0
                              ? Colors.green.shade700
                              : Colors.orange.shade700,
                        ),
                      if (participantsCount > 0)
                        _CompactStatusPill(
                          label: paidCount == participantsCount
                              ? 'Все оплатили'
                              : 'Оплата $paidCount/$participantsCount',
                          color: paidCount == participantsCount
                              ? Colors.green.shade700
                              : context.brandPrimary,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CompactStatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _CompactStatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontFamily: 'Gilroy',
              fontSize: 11.5,
              height: 1,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? color;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedColor = color ?? context.brandPrimary;
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: resolvedColor.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, size: 16, color: resolvedColor),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: SpFinanceUi.labelStyle.copyWith(fontSize: 10.5),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  color: resolvedColor,
                  fontFamily: 'Gilroy',
                  fontSize: 13.5,
                  height: 1,
                  fontWeight: FontWeight.w900,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
