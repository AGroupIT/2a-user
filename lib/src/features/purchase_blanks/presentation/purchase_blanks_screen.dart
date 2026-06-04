import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/ui/animated_hero_glow_backdrop.dart';
import '../../../core/ui/app_colors.dart';
import '../../../core/ui/app_layout.dart';
import '../../../core/ui/empty_state.dart';
import '../../../core/ui/scroll_to_top_button.dart';
import '../data/purchase_blank_model.dart';
import '../data/purchase_blanks_provider.dart';
import 'purchase_blank_ui.dart';
import 'widgets/blank_status_badge.dart';

class PurchaseBlanksScreen extends ConsumerStatefulWidget {
  const PurchaseBlanksScreen({super.key});

  @override
  ConsumerState<PurchaseBlanksScreen> createState() =>
      _PurchaseBlanksScreenState();
}

class _PurchaseBlanksScreenState extends ConsumerState<PurchaseBlanksScreen> {
  final ScrollController _scrollController = ScrollController();
  PurchaseBlankStatus? _selectedStatus;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(purchaseBlanksProvider.notifier).loadBlanks();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(purchaseBlanksProvider);
    final topPad = AppLayout.topBarTotalHeight(context);
    final bottomPad = AppLayout.bottomScrollPadding(context);

    // Загрузка
    if (state.isLoading && state.blanks.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    // Ошибка
    if (state.error != null && state.blanks.isEmpty) {
      return EmptyState(
        icon: Icons.error_outline,
        title: 'Ошибка загрузки',
        message: state.error!,
      );
    }

    final blanks = _selectedStatus == null
        ? state.blanks
        : state.blanks.where((b) => b.status == _selectedStatus).toList();

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: () => ref.read(purchaseBlanksProvider.notifier).reload(),
          color: context.brandPrimary,
          child: ListView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              16,
              topPad * 0.7 + 16,
              16,
              bottomPad + 16,
            ),
            children: [
              _buildHeader(context),
              const SizedBox(height: 15),
              _buildFilters(context),
              const SizedBox(height: 15),
              if (state.blanks.isEmpty)
                _buildEmptyCard(
                  context,
                  title: 'Нет бланков',
                  message: 'Создайте первый бланк на выкуп товара',
                )
              else if (blanks.isEmpty)
                _buildEmptyCard(
                  context,
                  title: 'По фильтру ничего нет',
                  message: 'Выберите другой статус или создайте новый бланк',
                )
              else
                ...blanks.map(
                  (blank) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _BlankCard(blank: blank),
                  ),
                ),
            ],
          ),
        ),
        ScrollToTopButton(controller: _scrollController),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PurchaseBlankPageHeader(title: 'Выкуп по бланку'),
        const SizedBox(height: 12),
        _PurchaseBlanksHero(onCreate: _createBlank),
      ],
    );
  }

  Widget _buildFilters(BuildContext context) {
    final allStatuses = [null, ...PurchaseBlankStatus.values];
    final labels = {
      null: 'Все',
      PurchaseBlankStatus.newBlank: 'Новые',
      PurchaseBlankStatus.submitted: 'Отправлены',
      PurchaseBlankStatus.inProgress: 'В работе',
      PurchaseBlankStatus.completed: 'Выполнены',
      PurchaseBlankStatus.cancelled: 'Отменены',
    };

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: PurchaseBlankUi.cardDecoration(),
      child: SizedBox(
        height: 40,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: allStatuses.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
            final status = allStatuses[i];
            final isSelected = _selectedStatus == status;
            final color = status?.color ?? context.brandPrimary;

            return Material(
              type: MaterialType.transparency,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                onTap: () => setState(() => _selectedStatus = status),
                borderRadius: BorderRadius.circular(14),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected ? color : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? color
                          : Colors.black.withValues(alpha: 0.035),
                    ),
                  ),
                  child: Text(
                    labels[status] ?? '',
                    style: TextStyle(
                      color: isSelected ? Colors.white : AppColors.textPrimary,
                      fontFamily: 'Gilroy',
                      fontSize: 13,
                      height: 15 / 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyCard(
    BuildContext context, {
    required String title,
    required String message,
  }) {
    return Container(
      decoration: PurchaseBlankUi.cardDecoration(),
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: context.brandPrimary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.description_rounded,
              color: context.brandPrimary,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: PurchaseBlankUi.sectionTitleStyle),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: PurchaseBlankUi.bodyStyle.copyWith(
                    color: PurchaseBlankUi.mutedTextColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _createBlank() async {
    final blank = await ref.read(purchaseBlanksProvider.notifier).createBlank();
    if (blank != null && mounted) {
      context.push('/purchase-blanks/${blank.id}');
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}

class _PurchaseBlanksHero extends StatelessWidget {
  final VoidCallback onCreate;

  const _PurchaseBlanksHero({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: context.brandGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: context.brandPrimary.withValues(alpha: 0.22),
            blurRadius: 28,
            spreadRadius: -12,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            const Positioned.fill(child: AnimatedHeroGlowBackdrop()),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.22),
                          ),
                        ),
                        child: const Icon(
                          Icons.assignment_rounded,
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
                              'Быстрый выкуп товаров',
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
                              'Добавьте ссылки, количество и цену — менеджер проверит бланк и оформит выкуп.',
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
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton.icon(
                      onPressed: onCreate,
                      icon: const Icon(Icons.add_rounded, size: 21),
                      label: const Text(
                        'Создать новый бланк',
                        style: TextStyle(
                          fontFamily: 'Gilroy',
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: context.brandPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Карточка бланка ─────────────────────────────────────────

class _BlankCard extends StatelessWidget {
  final PurchaseBlank blank;

  const _BlankCard({required this.blank});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd.MM.yyyy HH:mm');

    return Container(
      decoration: PurchaseBlankUi.cardDecoration(),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: () => context.push('/purchase-blanks/${blank.id}'),
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: context.brandPrimary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.assignment_rounded,
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
                            'Бланк #${blank.id}',
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
                              Icon(
                                Icons.add_circle_outline_rounded,
                                size: 15,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  dateFormat.format(blank.createdAt),
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontFamily: 'Gilroy',
                                    fontSize: 12,
                                    height: 14 / 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    BlankStatusBadge(status: blank.status, compact: true),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.black.withValues(alpha: 0.025),
                    ),
                  ),
                  child: Row(
                    children: [
                      _StatItem(
                        icon: Icons.shopping_bag_rounded,
                        label: 'Товаров',
                        value: '${blank.itemsCount}',
                      ),
                      const SizedBox(width: 12),
                      _StatItem(
                        icon: Icons.currency_yuan_rounded,
                        label: 'Сумма ¥',
                        value: blank.clientTotalCny > 0
                            ? '¥${blank.clientTotalCny.toStringAsFixed(2)}'
                            : '—',
                      ),
                      if (blank.totalAmountRub != null) ...[
                        const SizedBox(width: 12),
                        _StatItem(
                          icon: Icons.currency_ruble_rounded,
                          label: 'Итого ₽',
                          value: '₽${blank.totalAmountRub!.toStringAsFixed(0)}',
                        ),
                      ],
                    ],
                  ),
                ),
                if (blank.employeeComment != null &&
                    blank.employeeComment!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Colors.blue.withValues(alpha: 0.16),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.comment_rounded,
                          size: 16,
                          color: Colors.blue.shade700,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            blank.employeeComment!,
                            style: TextStyle(
                              fontFamily: 'Gilroy',
                              fontSize: 12.5,
                              height: 1.22,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue.shade700,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'Открыть бланк',
                      style: TextStyle(
                        color: context.brandPrimary,
                        fontFamily: 'Gilroy',
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: context.brandPrimary,
                      size: 22,
                    ),
                  ],
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
    return Expanded(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: context.brandPrimary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 15, color: context.brandPrimary),
          ),
          const SizedBox(width: 7),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'Gilroy',
                    fontSize: 10,
                    height: 12 / 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontFamily: 'Gilroy',
                    fontSize: 13,
                    height: 15 / 13,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
