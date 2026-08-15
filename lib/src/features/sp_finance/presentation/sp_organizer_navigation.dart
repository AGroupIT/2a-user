import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/app_colors.dart';
import '../../../core/utils/locale_text.dart';
import '../data/sp_organizer_models.dart';
import 'sp_finance_ui.dart';

enum SpOrganizerSection { purchases, customers, products, analytics }

class SpOrganizerNavigation extends StatelessWidget {
  final SpOrganizerCapabilities capabilities;
  final SpOrganizerSection selected;
  final ValueChanged<SpOrganizerSection>? onSelected;

  const SpOrganizerNavigation({
    super.key,
    required this.capabilities,
    required this.selected,
    this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (!capabilities.hasOrganizerTools) return const SizedBox.shrink();

    final items = <_OrganizerNavItem>[
      _OrganizerNavItem(
        section: SpOrganizerSection.purchases,
        icon: Icons.groups_2_rounded,
        label: tr(context, ru: 'Закупки', zh: '采购'),
        route: '/sp-finance',
      ),
      if (capabilities.customersDirectory)
        _OrganizerNavItem(
          section: SpOrganizerSection.customers,
          icon: Icons.people_alt_rounded,
          label: tr(context, ru: 'Клиенты', zh: '客户'),
          route: '/sp-finance/customers',
        ),
      if (capabilities.products)
        _OrganizerNavItem(
          section: SpOrganizerSection.products,
          icon: Icons.inventory_2_rounded,
          label: tr(context, ru: 'Товары', zh: '商品'),
          route: '/sp-finance/products',
        ),
      if (capabilities.analytics)
        _OrganizerNavItem(
          section: SpOrganizerSection.analytics,
          icon: Icons.query_stats_rounded,
          label: tr(context, ru: 'Аналитика', zh: '分析'),
          route: '/sp-finance/analytics',
        ),
    ];

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: SpFinanceUi.cardDecoration(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 380;
          final stacked = items.length > 2 && constraints.maxWidth < 560;
          return Row(
            children: [
              for (var index = 0; index < items.length; index++) ...[
                if (index > 0) SizedBox(width: stacked ? 5 : 8),
                Expanded(
                  child: _OrganizerNavButton(
                    item: items[index],
                    compact: compact,
                    stacked: stacked,
                    selected: selected == items[index].section,
                    onTap: () => _select(context, items[index]),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  void _select(BuildContext context, _OrganizerNavItem item) {
    if (selected == item.section) return;
    final callback = onSelected;
    if (callback != null) {
      callback(item.section);
      return;
    }
    context.go(item.route);
  }
}

class _OrganizerNavItem {
  final SpOrganizerSection section;
  final IconData icon;
  final String label;
  final String route;

  const _OrganizerNavItem({
    required this.section,
    required this.icon,
    required this.label,
    required this.route,
  });
}

class _OrganizerNavButton extends StatelessWidget {
  final _OrganizerNavItem item;
  final bool selected;
  final bool compact;
  final bool stacked;
  final VoidCallback onTap;

  const _OrganizerNavButton({
    required this.item,
    required this.selected,
    required this.compact,
    required this.stacked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? Colors.white : AppColors.textSecondary;
    return Material(
      color: selected ? context.brandPrimary : const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        onTap: selected ? null : onTap,
        borderRadius: BorderRadius.circular(17),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: stacked ? 3 : (compact ? 9 : 12),
            vertical: stacked ? 9 : 12,
          ),
          child: stacked
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(item.icon, color: foreground, size: 19),
                    const SizedBox(height: 4),
                    Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: foreground,
                        fontFamily: 'Gilroy',
                        fontSize: compact ? 10.5 : 11.5,
                        height: 1,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(item.icon, color: foreground, size: 19),
                    const SizedBox(width: 7),
                    Flexible(
                      child: Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: foreground,
                          fontFamily: 'Gilroy',
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
