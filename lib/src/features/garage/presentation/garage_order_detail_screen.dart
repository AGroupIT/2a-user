import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/app_colors.dart';
import '../../../core/ui/app_layout.dart';
import '../../../core/ui/app_toast.dart';
import '../application/garage_providers.dart';
import '../domain/garage_models.dart';
import 'garage_invoice_card.dart';
import 'garage_order_composition_card.dart';
import 'garage_payment_sheet.dart';
import 'garage_request_detail_screen.dart';
import 'garage_ui.dart';

class GarageOrderDetailScreen extends ConsumerStatefulWidget {
  final int orderId;

  const GarageOrderDetailScreen({super.key, required this.orderId});

  @override
  ConsumerState<GarageOrderDetailScreen> createState() =>
      _GarageOrderDetailScreenState();
}

class _GarageOrderDetailScreenState
    extends ConsumerState<GarageOrderDetailScreen> {
  bool _working = false;

  Future<void> _refresh() async {
    ref.invalidate(garageOrderProvider(widget.orderId));
    ref.invalidate(garageInvoiceProvider(widget.orderId));
    await ref.read(garageOrderProvider(widget.orderId).future);
  }

  Future<void> _pay(GarageOrder order) async {
    final sent = await showGaragePaymentSheet(
      context: context,
      orderId: order.id,
      orderNumber: order.orderNumber,
    );
    if (!mounted || sent != true) return;
    _show('Чек отправлен на проверку');
    await _refresh();
  }

  Future<void> _cancel(GarageOrder order) async {
    if (_working) return;
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Отменить заказ?'),
            content: const Text(
              'Неоплаченный заказ и его счёт будут отменены. Для повторного заказа создайте новую заявку.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Назад'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Отменить'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;
    setState(() => _working = true);
    try {
      await ref.read(garageRepositoryProvider).cancelOrder(order.id);
      if (!mounted) return;
      ref.invalidate(garageOrderProvider(order.id));
      ref.invalidate(garageOrdersProvider);
      setState(() => _working = false);
    } catch (_) {
      if (!mounted) return;
      setState(() => _working = false);
      _show('Не удалось отменить заказ', error: true);
    }
  }

  void _show(String message, {bool error = false}) {
    AppToast.show(context, message, isError: error);
  }

  @override
  Widget build(BuildContext context) {
    final order = ref.watch(garageOrderProvider(widget.orderId));
    final top = AppLayout.topBarTotalHeight(context);
    final bottom = AppLayout.bottomScrollPadding(context);
    return order.when(
      loading: () => ListView(
        padding: EdgeInsets.fromLTRB(16, top * 0.7 + 16, 16, bottom + 26),
        children: const [
          GaragePageHeader(title: 'Заказ Гаража'),
          SizedBox(height: 12),
          GarageCard(child: Center(child: CircularProgressIndicator())),
        ],
      ),
      error: (error, _) => ListView(
        padding: EdgeInsets.fromLTRB(16, top * 0.7 + 16, 16, bottom + 26),
        children: [
          const GaragePageHeader(title: 'Заказ Гаража'),
          const SizedBox(height: 12),
          GarageEmptyState(
            icon: Icons.error_outline_rounded,
            title: 'Заказ не загрузился',
            subtitle: 'Проверьте ссылку и соединение.',
            action: GarageSecondaryButton(
              label: 'Повторить',
              icon: Icons.refresh_rounded,
              onPressed: () =>
                  ref.invalidate(garageOrderProvider(widget.orderId)),
            ),
          ),
        ],
      ),
      data: (value) => RefreshIndicator(
        onRefresh: _refresh,
        color: context.brandPrimary,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(16, top * 0.7 + 16, 16, bottom + 26),
          children: [
            const GaragePageHeader(title: 'Заказ Гаража'),
            const SizedBox(height: 12),
            _summary(value),
            const SizedBox(height: 12),
            _items(value),
            const SizedBox(height: 12),
            _invoice(value),
            const SizedBox(height: 14),
            _actions(value),
          ],
        ),
      ),
    );
  }

  Widget _summary(GarageOrder order) {
    final vehicle = order.vehicleSnapshot ?? const <String, dynamic>{};
    final vehicleLabel = [
      vehicle['make'],
      vehicle['model'],
      vehicle['modelYear'],
    ].where((value) => value != null).join(' ');
    return GarageCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  order.orderNumber,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontFamily: 'Gilroy',
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              GarageStatusChip(status: order.status),
            ],
          ),
          const SizedBox(height: 12),
          GarageInfoRow(
            label: 'Автомобиль',
            value: vehicleLabel.isEmpty ? 'Не указан' : vehicleLabel,
          ),
          GarageInfoRow(
            label: 'Состав',
            value: '${order.items.length} позиций',
          ),
          GarageInfoRow(
            label: 'Итого',
            value: garageMoney(order.totalRub, '₽'),
            emphasized: true,
          ),
          const SizedBox(height: 12),
          _OrderProgress(status: order.status),
        ],
      ),
    );
  }

  Widget _items(GarageOrder order) {
    return GarageOrderCompositionCard(order: order);
  }

  Widget _invoice(GarageOrder order) {
    final embedded = order.invoice;
    if (embedded != null) {
      return GarageInvoiceCard(
        invoice: embedded,
        order: order,
        onPay: canPayGarageOrder(order, embedded) ? () => _pay(order) : null,
      );
    }
    final invoice = ref.watch(garageInvoiceProvider(order.id));
    return invoice.when(
      loading: () =>
          const GarageCard(child: Center(child: CircularProgressIndicator())),
      error: (error, _) => const GarageCard(
        child: Text(
          'Счёт ещё формируется',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontFamily: 'Gilroy',
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      data: (value) => GarageInvoiceCard(
        invoice: value,
        order: order,
        onPay: canPayGarageOrder(order, value) ? () => _pay(order) : null,
      ),
    );
  }

  Widget _actions(GarageOrder order) {
    final paid =
        order.paidAt != null ||
        {
          'paid',
          'purchasing',
          'purchased',
          'partially_purchased',
          'completed',
        }.contains(order.status);
    final canCancel =
        !paid &&
        (order.invoice?.paymentSummary?.creditedRub.kopecks ?? 0) == 0 &&
        {'awaiting_payment', 'payment_review'}.contains(order.status);
    final canEditSelection =
        order.status == 'awaiting_payment' &&
        order.paidAt == null &&
        order.invoice?.status == 'unpaid' &&
        order.invoice?.paidAt == null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (canEditSelection) ...[
          GarageSecondaryButton(
            label: 'Изменить состав и количество',
            icon: Icons.edit_note_rounded,
            onPressed: _working
                ? null
                : () async {
                    await showGarageRequestDetailModal(
                      context,
                      requestId: order.requestId,
                    );
                    if (!mounted) return;
                    await _refresh();
                  },
          ),
          if (canCancel) const SizedBox(height: 10),
        ],
        if (canCancel)
          GarageSecondaryButton(
            label: 'Отменить заказ',
            icon: Icons.cancel_outlined,
            color: Colors.redAccent,
            onPressed: _working ? null : () => _cancel(order),
          ),
      ],
    );
  }
}

