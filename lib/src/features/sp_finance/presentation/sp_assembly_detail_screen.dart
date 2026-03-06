// TODO: Update to ShowcaseView.get() API when showcaseview 6.0.0 is released
// ignore_for_file: deprecated_member_use
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:showcaseview/showcaseview.dart';

import '../../../core/network/api_config.dart';
import '../../../core/services/showcase_service.dart';
import '../../../core/ui/app_colors.dart';
import '../../../core/utils/locale_text.dart';
import '../../assemblies/domain/box.dart';
import '../data/sp_models.dart';
import '../data/sp_provider.dart';

/// Показывает стилизованный SnackBar в едином дизайне приложения
void _showStyledSnackBar(
  BuildContext context,
  String message, {
  bool isError = false,
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.showSnackBar(
    SnackBar(
      content: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => messenger.hideCurrentSnackBar(),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isError
                    ? Icons.error_outline_rounded
                    : Icons.check_circle_outline_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
      behavior: SnackBarBehavior.floating,
      backgroundColor: isError ? const Color(0xFFE53935) : context.brandPrimary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 15),
      duration: const Duration(seconds: 3),
    ),
  );
}

class SpAssemblyDetailScreen extends ConsumerStatefulWidget {
  final int assemblyId;

  const SpAssemblyDetailScreen({super.key, required this.assemblyId});

  @override
  ConsumerState<SpAssemblyDetailScreen> createState() => _SpAssemblyDetailScreenState();
}

class _SpAssemblyDetailScreenState extends ConsumerState<SpAssemblyDetailScreen> {
  final _showcaseKeyStats = GlobalKey();
  final _showcaseKeyParticipants = GlobalKey();
  final _showcaseKeyTracks = GlobalKey();
  bool _showcaseStarted = false;
  bool _allSkipped = false;
  List<ShowcaseBlock> _currentRunBlocks = [];

