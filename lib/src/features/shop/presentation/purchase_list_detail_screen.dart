import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/app_colors.dart';
import '../../../core/ui/app_layout.dart';
import '../../../core/ui/tutorial_card.dart';
import '../data/purchase_provider.dart';
import '../domain/purchase_list.dart';

class PurchaseListDetailScreen extends ConsumerWidget {
  final int listId;

  const PurchaseListDetailScreen({super.key, required this.listId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(purchaseListDetailProvider(listId));
    final topPad = AppLayout.topBarTotalHeight(context);
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return detailAsync.when(
      data: (list) {
        if (list == null) {
          return const Center(child: Text('Заявка не найдена'));
        }
        return _buildContent(
          context,
          list,
          topPad,
          bottomPad,
          () => ref.invalidate(purchaseListDetailProvider(listId)),
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
              onPressed: () =>
                  ref.invalidate(purchaseListDetailProvider(listId)),
              child: const Text('Повторить'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    PurchaseList list,
    double topPad,
    double bottomPad,
    VoidCallback onRefresh,
  ) {
    return TutorialScreenWrapper(
      screenKey: 'purchase_list_detail',
      steps: const [
        TutorialStep(
          icon: Icons.receipt_long_rounded,
          title: 'Детали заявки',
          description:
              'Здесь отображается список всех товаров в заявке: фото, название, выбранные параметры и количество.',
        ),
        TutorialStep(
          icon: Icons.label_rounded,
          title: 'Статус заявки',
          description:
              'Статус показывает этап обработки заявки: отправлена, в работе, выполнена или отменена.',
        ),
        TutorialStep(
          icon: Icons.comment_rounded,
          title: 'Комментарий менеджера',
          description:
              'Если менеджер оставил примечание к вашей заявке, оно отобразится в синем блоке внизу страницы.',
        ),
      ],
      child: ListView(
        padding: EdgeInsets.fromLTRB(16, topPad * 0.7 + 16, 16, 24 + bottomPad),
        children: [
          Text(
            'Заявка #${list.id}',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),

          // Status + date
          Row(
            children: [
              _StatusBadge(status: list.status),
              const SizedBox(width: 12),
              if (list.submittedAt != null)
                Text(
                  'от ${_formatDate(list.submittedAt!)}',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${list.totalItems} товаров',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 20),

          if (list.marketplaceOrder != null) ...[
            _MarketplaceOrderCard(
              order: list.marketplaceOrder!,
              onRefresh: onRefresh,
            ),
            const SizedBox(height: 16),
          ],

          // Items
          ...list.items.map((item) => _ItemCard(item: item)),

          // Note
          if (list.note != null && list.note!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ваш комментарий',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    list.note!,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Manager note
          if (list.managerNote != null && list.managerNote!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.comment_outlined,
                        size: 16,
                        color: Colors.blue.shade400,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Комментарий менеджера',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue.shade600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    list.managerNote!,
                    style: TextStyle(fontSize: 14, color: Colors.blue.shade800),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }
}

class _MarketplaceOrderCard extends StatelessWidget {
  const _MarketplaceOrderCard({required this.order, required this.onRefresh});

  final MarketplaceOrderSummary order;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final externalOrders = order.groups
        .expand((group) => group.externalOrders)
        .toList(growable: false);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.brandOrange.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  '1688',
                  style: TextStyle(
                    color: AppColors.brandOrange,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Заказ у поставщика',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      order.statusDisplay,
                      style: const TextStyle(
                        color: AppColors.brandOrange,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'Обновить',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _OrderMetric(
                  label: 'Товары и доставка',
                  value: '¥${order.payableCny.toStringAsFixed(2)}',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _OrderMetric(
                  label: 'Доставка по Китаю',
                  value: '¥${order.freightCny.toStringAsFixed(2)}',
                ),
              ),
            ],
          ),
          if (externalOrders.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),
            for (final external in externalOrders) ...[
              Row(
                children: [
                  const Icon(
                    Icons.receipt_long_outlined,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '1688 #${external.externalOrderId}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(
                    external.status,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              for (final shipment in external.shipments)
                Padding(
                  padding: const EdgeInsets.only(left: 26, top: 5),
                  child: Text(
                    '${shipment.companyName}: ${shipment.trackingNumber}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              const SizedBox(height: 6),
            ],
          ],
          const SizedBox(height: 6),
          const Text(
            'Оплату и работу с поставщиком выполняет ваш менеджер.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _OrderMetric extends StatelessWidget {
  const _OrderMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  final PurchaseItem item;

  const _ItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: item.imageUrl!,
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => Container(
                        width: 64,
                        height: 64,
                        color: Colors.grey.shade100,
                      ),
                      errorWidget: (_, _, _) => Container(
                        width: 64,
                        height: 64,
                        color: Colors.grey.shade100,
                        child: const Icon(Icons.image_outlined),
                      ),
                    )
                  : Container(
                      width: 64,
                      height: 64,
                      color: Colors.grey.shade100,
                      child: Icon(
                        Icons.image_outlined,
                        color: Colors.grey.shade300,
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (item.skuPropertiesDisplay.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      item.skuPropertiesDisplay,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        item.priceDisplay,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: context.brandPrimary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'x${item.quantity}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
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

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg, String label) = switch (status) {
      'submitted' => (
        Colors.orange.shade100,
        Colors.orange.shade800,
        'Отправлена',
      ),
      'processing' => (Colors.blue.shade100, Colors.blue.shade800, 'В работе'),
      'completed' => (
        Colors.green.shade100,
        Colors.green.shade800,
        'Выполнена',
      ),
      'cancelled' => (Colors.grey.shade200, Colors.grey.shade600, 'Отменена'),
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
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}
