import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/ui/app_colors.dart';
import '../../../core/utils/locale_text.dart';
import '../data/current_cny_rate_provider.dart';

class HomeCnyRateCard extends StatelessWidget {
  final AsyncValue<CurrentCnyRate?> rate;
  final VoidCallback onRetry;
  const HomeCnyRateCard({super.key, required this.rate, required this.onRetry});

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(child: _currency(context, usd: false)),
      const SizedBox(width: 8),
      Expanded(child: _currency(context, usd: true)),
    ],
  );

  Widget _currency(BuildContext context, {required bool usd}) {
    final data = rate.asData?.value;
    final value = usd ? data?.rubPerUsd : data?.rubPerCny;
    final locale = Localizations.localeOf(context).languageCode;
    final decimal = value?.toStringAsFixed(2);
    final localized = locale == 'zh'
        ? decimal
        : decimal?.replaceFirst('.', ',');
    final rateText = value == null
        ? '—'
        : '1 ${usd ? '\$' : '¥'} = $localized ₽';
    final title = usd
        ? tr(context, ru: 'Курс доллара', zh: '美元汇率')
        : tr(context, ru: 'Курс юаня', zh: '人民币汇率');
    final detail = rate.isLoading
        ? tr(context, ru: 'Обновляем курс', zh: '正在更新汇率')
        : rate.hasError
        ? tr(context, ru: 'Курс временно недоступен', zh: '汇率暂时不可用')
        : value == null
        ? tr(context, ru: 'Курс пока не опубликован', zh: '汇率尚未发布')
        : tr(
            context,
            ru: 'Курс на ${DateFormat('dd.MM.yyyy').format(data!.date)}',
            zh: '${DateFormat('yyyy.MM.dd').format(data.date)} 汇率',
          );
    return Semantics(
      container: true,
      label: '$title: $rateText',
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: context.brandPrimary.withValues(alpha: 0.10),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              usd ? 'USD / RUB' : 'CNY / RUB',
              style: TextStyle(
                fontFamily: 'Gilroy',
                color: context.brandPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              title,
              style: const TextStyle(
                fontFamily: 'Gilroy',
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
              ),
            ),
            const SizedBox(height: 5),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                rateText,
                maxLines: 1,
                style: const TextStyle(
                  fontFamily: 'Gilroy',
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                ),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              detail,
              style: const TextStyle(
                fontFamily: 'Gilroy',
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
            if (rate.isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else if (rate.hasError)
              IconButton(
                onPressed: onRetry,
                tooltip: tr(context, ru: 'Повторить', zh: '重试'),
                icon: Icon(Icons.refresh_rounded, color: context.brandPrimary),
              ),
          ],
        ),
      ),
    );
  }
}