  void _startShowcaseIfNeeded(BuildContext showcaseContext) {
    if (_showcaseStarted) return;
    if (!TickerMode.of(showcaseContext)) return;
    final pairs = [
      (_showcaseKeyStats, ShowcaseBlock.spAssemblyStats),
      (_showcaseKeyParticipants, ShowcaseBlock.spAssemblyParticipants),
      (_showcaseKeyTracks, ShowcaseBlock.spAssemblyTracks),
    ];
    final visible = pairs
        .where((p) => p.$1.currentContext != null && ref.read(showcaseBlockProvider(p.$2)))
        .toList();
    if (visible.isEmpty) { _showcaseStarted = false; return; }
    _showcaseStarted = true;
    _currentRunBlocks = visible.map((p) => p.$2).toSet().toList();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(showcasePendingBlocksProvider.notifier).setBlocks(_currentRunBlocks);
      startShowCaseSafe(showcaseContext, visible.map((p) => p.$1).toList());
    });
  }

  void _onShowcaseComplete() {
    for (final block in _currentRunBlocks) {
      ref.read(showcaseServiceProvider).markBlockAsSeen(block);
      ref.invalidate(showcaseBlockProvider(block));
    }
    _currentRunBlocks = [];
  }

  void _skipAllShowcases() {
    setState(() => _allSkipped = true);
    ref.read(showcaseServiceProvider).markAllBlocksSeen();
    for (final block in ShowcaseBlock.values) {
      ref.invalidate(showcaseBlockProvider(block));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(spAssembliesControllerProvider);
    final shouldShowStats = !_allSkipped && ref.watch(showcaseBlockProvider(ShowcaseBlock.spAssemblyStats));
    final shouldShowParticipants = !_allSkipped && ref.watch(showcaseBlockProvider(ShowcaseBlock.spAssemblyParticipants));
    final shouldShowTracks = !_allSkipped && ref.watch(showcaseBlockProvider(ShowcaseBlock.spAssemblyTracks));
    final assembly = state.assemblies.firstWhere(
      (a) => a.id == widget.assemblyId,
      orElse: () => throw Exception('Assembly not found'),
    );

    return ShowcaseWrapper(
      onComplete: _onShowcaseComplete,
      onSkipAll: _skipAllShowcases,
      child: Builder(
        builder: (showcaseContext) {
          _startShowcaseIfNeeded(showcaseContext);

          return Scaffold(
            body: RefreshIndicator(
              onRefresh: () async {
                await ref.read(spAssembliesControllerProvider.notifier).loadAssemblies();
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 60, 16, 16),
                children: [
                  // Заголовок
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Text(
                      assembly.displayName,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ),
                  shouldShowStats
                      ? Showcase(
                          key: _showcaseKeyStats,
                          title: '📊 Статистика сборки',
                          description: '• Треков — участвует в СП из общего\n'
                              '• Участников — уникальные в СП\n'
                              '• Доставка — общая сумма\n'
                              '• Вес — с упаковкой и без\n\n'
                              'Прибыль = сумма наценок.\n\n'
                              '👆 Нажмите для продолжения',
                          targetPadding: const EdgeInsets.all(8),
                          targetBorderRadius: BorderRadius.circular(20),
                          tooltipBackgroundColor: Colors.white,
                          textColor: Colors.black87,
                          titleTextStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1A1A1A),
                          ),
                          descTextStyle: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade600,
                          ),
                          child: _StatsSection(assembly: assembly),
                        )
                      : _StatsSection(assembly: assembly),
                  const SizedBox(height: 24),

                  // Коробки
                  if (assembly.boxes.isNotEmpty) ...[
                    _BoxesSection(assembly: assembly),
                    const SizedBox(height: 24),
                  ],

                  shouldShowParticipants
                      ? Showcase(
                          key: _showcaseKeyParticipants,
                          title: '👥 Участники СП',
                          description: '• Чекбокс — отметка оплаты\n'
                              '• Треки и вес — заказы участника\n'
                              '• Прибыль — ваша наценка\n\n'
                              'Разверните для деталей и копирования.\n\n'
                              '👆 Нажмите для продолжения',
                          targetPadding: const EdgeInsets.all(8),
                          targetBorderRadius: BorderRadius.circular(20),
                          tooltipBackgroundColor: Colors.white,
                          textColor: Colors.black87,
                          titleTextStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1A1A1A),
                          ),
                          descTextStyle: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade600,
                          ),
                          child: _ParticipantsSection(assembly: assembly),
                        )
                      : _ParticipantsSection(assembly: assembly),
                  const SizedBox(height: 24),
                  shouldShowTracks
                      ? Showcase(
                          key: _showcaseKeyTracks,
                          title: '📦 Треки сборки',
                          description: '• Зелёная рамка — данные заполнены\n'
                              '• Оранжевая — требуется заполнение\n\n'
                              'Видно: цена, доставка, итого, прибыль.\n'
                              'Нажмите на трек для редактирования.\n\n'
                              '✅ Нажмите для завершения',
                          targetPadding: const EdgeInsets.all(8),
                          targetBorderRadius: BorderRadius.circular(20),
                          tooltipBackgroundColor: Colors.white,
                          textColor: Colors.black87,
                          titleTextStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1A1A1A),
                          ),
                          descTextStyle: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade600,
                          ),
                          child: _TracksSection(assembly: assembly),
                        )
                      : _TracksSection(assembly: assembly),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _StatsSection extends StatelessWidget {
  final SpAssembly assembly;

  const _StatsSection({required this.assembly});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stats = assembly.stats;

    // Получаем данные из счета
    final invoice = assembly.invoices.isNotEmpty ? assembly.invoices[0] : null;
    final deliveryCostRub = invoice?.deliveryCostRub ?? 0;
    final grossWeightKg = stats.grossWeightKg ?? invoice?.weight ?? 0;
    final netWeightKg = stats.totalNetWeightKg;

    // Расчет стоимости за кг
    final costPerKgGross = grossWeightKg > 0 ? deliveryCostRub / grossWeightKg : 0.0;
    final costPerKgNet = netWeightKg > 0 ? deliveryCostRub / netWeightKg : 0.0;

    // Проверка на нераспределенные треки
    final hasUndistributed = stats.tracksWithSP < stats.tracksTotal;

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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Статистика',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),

            // Ряд 1: Треки и Участники
            Row(
              children: [
                Expanded(
                  child: _StatTile(
                    icon: Icons.shopping_bag_rounded,
                    label: 'Треков',
                    value: '${stats.tracksWithSP} / ${stats.tracksTotal}',
                    subtitle: hasUndistributed ? 'есть нераспред.' : null,
                    color: hasUndistributed ? Colors.orange.shade700 : null,
                  ),
                ),
                Expanded(
                  child: _StatTile(
                    icon: Icons.people_rounded,
                    label: 'Участников',
                    value: '${stats.participants.length}',
                  ),
                ),
              ],
            ),
            const Divider(height: 24),

            // Ряд 2: Доставка (по центру)
            Center(
              child: _StatTile(
                icon: Icons.local_shipping_rounded,
                label: 'Стоимость доставки',
                value: '${deliveryCostRub.toStringAsFixed(0)} ₽',
                color: Colors.purple.shade700,
              ),
            ),
            const Divider(height: 24),

            // Ряд 3: Грязный вес и стоимость за кг
            Row(
              children: [
                Expanded(
                  child: _StatTile(
                    icon: Icons.inventory_rounded,
                    label: 'Грязный вес',
                    value: '${grossWeightKg.toStringAsFixed(2)} кг',
                    color: Colors.grey.shade700,
                  ),
                ),
                Expanded(
                  child: _StatTile(
                    icon: Icons.price_change_rounded,
                    label: 'Цена за кг (гряз.)',
                    value: '${costPerKgGross.toStringAsFixed(2)} ₽',
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Ряд 4: Чистый вес и стоимость за кг
            Row(
              children: [
                Expanded(
                  child: _StatTile(
                    icon: Icons.scale_rounded,
                    label: 'Чистый вес',
                    value: '${netWeightKg.toStringAsFixed(2)} кг',
                    color: Colors.blue.shade700,
                  ),
                ),
                Expanded(
                  child: _StatTile(
                    icon: Icons.price_change_rounded,
                    label: 'Цена за кг (чист.)',
                    value: '${costPerKgNet.toStringAsFixed(2)} ₽',
                    color: Colors.blue.shade700,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),

            // Ряд 5: Прибыль (по центру)
            Center(
              child: _StatTile(
                icon: Icons.trending_up_rounded,
                label: 'Прибыль',
                value: '${stats.totalProfitRub.toStringAsFixed(0)} ₽',
                color: stats.totalProfitRub > 0
                    ? Colors.green.shade700
                    : Colors.red.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? subtitle;
  final Color? color;

  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    this.subtitle,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Icon(icon, size: 20, color: color ?? Colors.grey.shade600),
        const SizedBox(height: 4),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: Colors.grey.shade600,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: color,
          ),
          textAlign: TextAlign.center,
        ),
        if (subtitle != null)
          Text(
            subtitle!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.grey.shade500,
            ),
          ),
      ],
    );
  }
}

class _ParticipantsSection extends StatelessWidget {
  final SpAssembly assembly;

  const _ParticipantsSection({required this.assembly});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (assembly.stats.participants.isEmpty) {
      return const SizedBox.shrink();
    }

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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Участники',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            ...assembly.stats.participants.map((participant) {
              // Получаем треки участника
              final participantTracks = assembly.tracks
                  .where((t) => t.spParticipantName == participant.name)
                  .toList();

              // Считаем прибыль по участнику (сумма organizerMarginRub)
              final participantProfit = participantTracks.fold<double>(
                0,
                (sum, t) => sum + (t.organizerMarginRub ?? 0),
              );

              return _ParticipantCard(
                assemblyId: assembly.id,
                participant: participant,
                tracks: participantTracks,
                profit: participantProfit,
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _ParticipantCard extends ConsumerStatefulWidget {
  final int assemblyId;
  final SpParticipant participant;
  final List<SpTrack> tracks;
  final double profit;

  const _ParticipantCard({
    required this.assemblyId,
    required this.participant,
    required this.tracks,
    required this.profit,
  });

  @override
  ConsumerState<_ParticipantCard> createState() => _ParticipantCardState();
}

class _ParticipantCardState extends ConsumerState<_ParticipantCard> {
  bool _expanded = false;
  bool _isUpdating = false;

  /// Переключает статус оплаты через API
  Future<void> _togglePaymentStatus() async {
    if (_isUpdating) return;

    setState(() => _isUpdating = true);

    final newStatus = !widget.participant.isPaid;
    final success = await ref.read(spAssembliesControllerProvider.notifier).toggleParticipantPayment(
          widget.assemblyId,
          widget.participant.name,
          newStatus,
        );

    if (mounted) {
      setState(() => _isUpdating = false);

      if (!success) {
        _showStyledSnackBar(context, 'Ошибка обновления статуса оплаты', isError: true);
      }
    }
  }

  /// Формирует текст для копирования и отправки участнику
  void _copyParticipantInfo() {
    final buffer = StringBuffer();

    // Итоги
    double totalClientPrice = 0;
    double totalShipping = 0;
    double totalAdditionalExpenses = 0;

    // Для каждого трека: номер, цена товара, стоимость доставки
    for (final track in widget.tracks) {
      final clientPrice = track.clientPriceRub ?? 0;
      final shipping = track.shippingCostRub ?? 0;
      final additionalExpenses = track.additionalExpensesRub ?? 0;

      totalClientPrice += clientPrice;
      totalShipping += shipping;
      totalAdditionalExpenses += additionalExpenses;

      buffer.writeln(
        '${track.trackNumber}, ${clientPrice.toStringAsFixed(2)} ₽, ${shipping.toStringAsFixed(2)} ₽',
      );
    }

    // Итого доставка = доставка + доп. расходы
    final totalShippingWithExpenses = totalShipping + totalAdditionalExpenses;

    // Итого
    buffer.writeln();
    buffer.writeln('Итого товары: ${totalClientPrice.toStringAsFixed(2)} ₽');
    buffer.writeln('Итого доставка: ${totalShippingWithExpenses.toStringAsFixed(2)} ₽');
    buffer.writeln('ВСЕГО: ${(totalClientPrice + totalShippingWithExpenses).toStringAsFixed(2)} ₽');

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    _showStyledSnackBar(context, 'Данные скопированы');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Итоги для отображения
    double totalClientPrice = 0;
    double totalShipping = 0;
    double totalAdditionalExpenses = 0;
    for (final track in widget.tracks) {
      totalClientPrice += track.clientPriceRub ?? 0;
      totalShipping += track.shippingCostRub ?? 0;
      totalAdditionalExpenses += track.additionalExpensesRub ?? 0;
    }
    // Итого доставка = доставка + доп. расходы
    final totalShippingWithExpenses = totalShipping + totalAdditionalExpenses;

    final isPaid = widget.participant.isPaid;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: isPaid ? Colors.green.shade50 : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isPaid ? Colors.green.shade300 : Colors.grey.shade200,
            width: isPaid ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            // Заголовок участника
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    // Чекбокс оплаты
                    GestureDetector(
                      onTap: _isUpdating ? null : _togglePaymentStatus,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: isPaid ? Colors.green : Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isPaid ? Colors.green.shade700 : Colors.grey.shade400,
                            width: 2,
                          ),
                        ),
                        child: isPaid
                            ? const Icon(Icons.check_rounded, size: 18, color: Colors.white)
                            : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    CircleAvatar(
                      backgroundColor: context.brandPrimary.withValues(alpha: 0.1),
                      child: Text(
                        widget.participant.name[0].toUpperCase(),
                        style: TextStyle(
                          color: context.brandPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.participant.name,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${widget.participant.trackCount} треков • ${widget.participant.weight.toStringAsFixed(2)} кг',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.grey.shade600,
                            ),
                          ),
                          if (isPaid) ...[
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(
                                  Icons.check_circle_rounded,
                                  size: 12,
                                  color: Colors.green.shade700,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Оплачено',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: Colors.green.shade700,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Прибыль
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${widget.profit.toStringAsFixed(0)} ₽',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: widget.profit > 0
                                ? Colors.green.shade700
                                : Colors.red.shade700,
                          ),
                        ),
                        Text(
                          'прибыль',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.grey.shade500,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      color: Colors.grey.shade600,
                    ),
                  ],
                ),
              ),
            ),

            // Список треков (раскрывающийся)
            if (_expanded) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Заголовок таблицы
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text(
                              'Трек',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: Colors.grey.shade600,
                                fontSize: 10,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              'Цена',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: Colors.grey.shade600,
                                fontSize: 10,
                              ),
                              textAlign: TextAlign.right,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              'Доставка',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: Colors.grey.shade600,
                                fontSize: 10,
                              ),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Таблица треков
                    ...widget.tracks.map((track) {
                      return _TrackInfoRow(track: track);
                    }),

                    // Итого
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Итого товары:',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${totalClientPrice.toStringAsFixed(2)} ₽',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Итого доставка:',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${totalShippingWithExpenses.toStringAsFixed(2)} ₽',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'ВСЕГО:',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '${(totalClientPrice + totalShippingWithExpenses).toStringAsFixed(2)} ₽',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: context.brandPrimary,
                          ),
                        ),
                      ],
                    ),

                    // Кнопка копирования
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _copyParticipantInfo,
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        label: const Text('Скопировать для отправки'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TrackInfoRow extends StatelessWidget {
  final SpTrack track;

  const _TrackInfoRow({required this.track});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final clientPrice = track.clientPriceRub ?? 0;
    final shipping = track.shippingCostRub ?? 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          // Трек номер
          Expanded(
            flex: 2,
            child: Text(
              track.trackNumber,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Цена товара
          Expanded(
            child: Text(
              '${clientPrice.toStringAsFixed(2)} ₽',
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 11,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          // Доставка
          Expanded(
            child: Text(
              '${shipping.toStringAsFixed(2)} ₽',
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 11,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

class _TracksSection extends StatelessWidget {
  final SpAssembly assembly;

  const _TracksSection({required this.assembly});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allTracks = assembly.tracks;
    final spTracksCount = allTracks.where((t) => t.spParticipantName != null).length;

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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Треки ($spTracksCount СП из ${allTracks.length})',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            if (allTracks.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Нет треков в сборке',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade500,
                    ),
                  ),
                ),
              )
            else
              ...allTracks.map((track) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _TrackCard(track: track, assembly: assembly),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _TrackCard extends StatelessWidget {
  final SpTrack track;
  final SpAssembly assembly;

  const _TrackCard({required this.track, required this.assembly});

  /// Проверяет, все ли обязательные поля заполнены
  bool get isComplete {
    return track.spParticipantName != null &&
        track.spParticipantName!.isNotEmpty &&
        track.clientPriceYuan != null &&
        track.clientPriceYuan! > 0 &&
        track.netWeightKg != null &&
        track.netWeightKg! > 0 &&
        track.purchaseRate != null &&
        track.purchaseRate! > 0;
  }

  /// Рассчитывает стоимость доставки автоматически
  double? _calculateShippingCost() {
    final netWeight = track.netWeightKg;
    if (netWeight == null || netWeight <= 0) return null;

    // Проверяем, что у всех СП-треков заполнен вес
    final spTracks = assembly.tracks.where((t) => t.spParticipantName != null && t.spParticipantName!.isNotEmpty).toList();
    if (spTracks.isEmpty) return null;

    double totalNetWeight = 0;
    for (final t in spTracks) {
      if (t.netWeightKg == null || t.netWeightKg! <= 0) return null;
      totalNetWeight += t.netWeightKg!;
    }

    if (totalNetWeight <= 0) return null;

    // Общая стоимость доставки
    double totalDeliveryCost = assembly.totalShippingCostRub ?? 0;
    if (totalDeliveryCost == 0 && assembly.invoices.isNotEmpty) {
      for (final invoice in assembly.invoices) {
        totalDeliveryCost += invoice.deliveryCostRub;
      }
    }

    if (totalDeliveryCost <= 0) return null;

    return netWeight * (totalDeliveryCost / totalNetWeight);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Расчёты
    final clientPriceRub = track.clientPriceRub ??
        (track.clientPriceYuan != null && track.purchaseRate != null
            ? track.clientPriceYuan! * track.purchaseRate!
            : null);
    final shippingCostRub = _calculateShippingCost() ?? track.shippingCostRub;
    final totalRub = clientPriceRub != null ? clientPriceRub + (shippingCostRub ?? 0) : null;
    final profitRub = track.organizerMarginRub ??
        (track.clientPriceRub != null && track.costPriceRub != null
            ? track.clientPriceRub! - track.costPriceRub!
            : null);

    // Информация о товаре
    final productName = track.productInfo?.title ?? track.productTitle;
    final productQty = track.productInfo?.quantity ?? 1;

    return InkWell(
      onTap: () {
        context.push('/sp-finance/tracks/${track.id}', extra: {'assemblyId': assembly.id});
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isComplete ? Colors.green.shade200 : Colors.orange.shade200,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Верхняя строка: номер трека + статус
            Row(
              children: [
                Expanded(
                  child: Text(
                    track.trackNumber,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                // Статус заполненности
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isComplete ? Colors.green.shade50 : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isComplete ? Icons.check_circle_rounded : Icons.warning_rounded,
                        size: 14,
                        color: isComplete ? Colors.green.shade700 : Colors.orange.shade700,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isComplete ? 'Заполнено' : 'Не заполнено',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: isComplete ? Colors.green.shade700 : Colors.orange.shade700,
                          fontWeight: FontWeight.w600,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right_rounded, size: 20, color: Colors.grey),
              ],
            ),

            // О товаре
            if (productName != null && productName.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.inventory_2_rounded, size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '$productName × $productQty шт.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],

            // Имя участника
            if (track.spParticipantName != null && track.spParticipantName!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.person_rounded, size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 6),
                  Text(
                    track.spParticipantName!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: context.brandPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],

            const Divider(height: 16),

            // Финансовые показатели - 2 строки по 2 элемента
            Row(
              children: [
                // Цена участника
                Expanded(
                  child: _FinanceItem(
                    label: 'Цена товара',
                    value: clientPriceRub,
                    color: Colors.blue.shade700,
                  ),
                ),
                // Доставка
                Expanded(
                  child: _FinanceItem(
                    label: 'Цена доставки',
                    value: shippingCostRub,
                    color: Colors.purple.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                // Итого
                Expanded(
                  child: _FinanceItem(
                    label: 'Итого к оплате',
                    value: totalRub,
                    color: context.brandPrimary,
                    isBold: true,
                  ),
                ),
                // Прибыль
                Expanded(
                  child: _FinanceItem(
                    label: 'Прибыль',
                    value: profitRub,
                    color: profitRub != null && profitRub > 0
                        ? Colors.green.shade700
                        : Colors.red.shade700,
                    isBold: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FinanceItem extends StatelessWidget {
  final String label;
  final double? value;
  final Color color;
  final bool isBold;

  const _FinanceItem({
    required this.label,
    required this.value,
    required this.color,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: Colors.grey.shade500,
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value != null ? '${value!.toStringAsFixed(2)} ₽' : '—',
          style: theme.textTheme.bodySmall?.copyWith(
            color: value != null ? color : Colors.grey.shade400,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

/// Секция с фото на весах
class _BoxesSection extends StatelessWidget {
  final SpAssembly assembly;

  const _BoxesSection({required this.assembly});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.inventory_2_outlined, size: 20, color: Color(0xFFfe3301)),
                    const SizedBox(width: 8),
                    Text(
                      tr(context, ru: 'Коробки', zh: '箱子'),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                Text(
                  '${assembly.boxes.length} шт.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Отображаем каждую коробку
            ...assembly.boxes.asMap().entries.map((entry) {
              final index = entry.key;
              final box = entry.value;
              return Padding(
                padding: EdgeInsets.only(bottom: index < assembly.boxes.length - 1 ? 12 : 0),
                child: _buildBoxCard(context, box),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildBoxCard(BuildContext context, Box box) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Заголовок с номером коробки
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFfe3301).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    '#${box.number}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: Color(0xFFfe3301),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                box.displayName(context),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Параметры коробки в сетке 2x2
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildBoxParam(
                        context,
                        icon: Icons.straighten,
                        label: tr(context, ru: 'Габариты', zh: '尺寸'),
                        value: box.dimensionsDisplay,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildBoxParam(
                        context,
                        icon: Icons.scale,
                        label: tr(context, ru: 'Вес', zh: '重量'),
                        value: box.weightDisplay,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildBoxParam(
                        context,
                        icon: Icons.inventory_2_outlined,
                        label: tr(context, ru: 'Объём', zh: '体积'),
                        value: box.volumeDisplay,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildBoxParam(
                        context,
                        icon: Icons.compress,
                        label: tr(context, ru: 'Плотность', zh: '密度'),
                        value: box.densityDisplay,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Фото на весах
          if (box.photos.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              tr(context, ru: 'Фото на весах (${box.photos.length})', zh: '称重照片 (${box.photos.length})'),
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 90,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: box.photos.length,
                itemBuilder: (context, index) {
                  final photo = box.photos[index];
                  final photoUrl = ApiConfig.getMediaUrl(photo.url);

                  return Padding(
                    padding: EdgeInsets.only(right: index < box.photos.length - 1 ? 10 : 0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            // TODO: Добавить просмотр фото
                          },
                          child: Container(
                            width: 90,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.03),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: CachedNetworkImage(
                              imageUrl: photoUrl,
                              fit: BoxFit.cover,
                              placeholder: (_, _) => Container(
                                color: Colors.black.withValues(alpha: 0.06),
                                child: const Center(
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                              errorWidget: (_, _, _) => Container(
                                color: Colors.black.withValues(alpha: 0.06),
                                child: const Center(
                                  child: Icon(Icons.broken_image_outlined, size: 24),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBoxParam(BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 15, color: Colors.black45),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black54,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}
