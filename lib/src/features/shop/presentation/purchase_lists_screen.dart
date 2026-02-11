import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/app_colors.dart';
import '../../../core/ui/app_layout.dart';
import '../data/purchase_provider.dart';
import '../domain/purchase_list.dart';

class PurchaseListsScreen extends ConsumerWidget {
  const PurchaseListsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listsAsync = ref.watch(purchaseListsProvider);
    final topPad = AppLayout.topBarTotalHeight(context);
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return listsAsync.when(
      data: (lists) {
        // Filter out drafts — only show submitted+
        final submitted =
            lists.where((l) => l.status != 'draft').toList();

        if (submitted.isEmpty) {
          return ListView(
            padding: EdgeInsets.fromLTRB(16, topPad * 0.7 + 6, 16, 100),
            children: [
              Text(
                'Мои заявки',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 60),
              Center(
                child: Column(
                  children: [
                    Icon(Icons.receipt_long_outlined,
                        size: 64, color: Colors.grey.shade300),
                    const SizedBox(height: 16),
                    Text(
                      'Нет заявок',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Заявки появятся после отправки списка выкупа',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(fontSize: 14, color: Colors.grey.shade400),
                    ),
                  ],
                ),
              ),
            ],
          );
        }

        return ListView(
          padding: EdgeInsets.fromLTRB(
              16, topPad * 0.7 + 6, 16, 24 + bottomPad),
          children: [
            Text(
              'Мои заявки',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 16),
            ...submitted.map(
              (list) => _PurchaseListCard(
                list: list,
                onTap: () => context.push('/shop/purchases/${list.id}'),
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              'Ошибка загрузки',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => ref.invalidate(purchaseListsProvider),
              child: const Text('Повторить'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PurchaseListCard extends StatelessWidget {
  final PurchaseList list;
  final VoidCallback onTap;

  const _PurchaseListCard({required this.list, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Заявка #${list.id}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  _StatusBadge(status: list.status),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.shopping_bag_outlined,
                      size: 16, color: Colors.grey.shade500),
                  const SizedBox(width: 6),
                  Text(
                    '${list.totalItems} товаров',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.calendar_today_outlined,
                      size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 6),
                  Text(
                    _formatDate(list.submittedAt ?? list.createdAt),
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
              if (list.items.isNotEmpty) ...[
                const SizedBox(height: 12),
                // Preview images
                SizedBox(
                  height: 44,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount:
                        list.items.length > 5 ? 5 : list.items.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 6),
                    itemBuilder: (context, index) {
                      if (index == 4 && list.items.length > 5) {
                        return Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              '+${list.items.length - 4}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                        );
                      }
                      final item = list.items[index];
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: item.imageUrl != null &&
                                item.imageUrl!.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: item.imageUrl!,
                                width: 44,
                                height: 44,
                                fit: BoxFit.cover,
                              )
                            : Container(
                                width: 44,
                                height: 44,
                                color: Colors.grey.shade100,
                                child: Icon(Icons.image_outlined,
                                    size: 20, color: Colors.grey.shade300),
                              ),
                      );
                    },
                  ),
                ),
              ],
              if (list.managerNote != null &&
                  list.managerNote!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.comment_outlined,
                          size: 16, color: Colors.blue.shade400),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          list.managerNote!,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.blue.shade800,
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
      ),
    );
  }

  static String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg, String label) = switch (status) {
      'submitted' => (
          Colors.orange.shade100,
          Colors.orange.shade800,
          'Отправлена'
        ),
      'processing' => (
          Colors.blue.shade100,
          Colors.blue.shade800,
          'В работе'
        ),
      'completed' => (
          Colors.green.shade100,
          Colors.green.shade800,
          'Выполнена'
        ),
      'cancelled' => (
          Colors.grey.shade200,
          Colors.grey.shade600,
          'Отменена'
        ),
      _ => (Colors.grey.shade200, Colors.grey.shade600, status),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}
