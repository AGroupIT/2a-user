import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/app_colors.dart';
import '../../../core/utils/locale_text.dart';
import '../../payments/data/payment_operator_status.dart';
import '../../payments/presentation/client_payment_summary_panel.dart';
import '../../payments/presentation/payment_operator_sleeping_notice.dart';
import '../domain/garage_models.dart';
import 'garage_ui.dart';

@visibleForTesting
bool isTerminalGarageRefund(GarageInvoice invoice, GarageOrder order) {
  const terminalStatuses = {'cancelled', 'refunded'};
  return terminalStatuses.contains(invoice.status.toLowerCase()) ||
      terminalStatuses.contains(order.status.toLowerCase()) ||
      order.refundState == 'refunded';
}

class GarageInvoiceCard extends ConsumerWidget {
  final GarageInvoice invoice;
  final GarageOrder order;
  final VoidCallback? onPay;

  const GarageInvoiceCard({
    super.key,
    required this.invoice,
    required this.order,
    required this.onPay,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final operatorsSleeping =
        onPay != null &&
        paymentOperatorStatusOrWorking(
          ref.watch(paymentOperatorStatusProvider),
        ).sleeping;
    return GarageCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: context.brandPrimary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.receipt_long_rounded,
                  color: context.brandPrimary,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Счёт ${invoice.invoiceNumber}',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontFamily: 'Gilroy',
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Заказ ${order.orderNumber}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontFamily: 'Gilroy',
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              GarageStatusChip(status: invoice.status),
            ],
          ),
          const SizedBox(height: 14),
          GarageInfoRow(
            label: 'Товары',
            value: garageMoney(order.goodsTotalCny, '¥'),
          ),
          GarageInfoRow(
            label: 'Доставка по Китаю',
            value: garageMoney(order.chinaDeliveryTotalCny, '¥'),
          ),
          if (order.discountCny > 0)
            GarageInfoRow(
              label: 'Скидка',
              value: '-${garageMoney(order.discountCny, '¥')}',
            ),
          GarageInfoRow(
            label: 'Курс CNY/RUB',
            value: invoice.clientCnyRubRateSnapshot.toStringAsFixed(4),
          ),
          const Divider(height: 22),
          GarageInfoRow(
            label: 'Итого',
            value:
                '${garageMoney(invoice.totalCny, '¥')} · ${garageMoney(invoice.totalRub, '₽')}',
            emphasized: true,
          ),
          if (invoice.paymentSummary case final paymentSummary?) ...[
            const SizedBox(height: 12),
            ClientPaymentSummaryPanel(
              summary: paymentSummary,
              terminalRefund: isTerminalGarageRefund(invoice, order),
            ),
          ],
          if (onPay != null) ...[
            const SizedBox(height: 13),
            if (operatorsSleeping)
              const PaymentOperatorSleepingNotice(compact: true)
            else
              GaragePrimaryButton(
                label: invoice.paymentSummary?.isPartial == true
                    ? tr(
                        context,
                        ru: 'Доплатить ${invoice.paymentSummary!.remainingRub.display} по QR',
                        zh: '扫码补付 ${invoice.paymentSummary!.remainingRub.display}',
                      )
                    : tr(
                        context,
                        ru: 'Оплатить по Bank QR',
                        zh: '使用 Bank QR 付款',
                      ),
                icon: Icons.qr_code_2_rounded,
                onPressed: onPay,
              ),
          ],
        ],
      ),
    );
  }
}
