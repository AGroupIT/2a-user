import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ui/app_colors.dart';
import '../../data/shop_provider.dart';
import '../../domain/marketplace.dart';

class MarketplaceSelector extends ConsumerWidget {
  final ValueChanged<Marketplace>? onChanged;

  const MarketplaceSelector({super.key, this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedMarketplaceProvider);

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: Marketplace.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final mp = Marketplace.values[index];
          final isSelected = mp == selected;

          return ChoiceChip(
            label: Text(mp.displayName),
            selected: isSelected,
            onSelected: (_) {
              ref.read(selectedMarketplaceProvider.notifier).select(mp);
              onChanged?.call(mp);
            },
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
