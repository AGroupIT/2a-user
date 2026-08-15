import 'package:flutter/material.dart';

import '../../../core/ui/app_colors.dart';
import '../../../core/utils/locale_text.dart';
import 'sp_finance_ui.dart';

String spOrganizerPurchaseKindLabel(BuildContext context, String kind) {
  return switch (kind) {
    'personal' => tr(context, ru: 'Для себя', zh: '自用'),
    'individual' => tr(context, ru: 'Один клиент', zh: '单个客户'),
    _ => tr(context, ru: 'Совместная', zh: '多人拼团'),
  };
}

IconData spOrganizerPurchaseKindIcon(String kind) {
  return switch (kind) {
    'personal' => Icons.person_rounded,
    'individual' => Icons.person_pin_rounded,
    _ => Icons.groups_2_rounded,
  };
}

class SpOrganizerPurchaseKindSelector extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const SpOrganizerPurchaseKindSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    const kinds = ['personal', 'individual', 'group'];
    final description = switch (value) {
      'personal' => tr(
        context,
        ru: 'Собственные товары организатора без клиентской прибыли.',
        zh: '团长自用商品，不计算客户利润。',
      ),
      'individual' => tr(
        context,
        ru: 'Закупка и расчёт для одного клиента.',
        zh: '为单个客户进行采购和结算。',
      ),
      _ => tr(
        context,
        ru: 'Несколько участников с отдельными товарами и оплатами.',
        zh: '多个参与者，分别管理商品和付款。',
      ),
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: SpFinanceUi.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr(context, ru: 'Тип закупки', zh: '采购类型'),
            style: SpFinanceUi.sectionTitleStyle,
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: kinds
                .map(
                  (kind) => _PurchaseKindButton(
                    buttonKey: ValueKey('sp-purchase-kind-$kind'),
                    selected: value == kind,
                    icon: spOrganizerPurchaseKindIcon(kind),
                    label: spOrganizerPurchaseKindLabel(context, kind),
                    onTap: value == kind ? null : () => onChanged(kind),
                  ),
                )
                .toList(growable: false),
          ),
          const SizedBox(height: 9),
          Text(description, style: SpFinanceUi.labelStyle),
        ],
      ),
    );
  }
}

class _PurchaseKindButton extends StatelessWidget {
  final Key buttonKey;
  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _PurchaseKindButton({
    required this.buttonKey,
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? Colors.white : AppColors.textSecondary;
    return Material(
      key: buttonKey,
      color: selected ? context.brandPrimary : const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: selected ? context.brandPrimary : const Color(0xFFE1E5ED),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 17, color: foreground),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  color: foreground,
                  fontFamily: 'Gilroy',
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
