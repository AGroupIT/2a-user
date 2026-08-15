import 'package:flutter/material.dart';

import '../../../core/ui/app_colors.dart';
import '../data/sp_v2_models.dart';
import 'sp_finance_ui.dart';

class SpPurchaseClientSectionsEditor extends StatelessWidget {
  final SpV2ClientCardSections value;
  final ValueChanged<SpV2ClientCardSections> onChanged;

  const SpPurchaseClientSectionsEditor({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: SpFinanceUi.cardDecoration(),
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'Разделы в карточке клиента',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontFamily: 'Gilroy',
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 4),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'Выберите, какие рабочие блоки показывать внутри этой СП.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontFamily: 'Gilroy',
                fontSize: 12.5,
                height: 1.25,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 8),
          _SectionSwitch(
            key: const Key('sp-client-section-tariff'),
            title: 'Тариф',
            subtitle: 'Курс и параметры расчёта для клиента',
            icon: Icons.calculate_rounded,
            value: value.showTariff,
            onChanged: (enabled) =>
                onChanged(value.copyWith(showTariff: enabled)),
          ),
          _SectionSwitch(
            key: const Key('sp-client-section-custom-price'),
            title: 'Своя цена для клиента',
            subtitle: 'Цена товара, назначенная организатором',
            icon: Icons.sell_rounded,
            value: value.showCustomPrice,
            onChanged: (enabled) =>
                onChanged(value.copyWith(showCustomPrice: enabled)),
          ),
          _SectionSwitch(
            key: const Key('sp-client-section-finance'),
            title: 'Финансы',
            subtitle: 'Суммы, долги и отметки оплат клиента',
            icon: Icons.payments_rounded,
            value: value.showFinance,
            onChanged: (enabled) =>
                onChanged(value.copyWith(showFinance: enabled)),
          ),
          _SectionSwitch(
            key: const Key('sp-client-section-delivery'),
            title: 'Доставка до клиента',
            subtitle: 'Отправка, трек и стоимость доставки от вас',
            icon: Icons.local_shipping_rounded,
            value: value.showDelivery,
            onChanged: (enabled) =>
                onChanged(value.copyWith(showDelivery: enabled)),
          ),
        ],
      ),
    );
  }
}

class _SectionSwitch extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SectionSwitch({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: value,
      label: '$title. $subtitle',
      child: SwitchListTile.adaptive(
        contentPadding: const EdgeInsets.symmetric(horizontal: 2),
        secondary: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: context.brandPrimary.withValues(alpha: 0.09),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: context.brandPrimary, size: 20),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontFamily: 'Gilroy',
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontFamily: 'Gilroy',
            fontSize: 12,
            height: 1.2,
            fontWeight: FontWeight.w600,
          ),
        ),
        value: value,
        activeTrackColor: context.brandPrimary.withValues(alpha: 0.55),
        activeThumbColor: context.brandPrimary,
        onChanged: onChanged,
      ),
    );
  }
}
