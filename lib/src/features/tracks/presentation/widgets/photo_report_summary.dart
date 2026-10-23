import 'package:flutter/material.dart';
import '../../../../core/utils/locale_text.dart';
import '../../domain/track_item.dart';

class PhotoReportSummary extends StatelessWidget {
  final PhotoRequest request;
  const PhotoReportSummary({super.key, required this.request});

  @override
  Widget build(BuildContext context) {
    if (request.reportType == 'legacy') return const SizedBox.shrink();
    final price = double.tryParse(request.priceUsd) ?? 0;
    final charge = request.charge;
    final status = charge?['status'];
    final type = request.reportType == 'custom'
        ? tr(context, ru: 'Проверка по заданию', zh: '按要求检查')
        : tr(context, ru: 'Стандартный фотоотчёт', zh: '标准拍照报告');
    final amount = price == 0
        ? tr(context, ru: 'Бесплатно', zh: '免费')
        : '\$${price.toStringAsFixed(2)}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$type · $amount',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          if (charge != null)
            Text(
              status == 'paid'
                  ? tr(
                      context,
                      ru: 'Оплачено в счёте ${charge['invoiceNumber'] ?? ''}',
                      zh: '已在账单 ${charge['invoiceNumber'] ?? ''} 中支付',
                    )
                  : status == 'invoiced'
                  ? tr(
                      context,
                      ru: 'Включено в счёт ${charge['invoiceNumber'] ?? ''}',
                      zh: '已计入账单 ${charge['invoiceNumber'] ?? ''}',
                    )
                  : tr(
                      context,
                      ru: 'Будет включено в ближайший счёт на доставку',
                      zh: '将计入下一张运输账单',
                    ),
            ),
        ],
      ),
    );
  }
}
