import 'package:flutter/material.dart';

import '../../../../core/ui/app_colors.dart';
import '../../domain/marketplace.dart';

class MarketplaceSelector extends StatelessWidget {
  final List<Marketplace> marketplaces;
  final Marketplace selected;
  final ValueChanged<Marketplace> onChanged;

  const MarketplaceSelector({
    super.key,
    required this.marketplaces,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: marketplaces.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final mp = marketplaces[index];
          final isSelected = mp == selected;

          return ChoiceChip(
            label: Text(mp.displayName),
            selected: isSelected,
            onSelected: (_) => onChanged(mp),
            selectedColor: context.brandPrimary,
            backgroundColor: Colors.white,
            labelStyle: TextStyle(
              color: isSelected ? Colors.white : AppColors.textPrimary,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              fontSize: 14,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: isSelected ? Colors.transparent : Colors.grey.shade300,
              ),
            ),
            showCheckmark: false,
            padding: const EdgeInsets.symmetric(horizontal: 12),
          );
        },
      ),
    );
  }
}
