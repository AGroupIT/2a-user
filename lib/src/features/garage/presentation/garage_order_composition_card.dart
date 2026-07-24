import 'package:flutter/material.dart';

import '../../../core/ui/app_colors.dart';
import '../domain/garage_models.dart';
import 'garage_media_image.dart';
import 'garage_translated_text.dart';
import 'garage_ui.dart';

class GarageOrderCompositionCard extends StatelessWidget {
  final GarageOrder order;

  const GarageOrderCompositionCard({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    return GarageCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Состав заказа · ${order.items.length}',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontFamily: 'Gilroy',
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          for (var index = 0; index < order.items.length; index++) ...[
            _GarageOrderItemRow(item: order.items[index]),
            if (index != order.items.length - 1) const Divider(height: 26),
          ],
          const Divider(height: 26),
          GarageInfoRow(
            label: 'Товары',
            value: garageMoney(order.goodsTotalCny, '¥'),
          ),
          GarageInfoRow(
            label: 'Доставка по Китаю',
            value: garageMoney(order.chinaDeliveryTotalCny, '¥'),
          ),
          GarageInfoRow(
            label: 'Курс CNY/RUB',
            value: order.clientCnyRubRateSnapshot.toStringAsFixed(4),
          ),
          const Divider(height: 20),
          GarageInfoRow(
            label: 'Итого',
            value:
                '${garageMoney(order.totalCny, '¥')} · ${garageMoney(order.totalRub, '₽')}',
            emphasized: true,
          ),
        ],
      ),
    );
  }
}

class _GarageOrderItemRow extends StatelessWidget {
  final GarageOrderItem item;

  const _GarageOrderItemRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final title = '${item.manufacturer} ${item.partNumber}'.trim();
    final translatedTitle = item.manufacturerRu?.trim().isNotEmpty == true
        ? '${item.manufacturerRu!.trim()} ${item.partNumber}'.trim()
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (item.imageUrls.isNotEmpty) ...[
          GarageImageStrip(
            imagePaths: item.imageUrls,
            keyPrefix: 'garage-order-item-${item.id}',
            fallbackFileNamePrefix: 'garage-order-item-${item.id}',
            imageSize: 78,
          ),
          const SizedBox(height: 12),
        ],
        Text(
          item.partName,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontFamily: 'Gilroy',
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
        if (title.isNotEmpty) ...[
          const SizedBox(height: 4),
          GarageTranslatedText(
            title,
            translatedText: translatedTitle,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontFamily: 'Gilroy',
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        if (item.description?.trim().isNotEmpty == true) ...[
          const SizedBox(height: 7),
          GarageTranslatedText(
            item.description!,
            translatedText: item.descriptionRu,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontFamily: 'Gilroy',
              fontSize: 12.5,
              height: 1.25,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _Metric(label: 'Количество', value: '${item.quantity} шт.'),
            _Metric(
              label: 'Цена за единицу',
              value:
                  '${garageMoney(item.clientUnitPriceCny, '¥')} · ${garageMoney(item.clientUnitPriceRub, '₽')}',
            ),
            _Metric(
              label: 'Сумма',
              value:
                  '${garageMoney(item.lineTotalCny, '¥')} · ${garageMoney(item.lineTotalRub, '₽')}',
              emphasized: true,
            ),
          ],
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasized;

  const _Metric({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 132),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: emphasized
            ? context.brandPrimary.withValues(alpha: 0.08)
            : const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontFamily: 'Gilroy',
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              color: emphasized ? context.brandPrimary : AppColors.textPrimary,
              fontFamily: 'Gilroy',
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
