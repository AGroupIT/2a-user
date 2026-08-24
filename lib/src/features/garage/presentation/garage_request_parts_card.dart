import 'package:flutter/material.dart';

import '../../../core/ui/app_colors.dart';
import '../domain/garage_models.dart';
import 'garage_media_image.dart';
import 'garage_translated_text.dart';
import 'garage_ui.dart';

class GaragePartPositionCard extends StatelessWidget {
  final GarageRequestItem item;
  final List<GaragePartOption> options;
  final bool hasPublishedOffer;
  final Map<int, GarageOfferSelection> selections;
  final bool enabled;
  final void Function(GaragePartOption option, bool selected) onOptionChanged;
  final void Function(GaragePartOption option, int quantity) onQuantityChanged;

  const GaragePartPositionCard({
    super.key,
    required this.item,
    required this.options,
    required this.hasPublishedOffer,
    required this.selections,
    required this.enabled,
    required this.onOptionChanged,
    required this.onQuantityChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey('garage-part-position-${item.id}'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFFE4E7EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (item.imageUrl?.trim().isNotEmpty == true) ...[
            GarageImageStrip(
              imagePaths: [item.imageUrl!],
              keyPrefix: 'garage-request-item-${item.id}',
              fallbackFileNamePrefix: 'garage-part-${item.id}',
              imageSize: 112,
            ),
            const SizedBox(height: 11),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: context.brandPrimary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Text(
                  '${item.orderNumber}',
                  style: TextStyle(
                    color: context.brandPrimary,
                    fontFamily: 'Gilroy',
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.partName,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontFamily: 'Gilroy',
                        fontSize: 14,
                        height: 1.15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (item.partNumber.trim().isNotEmpty)
                          GaragePartsBadge(
                            label: item.partNumber.trim(),
                            compact: true,
                          ),
                        GaragePartsBadge(
                          label: '${item.quantity} шт.',
                          compact: true,
                        ),
                        GaragePartsBadge(
                          label: _preference(item.preference),
                          compact: true,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Подобранные варианты',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontFamily: 'Gilroy',
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (options.isNotEmpty)
                GaragePartsBadge(label: '${options.length}', compact: true),
            ],
          ),
          const SizedBox(height: 7),
          if (options.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.schedule_rounded,
                    size: 17,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      hasPublishedOffer
                          ? 'Варианты ещё не добавлены'
                          : 'Менеджер ещё подбирает варианты',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontFamily: 'Gilroy',
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            for (var index = 0; index < options.length; index++) ...[
              _GarageOptionChoiceCard(
                option: options[index],
                selected: selections.containsKey(options[index].id),
                quantity: selections[options[index].id]?.quantity ?? 1,
                enabled: enabled,
                onChanged: (selected) =>
                    onOptionChanged(options[index], selected),
                onQuantityChanged: (quantity) =>
                    onQuantityChanged(options[index], quantity),
              ),
              if (index != options.length - 1) const SizedBox(height: 7),
            ],
        ],
      ),
    );
  }
}

class _GarageOptionChoiceCard extends StatelessWidget {
  final GaragePartOption option;
  final bool selected;
  final int quantity;
  final bool enabled;
  final ValueChanged<bool> onChanged;
  final ValueChanged<int> onQuantityChanged;

  const _GarageOptionChoiceCard({
    required this.option,
    required this.selected,
    required this.quantity,
    required this.enabled,
    required this.onChanged,
    required this.onQuantityChanged,
  });

  @override
  Widget build(BuildContext context) {
    final title = '${option.manufacturer} ${option.partNumber}'.trim();
    final translatedTitle = option.manufacturerRu?.trim().isNotEmpty == true
        ? '${option.manufacturerRu!.trim()} ${option.partNumber}'.trim()
        : null;
    return Material(
      color: selected
          ? context.brandPrimary.withValues(alpha: 0.08)
          : const Color(0xFFF7F8FA),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: enabled ? () => onChanged(!selected) : null,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            border: Border.all(
              color: selected ? context.brandPrimary : const Color(0xFFE4E7EC),
              width: selected ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    key: ValueKey('garage-option-${option.id}-checkbox'),
                    value: selected,
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onChanged: enabled
                        ? (value) => onChanged(value ?? false)
                        : null,
                    activeColor: context.brandPrimary,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GarageTranslatedText(
                          title.isEmpty ? 'Вариант запчасти' : title,
                          translatedText: translatedTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontFamily: 'Gilroy',
                            fontSize: 14,
                            height: 1.15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 5),
                        GaragePartsBadge(
                          key: ValueKey('garage-option-${option.id}-type'),
                          label: garageOptionTypeLabel(option.optionType),
                          compact: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        garageMoney(option.clientUnitPriceRub, '₽'),
                        style: TextStyle(
                          color: context.brandPrimary,
                          fontFamily: 'Gilroy',
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        garageMoney(option.clientUnitPriceCny, '¥'),
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
              Padding(
                padding: const EdgeInsets.only(left: 35),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (option.imageUrls.isNotEmpty) ...[
                      const SizedBox(height: 9),
                      GarageImageStrip(
                        imagePaths: option.imageUrls,
                        keyPrefix: 'garage-option-${option.id}',
                        fallbackFileNamePrefix: 'garage-option-${option.id}',
                        imageSize: 68,
                      ),
                    ],
                    if (option.displayDescription != null) ...[
                      const SizedBox(height: 8),
                      GarageTranslatedText(
                        option.description ?? option.displayDescription!,
                        translatedText: option.descriptionRu,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontFamily: 'Gilroy',
                          fontSize: 12.5,
                          height: 1.25,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (option.displayEmployeeComment != null) ...[
                      const SizedBox(height: 7),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 15,
                            color: context.brandPrimary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: GarageTranslatedText(
                              option.employeeComment ??
                                  option.displayEmployeeComment!,
                              translatedText: option.employeeCommentRu,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontFamily: 'Gilroy',
                                fontSize: 12.5,
                                height: 1.25,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (selected) ...[
                      const Divider(height: 18),
                      Row(
                        children: [
                          const Text(
                            'Количество',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontFamily: 'Gilroy',
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          _GarageQuantityControls(
                            optionId: option.id,
                            quantity: quantity,
                            enabled: enabled,
                            onChanged: onQuantityChanged,
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GarageQuantityControls extends StatelessWidget {
  final int optionId;
  final int quantity;
  final bool enabled;
  final ValueChanged<int> onChanged;

  const _GarageQuantityControls({
    required this.optionId,
    required this.quantity,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final canDecrease = enabled && quantity > 1;
    final canIncrease = enabled && quantity < 999;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _quantityButton(
          key: ValueKey('garage-option-$optionId-minus'),
          icon: Icons.remove_rounded,
          enabled: canDecrease,
          onTap: () => onChanged(quantity - 1),
        ),
        SizedBox(
          width: 42,
          child: Text(
            '$quantity',
            key: ValueKey('garage-option-$optionId-quantity'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontFamily: 'Gilroy',
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        _quantityButton(
          key: ValueKey('garage-option-$optionId-plus'),
          icon: Icons.add_rounded,
          enabled: canIncrease,
          onTap: () => onChanged(quantity + 1),
        ),
      ],
    );
  }

  Widget _quantityButton({
    required Key key,
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return InkWell(
      key: key,
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: enabled ? const Color(0xFFE9EDF2) : const Color(0xFFF1F3F6),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 17,
          color: enabled ? AppColors.textPrimary : const Color(0xFFB6BDC8),
        ),
      ),
    );
  }
}

String _preference(GaragePartPreference preference) {
  return switch (preference) {
    GaragePartPreference.original => 'оригинал',
    GaragePartPreference.analog => 'аналог',
    GaragePartPreference.any => 'любой',
    GaragePartPreference.unknown => 'не указано',
  };
}
