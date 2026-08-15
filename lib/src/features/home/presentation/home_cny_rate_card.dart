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
  Widget build(BuildContext context) {
    final value = rate.asData?.value;
    final isLoading = rate.isLoading;
    final hasError = rate.hasError;
    final locale = Localizations.localeOf(context).languageCode;
    final rateText = value == null
        ? '—'
        : _formatRate(value.rubPerCny, locale: locale);
    final detailText = switch ((isLoading, hasError, value)) {
      (true, _, _) => tr(context, ru: 'Обновляем курс', zh: '正在更新汇率'),
      (_, true, _) => tr(
        context,
        ru: 'Курс временно недоступен',
        zh: '汇率暂时不可用',
      ),
      (_, _, null) => tr(
        context,
        ru: 'Актуальный курс пока не опубликован',
        zh: '当前汇率尚未发布',
      ),
      _ => tr(
        context,
        ru: 'Курс на ${DateFormat('dd.MM.yyyy').format(value!.date)}',
        zh: '${DateFormat('yyyy.MM.dd').format(value.date)} 汇率',
      ),
    };

    return Semantics(
      container: true,
      label: tr(
        context,
        ru: 'Актуальный курс юаня: $rateText',
        zh: '当前人民币汇率：$rateText',
      ),
      child: Container(
        constraints: const BoxConstraints(minHeight: 86),
        padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: context.brandPrimary.withValues(alpha: 0.10),
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF111827).withValues(alpha: 0.06),
              offset: const Offset(0, 8),
              blurRadius: 24,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: context.brandPrimary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: Text(
                '¥',
                style: TextStyle(
                  color: context.brandPrimary,
                  fontFamily: 'Gilroy',
                  fontWeight: FontWeight.w900,
                  fontSize: 27,
                  height: 1,
                ),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    tr(context, ru: 'Актуальный курс юаня', zh: '当前人民币汇率'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontFamily: 'Gilroy',
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: Text(
                      rateText,
                      key: ValueKey(rateText),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontFamily: 'Gilroy',
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                        height: 1.05,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    detailText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: hasError
                          ? const Color(0xFFB45309)
                          : AppColors.textSecondary,
                      fontFamily: 'Gilroy',
                      fontWeight: FontWeight.w600,
                      fontSize: 11.5,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ),
            if (isLoading)
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: context.brandPrimary,
                ),
              )
            else if (hasError)
              IconButton(
                onPressed: onRetry,
                tooltip: tr(context, ru: 'Повторить', zh: '重试'),
                icon: Icon(Icons.refresh_rounded, color: context.brandPrimary),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                  color: context.brandPrimary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'CNY / RUB',
                  style: TextStyle(
                    color: context.brandPrimary,
                    fontFamily: 'Gilroy',
                    fontWeight: FontWeight.w800,
                    fontSize: 10.5,
                    height: 1,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static String _formatRate(double value, {required String locale}) {
    final decimal = value.toStringAsFixed(2);
    final localized = locale == 'zh' ? decimal : decimal.replaceFirst('.', ',');
    return '1 ¥ = $localized ₽';
  }
}
