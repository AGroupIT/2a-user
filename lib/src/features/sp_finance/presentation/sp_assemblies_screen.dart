import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/ui/tutorial_card.dart';
import '../../../core/ui/app_colors.dart';
import '../../../core/ui/app_layout.dart';
import '../../../core/ui/app_page_header.dart';
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
                const AppPageHeader(
                  title: 'Совместные покупки',
                  showBack: true,
                ),
                const SizedBox(height: 15),
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

class _SpEmptyCard extends StatelessWidget {
  const _SpEmptyCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: SpFinanceUi.cardDecoration(),
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            size: 28,
            color: context.brandPrimary,
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
                Text(
                  'Заполните СП данные в треках ваших сборок, и они появятся здесь',
                  style: SpFinanceUi.bodyStyle.copyWith(
                    color: SpFinanceUi.mutedTextColor,
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

  /// Проверяет, заполнен ли трек полностью
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

  /// Строит виджет статуса заполненности
  List<Widget> _buildFillStatus(BuildContext context) {
    // Считаем только треки которые участвуют в СП
    final spTracks = assembly.tracks
        .where(
          (t) => t.spParticipantName != null && t.spParticipantName!.isNotEmpty,
        )
        .toList();

    if (spTracks.isEmpty) {
      return [];
    }

    final incompleteCount = spTracks.where((t) => !_isTrackComplete(t)).length;

    if (incompleteCount == 0) {
      return [
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green.shade200),
          ),
          child: Row(
            children: [
              Icon(
                Icons.check_circle_rounded,
                size: 16,
                color: Colors.green.shade700,
              ),
              const SizedBox(width: 8),
              Text(
                'Все треки заполнены',
                style: SpFinanceUi.bodyStyle.copyWith(
                  color: Colors.green.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ];
    }

    return [
      const SizedBox(height: 12),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange.shade200),
        ),
        child: Row(
          children: [
            Icon(
              Icons.warning_rounded,
              size: 16,
              color: Colors.orange.shade700,
            ),
            const SizedBox(width: 8),
            Text(
              'Не заполнено треков: $incompleteCount из ${spTracks.length}',
              style: SpFinanceUi.bodyStyle.copyWith(
                color: Colors.orange.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    ];
  }

  /// Строит виджет статуса оплаты участников
  List<Widget> _buildPaymentStatus(BuildContext context) {
    final participants = assembly.stats.participants;
    if (participants.isEmpty) {
      return [];
    }

    final paidCount = participants.where((p) => p.isPaid).length;
    final totalCount = participants.length;

    if (paidCount == totalCount) {
      return [
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Row(
            children: [
              Icon(
                Icons.payments_rounded,
                size: 16,
                color: Colors.blue.shade700,
              ),
              const SizedBox(width: 8),
              Text(
                'Все участники оплатили',
                style: SpFinanceUi.bodyStyle.copyWith(
                  color: Colors.blue.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ];
    }

    return [
      const SizedBox(height: 8),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.purple.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.purple.shade200),
        ),
        child: Row(
          children: [
            Icon(
              Icons.payments_rounded,
              size: 16,
              color: Colors.purple.shade700,
            ),
            const SizedBox(width: 8),
            Text(
              'Оплатили: $paidCount из $totalCount',
              style: SpFinanceUi.bodyStyle.copyWith(
                color: Colors.purple.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd.MM.yyyy');

    return Container(
      decoration: SpFinanceUi.cardDecoration(),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: () {
            context.push('/sp-finance/assemblies/${assembly.id}');
          },
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Заголовок
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: context.brandPrimary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.inventory_2_rounded,
                        color: context.brandPrimary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            assembly.displayName,
                            style: const TextStyle(
                              color: SpFinanceUi.textColor,
                              fontFamily: 'Gilroy',
                              fontSize: 18,
                              height: 22 / 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            dateFormat.format(assembly.createdAt),
                            style: SpFinanceUi.labelStyle,
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                  ],
                ),
                const SizedBox(height: 16),

                // Статистика
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
                              label: 'Участников',
                              value: assembly.stats.participants.length
                                  .toString(),
                            ),
                          ),
                          Expanded(
                            child: _StatItem(
                              icon: Icons.shopping_bag_rounded,
                              label: 'Треков СП',
                              value:
                                  '${assembly.stats.tracksWithSP}/${assembly.stats.tracksTotal}',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _StatItem(
                              icon: Icons.inventory_2_rounded,
                              label: 'Грязный вес',
                              value: assembly.stats.grossWeightKg != null
                                  ? '${assembly.stats.grossWeightKg!.toStringAsFixed(2)} кг'
                                  : '— кг',
                            ),
                          ),
                          Expanded(
                            child: _StatItem(
                              icon: Icons.scale_rounded,
                              label: 'Чистый вес',
                              value:
                                  '${assembly.stats.totalNetWeightKg.toStringAsFixed(2)} кг',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Статус заполненности треков
                ..._buildFillStatus(context),

                // Статус оплаты участников
                ..._buildPaymentStatus(context),

                // Прибыль
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 12,
                  ),
                  decoration: BoxDecoration(
                    color: assembly.stats.totalProfitRub > 0
                        ? Colors.green.shade50
                        : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Прибыль:',
                        style: SpFinanceUi.bodyStyle.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${assembly.stats.totalProfitRub.toStringAsFixed(0)} ₽',
                        style: SpFinanceUi.bodyStyle.copyWith(
                          fontWeight: FontWeight.w700,
                          color: assembly.stats.totalProfitRub > 0
                              ? Colors.green.shade700
                              : Colors.red.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 6),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: SpFinanceUi.labelStyle.copyWith(fontSize: 10)),
              Text(
                value,
                style: const TextStyle(
                  color: SpFinanceUi.textColor,
                  fontFamily: 'Gilroy',
                  fontSize: 13,
                  height: 15 / 13,
                  fontWeight: FontWeight.w700,
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
