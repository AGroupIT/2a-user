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
    final bottomPad = MediaQuery.paddingOf(context).bottom;

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

    if (state.assemblies.isEmpty) {
      return EmptyState(
        icon: Icons.shopping_cart_outlined,
        title: 'Нет совместных покупок',
        message: 'Заполните СП данные в треках ваших сборок, и они появятся здесь',
      );
    }

    return TutorialScreenWrapper(
      screenKey: 'sp_assemblies',
      steps: [
        TutorialStep(
          icon: Icons.inventory_2_rounded,
          title: 'Совместные покупки',
          description: 'Сборка объединяет несколько треков в одну партию. Здесь видны статус и итоговая стоимость каждой группы.',
          targetKey: _assembliesListKey,
        ),
        TutorialStep(
          icon: Icons.group_rounded,
          title: 'Детали сборки',
          description: 'Нажмите на сборку, чтобы увидеть всех участников, их треки, вес и долю в общем счёте.',
          targetKey: _firstAssemblyKey,
        ),
        TutorialStep(
          icon: Icons.notifications_rounded,
          title: 'Уведомления о статусе',
          description: 'При изменении статуса сборки вы получите push-уведомление. Статусы: новая → упакована → отправлена.',
          targetKey: _firstAssemblyKey,
        ),
      ],
      child: Stack(
      children: [
      RefreshIndicator(
        onRefresh: () async {
          await ref.read(spAssembliesControllerProvider.notifier).loadAssemblies();
        },
        color: context.brandPrimary,
      child: ListView.builder(
        controller: _scrollController,
        key: _assembliesListKey,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          16,
          topPad * 0.7 + 16,
          16,
          24 + bottomPad,
        ),
        itemCount: state.assemblies.length + 1, // +1 для заголовка
        itemBuilder: (context, i) {
          if (i == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Text(
                'Совместные покупки',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
            );
          }

          final assembly = state.assemblies[i - 1];
          final card = _AssemblyCard(assembly: assembly);
          return Padding(
            padding: EdgeInsets.only(bottom: i == state.assemblies.length ? 0 : 12),
            child: i == 1
                ? KeyedSubtree(key: _firstAssemblyKey, child: card)
                : card,
          );
        },
      ),
    ),
    ScrollToTopButton(controller: _scrollController),
    ],
    ));
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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
  List<Widget> _buildFillStatus(BuildContext context, ThemeData theme) {
    // Считаем только треки которые участвуют в СП
    final spTracks = assembly.tracks
        .where((t) => t.spParticipantName != null && t.spParticipantName!.isNotEmpty)
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
              Icon(Icons.check_circle_rounded, size: 16, color: Colors.green.shade700),
              const SizedBox(width: 8),
              Text(
                'Все треки заполнены',
                style: theme.textTheme.bodySmall?.copyWith(
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
            Icon(Icons.warning_rounded, size: 16, color: Colors.orange.shade700),
            const SizedBox(width: 8),
            Text(
              'Не заполнено треков: $incompleteCount из ${spTracks.length}',
              style: theme.textTheme.bodySmall?.copyWith(
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
  List<Widget> _buildPaymentStatus(BuildContext context, ThemeData theme) {
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
              Icon(Icons.payments_rounded, size: 16, color: Colors.blue.shade700),
              const SizedBox(width: 8),
              Text(
                'Все участники оплатили',
                style: theme.textTheme.bodySmall?.copyWith(
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
            Icon(Icons.payments_rounded, size: 16, color: Colors.purple.shade700),
            const SizedBox(width: 8),
            Text(
              'Оплатили: $paidCount из $totalCount',
              style: theme.textTheme.bodySmall?.copyWith(
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
    final theme = Theme.of(context);
    final dateFormat = DateFormat('dd.MM.yyyy');

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: () {
            context.push('/sp-finance/assemblies/${assembly.id}');
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              // Заголовок
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: context.brandPrimary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.inventory_2_rounded,
                      color: context.brandPrimary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          assembly.displayName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          dateFormat.format(assembly.createdAt),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.grey,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Статистика
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _StatItem(
                            icon: Icons.people_rounded,
                            label: 'Участников',
                            value: assembly.stats.participants.length.toString(),
                          ),
                        ),
                        Expanded(
                          child: _StatItem(
                            icon: Icons.shopping_bag_rounded,
                            label: 'Треков СП',
                            value: '${assembly.stats.tracksWithSP}/${assembly.stats.tracksTotal}',
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
                            value: '${assembly.stats.totalNetWeightKg.toStringAsFixed(2)} кг',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Статус заполненности треков
              ..._buildFillStatus(context, theme),

              // Статус оплаты участников
              ..._buildPaymentStatus(context, theme),

              // Прибыль
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
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
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${assembly.stats.totalProfitRub.toStringAsFixed(0)} ₽',
                      style: theme.textTheme.bodyMedium?.copyWith(
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
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 6),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: Colors.grey.shade600,
                  fontSize: 10,
                ),
              ),
              Text(
                value,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
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
