import 'package:flutter/material.dart';

import '../../../core/ui/app_colors.dart';
import '../domain/garage_models.dart';
import 'garage_ui.dart';

class GarageInvoiceCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
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
          if (onPay != null) ...[
            const SizedBox(height: 13),
            GaragePrimaryButton(
              label: 'Оплатить по Bank QR',
              icon: Icons.qr_code_2_rounded,
              onPressed: onPay,
            ),
          ],
        ],
      ),
    );
  }
}
