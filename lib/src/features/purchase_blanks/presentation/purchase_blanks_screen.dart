import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/ui/app_colors.dart';
import '../../../core/ui/app_layout.dart';
import '../../../core/ui/empty_state.dart';
import '../../../core/ui/scroll_to_top_button.dart';
import '../data/purchase_blank_model.dart';
import '../data/purchase_blanks_provider.dart';
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

  List<PurchaseBlank> get _filteredBlanks {
    final blanks = ref.read(purchaseBlanksProvider).blanks;
    if (_selectedStatus == null) return blanks;
    return blanks.where((b) => b.status == _selectedStatus).toList();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(purchaseBlanksProvider);
    final theme = Theme.of(context);
    final topPad = AppLayout.topBarTotalHeight(context);
    final bottomPad = MediaQuery.paddingOf(context).bottom;

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

    final blanks = _filteredBlanks;

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: () => ref.read(purchaseBlanksProvider.notifier).reload(),
          color: context.brandPrimary,
          child: ListView.builder(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              16,
              topPad * 0.7 + 16,
              16,
              24 + bottomPad,
            ),
            itemCount: blanks.length + 2, // заголовок + фильтр + items
            itemBuilder: (context, i) {
              if (i == 0) {
                return _buildHeader(context, theme);
              }
              if (i == 1) {
                return _buildFilters(context);
              }

              final blank = blanks[i - 2];
              return Padding(
                padding: EdgeInsets.only(
                  bottom: i - 2 == blanks.length - 1 ? 0 : 12,
                ),
                child: _BlankCard(blank: blank),
              );
            },
          ),
        ),
        ScrollToTopButton(controller: _scrollController),

        // Пустое состояние (после фильтров)
        if (state.blanks.isEmpty)
          Center(
            child: EmptyState(
              icon: Icons.description_rounded,
              title: 'Нет бланков',
              message: 'Создайте первый бланк на выкуп товара',
            ),
          ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Выкуп по бланку',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          // Кнопка создать
          GestureDetector(
            onTap: _createBlank,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                gradient: context.brandGradient,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: context.brandPrimary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_rounded, size: 18, color: Colors.white),
                  SizedBox(width: 4),
                  Text(
                    'Создать',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
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

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: SizedBox(
        height: 36,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: allStatuses.length,
          separatorBuilder: (_, _) => const SizedBox(width: 6),
          itemBuilder: (context, i) {
            final status = allStatuses[i];
            final isSelected = _selectedStatus == status;
            final color = status?.color ?? context.brandPrimary;

            return GestureDetector(
              onTap: () => setState(() => _selectedStatus = status),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? color.withValues(alpha: 0.15)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                  border: isSelected
                      ? Border.all(color: color.withValues(alpha: 0.4))
                      : null,
                ),
                child: Text(
                  labels[status] ?? '',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? color : Colors.grey.shade600,
                  ),
                ),
              ),
            );
          },
        ),
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

// ── Карточка бланка ─────────────────────────────────────────

class _BlankCard extends StatelessWidget {
  final PurchaseBlank blank;

  const _BlankCard({required this.blank});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('dd.MM.yyyy HH:mm');

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
          onTap: () => context.push('/purchase-blanks/${blank.id}'),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Заголовок с номером и статусом
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: context.brandPrimary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
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
                          Text(
                            'Бланк #${blank.id}',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            dateFormat.format(blank.createdAt),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    BlankStatusBadge(status: blank.status),
                  ],
                ),
                const SizedBox(height: 14),

                // Статистика
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      _StatItem(
                        icon: Icons.shopping_bag_rounded,
                        label: 'Товаров',
                        value: '${blank.itemsCount}',
                      ),
                      const SizedBox(width: 20),
                      _StatItem(
                        icon: Icons.currency_yuan_rounded,
                        label: 'Сумма ¥',
                        value: blank.clientTotalCny > 0
                            ? '¥${blank.clientTotalCny.toStringAsFixed(2)}'
                            : '—',
                      ),
                      if (blank.totalAmountRub != null) ...[
                        const SizedBox(width: 20),
                        _StatItem(
                          icon: Icons.currency_ruble_rounded,
                          label: 'Итого ₽',
                          value: '₽${blank.totalAmountRub!.toStringAsFixed(0)}',
                        ),
                      ],
                    ],
                  ),
                ),

                // Комментарий сотрудника
                if (blank.employeeComment != null &&
                    blank.employeeComment!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.comment_rounded,
                          size: 14,
                          color: Colors.blue.shade700,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            blank.employeeComment!,
                            style: theme.textTheme.bodySmall?.copyWith(
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

                // Стрелка
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.grey.shade400,
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
    return Expanded(
      child: Row(
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
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade600,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
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
      ),
    );
  }
}