class _OrderProgress extends StatelessWidget {
  final String status;

  const _OrderProgress({required this.status});

  @override
  Widget build(BuildContext context) {
    const stages = [
      ('awaiting_payment', 'Ожидает оплаты'),
      ('paid', 'Оплачено'),
      ('purchasing', 'Выкупаем'),
      ('completed', 'Завершено'),
    ];
    final index = switch (status) {
      'awaiting_payment' || 'payment_review' => 0,
      'paid' => 1,
      'purchasing' || 'purchased' || 'partially_purchased' => 2,
      'completed' || 'refunded' => 3,
      _ => 0,
    };
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var position = 0; position < stages.length; position++) ...[
            SizedBox(
              width: 112,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: position <= index
                          ? context.brandPrimary
                          : const Color(0xFFE4E7EC),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    stages[position].$2,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: position <= index
                          ? context.brandPrimary
                          : AppColors.textSecondary,
                      fontFamily: 'Gilroy',
                      fontSize: 11,
                      fontWeight: position == index
                          ? FontWeight.w900
                          : FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            if (position != stages.length - 1) const SizedBox(width: 7),
          ],
        ],
      ),
    );
  }
}

@visibleForTesting
bool canPayGarageOrder(GarageOrder order, GarageInvoice invoice) {
  if (!{'awaiting_payment', 'payment_review'}.contains(order.status) ||
      !{
        'unpaid',
        'awaiting_payment',
        'payment_review',
      }.contains(invoice.status)) {
    return false;
  }
  final summary = invoice.paymentSummary;
  if (summary != null) {
    if (summary.isPartial) return true;
    if (summary.isUnknown || summary.isFullyCovered) return false;
  }
  return order.status == 'awaiting_payment' &&
      {'unpaid', 'awaiting_payment'}.contains(invoice.status);
}
