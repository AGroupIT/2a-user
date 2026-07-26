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
            _GarageOrderItemCard(item: order.items[index]),
            if (index != order.items.length - 1) const SizedBox(height: 8),
          ],
          const SizedBox(height: 12),
          _FinancialSummary(order: order),
        ],
      ),
    );
  }
}

class _GarageOrderItemCard extends StatelessWidget {
  final GarageOrderItem item;

  const _GarageOrderItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final title = '${item.manufacturer} ${item.partNumber}'.trim();
    final translatedTitle = item.manufacturerRu?.trim().isNotEmpty == true
        ? '${item.manufacturerRu!.trim()} ${item.partNumber}'.trim()
        : null;
    return Container(
      key: ValueKey('garage-order-item-${item.id}-card'),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFFE4E7EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.partName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontFamily: 'Gilroy',
                        fontSize: 14.5,
                        height: 1.15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (title.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      GarageTranslatedText(
                        title,
                        translatedText: translatedTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontFamily: 'Gilroy',
                          fontSize: 12.5,
                          height: 1.15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    garageMoney(item.lineTotalRub, '₽'),
                    style: TextStyle(
                      color: context.brandPrimary,
                      fontFamily: 'Gilroy',
                      fontSize: 15.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    garageMoney(item.lineTotalCny, '¥'),
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontFamily: 'Gilroy',
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 7),
          Align(
            alignment: Alignment.centerLeft,
            child: GaragePartsBadge(
              key: ValueKey('garage-order-item-${item.id}-type'),
              label: garageOptionTypeLabel(item.optionType),
              compact: true,
            ),
          ),
          if (item.imageUrls.isNotEmpty) ...[
            const SizedBox(height: 9),
            GarageImageStrip(
              imagePaths: item.imageUrls,
              keyPrefix: 'garage-order-item-${item.id}',
              fallbackFileNamePrefix: 'garage-order-item-${item.id}',
              imageSize: 64,
            ),
          ],
          if (item.description?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 8),
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
          const SizedBox(height: 9),
          _PurchaseInfo(item: item),
          const SizedBox(height: 9),
          _ItemPriceSummary(item: item),
        ],
      ),
    );
  }
}

class _PurchaseInfo extends StatelessWidget {
  final GarageOrderItem item;

  const _PurchaseInfo({required this.item});

  @override
  Widget build(BuildContext context) {
    final purchased = item.purchaseStatus == 'purchased';
    final color = purchased ? const Color(0xFF16A34A) : context.brandPrimary;
    final supplierOrderNumber = item.supplierOrderNumber?.trim();

    return Container(
      key: ValueKey('garage-order-item-${item.id}-purchase'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  purchased
                      ? Icons.check_circle_outline_rounded
                      : Icons.schedule_rounded,
                  size: 18,
                  color: color,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Статус закупки',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontFamily: 'Gilroy',
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            purchased ? 'Выкуплена' : 'Ожидает выкупа',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: color,
                              fontFamily: 'Gilroy',
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        if (purchased && item.purchasedAt != null) ...[
                          const SizedBox(width: 6),
                          Text(
                            '· ${_purchaseDate(item.purchasedAt!)}',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontFamily: 'Gilroy',
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (supplierOrderNumber?.isNotEmpty == true) ...[
            const Divider(height: 15),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(
                  child: Text(
                    'Номер заказа / трек',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontFamily: 'Gilroy',
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: SelectableText(
                    supplierOrderNumber!,
                    key: ValueKey(
                      'garage-order-item-${item.id}-supplier-order',
                    ),
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontFamily: 'Gilroy',
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ItemPriceSummary extends StatelessWidget {
  final GarageOrderItem item;

  const _ItemPriceSummary({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey('garage-order-item-${item.id}-price-summary'),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        children: [
          Expanded(
            child: _PriceFact(
              label: 'Количество',
              primary: '${item.quantity} шт.',
            ),
          ),
          const _PriceDivider(),
          Expanded(
            child: _PriceFact(
              label: 'Цена за ед.',
              primary: garageMoney(item.clientUnitPriceRub, '₽'),
              secondary: garageMoney(item.clientUnitPriceCny, '¥'),
            ),
          ),
          const _PriceDivider(),
          Expanded(
            child: _PriceFact(
              label: 'Сумма',
              primary: garageMoney(item.lineTotalRub, '₽'),
              secondary: garageMoney(item.lineTotalCny, '¥'),
              emphasized: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _PriceDivider extends StatelessWidget {
  const _PriceDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 38,
      margin: const EdgeInsets.symmetric(horizontal: 7),
      color: const Color(0xFFE4E7EC),
    );
  }
}

class _PriceFact extends StatelessWidget {
  final String label;
  final String primary;
  final String? secondary;
  final bool emphasized;

  const _PriceFact({
    required this.label,
    required this.primary,
    this.secondary,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontFamily: 'Gilroy',
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          primary,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: emphasized ? context.brandPrimary : AppColors.textPrimary,
            fontFamily: 'Gilroy',
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
        if (secondary != null) ...[
          const SizedBox(height: 1),
          Text(
            secondary!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontFamily: 'Gilroy',
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }
}

class _FinancialSummary extends StatelessWidget {
  final GarageOrder order;

  const _FinancialSummary({required this.order});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('garage-order-financial-summary'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.brandPrimary.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.brandPrimary.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Финансовая сводка',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontFamily: 'Gilroy',
              fontSize: 13.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
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
          const Divider(height: 18),
          GarageInfoRow(
            label: 'Итого',
            value:
                '${garageMoney(order.totalRub, '₽')} · ${garageMoney(order.totalCny, '¥')}',
            emphasized: true,
          ),
        ],
      ),
    );
  }
}

String _purchaseDate(DateTime value) {
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(local.day)}.${two(local.month)}.${local.year}';
}
