import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/app_colors.dart';
import '../../../core/ui/app_layout.dart';
import '../../../core/ui/scroll_to_top_button.dart';
import '../../../core/ui/tutorial_card.dart';
import '../data/tariffs_provider.dart';
import 'tariffs_ui.dart';

class TariffsScreen extends ConsumerStatefulWidget {
  const TariffsScreen({super.key});

  @override
  ConsumerState<TariffsScreen> createState() => _TariffsScreenState();
}

class _TariffsScreenState extends ConsumerState<TariffsScreen> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _tariffsListKey = GlobalKey();
  final GlobalKey _weightTiersKey = GlobalKey();
  final GlobalKey _packagingKey = GlobalKey();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tariffsAsync = ref.watch(userTariffsProvider);
    final topPad = AppLayout.topBarTotalHeight(context);
    final bottomPad = AppLayout.bottomScrollPadding(context);

    Future<void> onRefresh() async {
      ref.invalidate(userTariffsProvider);
      await ref.read(userTariffsProvider.future);
    }

    Widget buildFrame({required List<Widget> children}) {
      return Stack(
        children: [
          RefreshIndicator(
            onRefresh: onRefresh,
            color: context.brandPrimary,
            child: ListView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                16,
                topPad * 0.7 + 16,
                16,
                bottomPad + 16,
              ),
              children: children,
            ),
          ),
          ScrollToTopButton(controller: _scrollController),
        ],
      );
    }

    List<Widget> baseHeader() {
      return const [
        TariffsPageHeader(),
        SizedBox(height: 12),
        TariffsHeroCard(),
        SizedBox(height: 14),
      ];
    }

    return tariffsAsync.when(
      loading: () => buildFrame(
        children: [
          ...baseHeader(),
          const TariffsStateCard(
            icon: Icons.price_change_rounded,
            title: 'Загружаем тарифы',
            message: 'Получаем актуальные тарифы доставки и услуг.',
            isLoading: true,
          ),
        ],
      ),
      error: (e, _) => buildFrame(
        children: [
          ...baseHeader(),
          TariffsStateCard(
            icon: Icons.error_outline_rounded,
            title: 'Не удалось загрузить тарифы',
            message: 'Проверьте соединение и попробуйте ещё раз.',
            isError: true,
            actionLabel: 'Повторить',
            onAction: () => ref.invalidate(userTariffsProvider),
          ),
        ],
      ),
      data: (data) {
        final isEmpty =
            data.deliveryTariffs.isEmpty &&
            data.packagingTypes.isEmpty &&
            data.photoCoefficients.isEmpty;

        if (isEmpty) {
          return buildFrame(
            children: [
              ...baseHeader(),
              const TariffsStateCard(
                icon: Icons.price_change_outlined,
                title: 'Тарифы не настроены',
                message:
                    'Когда агент добавит тарифы, они появятся на этой странице.',
              ),
            ],
          );
        }

        return TutorialScreenWrapper(
          screenKey: 'tariffs',
          steps: [
            TutorialStep(
              icon: Icons.local_shipping_rounded,
              title: 'Тарифы доставки',
              description:
                  'Актуальная стоимость доставки по каждому тарифу. Цена указана за 1 кг. Тариф назначается менеджером при оформлении.',
              targetKey: _tariffsListKey,
            ),
            TutorialStep(
              icon: Icons.scale_rounded,
              title: 'Весовые диапазоны',
              description:
                  'Чем тяжелее партия — тем ниже цена за кг. Итоговый тариф выбирается автоматически при выставлении счёта.',
              targetKey: _weightTiersKey,
            ),
            TutorialStep(
              icon: Icons.inventory_rounded,
              title: 'Упаковка',
              description:
                  'Стоимость дополнительной упаковки прибавляется к счёту. Упаковка защищает товар при транспортировке.',
              targetKey: _packagingKey,
            ),
          ],
          child: buildFrame(
            children: [
              ...baseHeader(),
              if (data.deliveryTariffs.isNotEmpty) ...[
                for (var i = 0; i < data.deliveryTariffs.length; i++) ...[
                  if (i == 0)
                    KeyedSubtree(
                      key: _weightTiersKey,
                      child: _DeliveryTariffCard(
                        tariff: data.deliveryTariffs[i],
                      ),
                    )
                  else
                    _DeliveryTariffCard(tariff: data.deliveryTariffs[i]),
                  if (i != data.deliveryTariffs.length - 1)
                    const SizedBox(height: 12),
                ],
                const SizedBox(height: 16),
              ],
              if (data.packagingTypes.isNotEmpty) ...[
                KeyedSubtree(
                  key: _packagingKey,
                  child: const _SectionTitle(
                    icon: Icons.inventory_2_rounded,
                    title: 'Упаковка',
                    subtitle: 'Дополнительная защита товара при перевозке.',
                  ),
                ),
                const SizedBox(height: 10),
                _PackagingCard(types: data.packagingTypes),
                const SizedBox(height: 16),
              ],
              if (data.photoCoefficients.isNotEmpty) ...[
                const _SectionTitle(
                  icon: Icons.photo_camera_rounded,
                  title: 'Фотоотчёт',
                  subtitle: 'Коэффициент зависит от количества фотографий.',
                ),
                const SizedBox(height: 10),
                _PhotoReportCard(coefficients: data.photoCoefficients),
              ],
              const SizedBox(height: 12),
              const _TariffInfoNote(),
            ],
          ),
        );
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SectionTitle({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: context.brandPrimary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: context.brandPrimary, size: 22),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TariffsUi.sectionTitleStyle),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontFamily: 'Gilroy',
                  fontSize: 13,
                  height: 17 / 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DeliveryTariffCard extends StatelessWidget {
  final UserDeliveryTariff tariff;

  const _DeliveryTariffCard({required this.tariff});

  @override
  Widget build(BuildContext context) {
    final price = _mainPrice(tariff);
    final hasTiers = tariff.weightTiers.isNotEmpty;
    final hasAllowed = tariff.allowedItems?.trim().isNotEmpty == true;
    final hasProhibited = tariff.prohibitedItems?.trim().isNotEmpty == true;

    return Container(
      decoration: TariffsUi.cardDecoration(),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tariff.name,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontFamily: 'Gilroy',
                        fontSize: 18,
                        height: 22 / 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.15,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        _SmallPill(
                          icon: tariff.requiresProductInfo
                              ? Icons.assignment_outlined
                              : Icons.assignment_turned_in_outlined,
                          label: tariff.requiresProductInfo
                              ? 'Нужны данные о товаре'
                              : 'Без данных о товаре',
                          color: tariff.requiresProductInfo
                              ? context.brandPrimary
                              : const Color(0xFF2EAD63),
                        ),
                        if (hasTiers)
                          _SmallPill(
                            icon: Icons.scale_rounded,
                            label: 'Есть диапазоны веса',
                            color: const Color(0xFF3F7AE0),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _MainPriceBadge(price: price),
            ],
          ),
          if (hasTiers) ...[
            const SizedBox(height: 14),
            _WeightTiersBlock(tiers: tariff.weightTiers),
          ],
          if (hasAllowed || hasProhibited) ...[
            const SizedBox(height: 12),
            if (hasAllowed)
              _RulesTextBlock(
                icon: Icons.check_circle_outline_rounded,
                title: 'Разрешено',
                text: tariff.allowedItems!.trim(),
                color: const Color(0xFF2EAD63),
              ),
            if (hasAllowed && hasProhibited) const SizedBox(height: 8),
            if (hasProhibited)
              _RulesTextBlock(
                icon: Icons.cancel_outlined,
                title: 'Запрещено',
                text: tariff.prohibitedItems!.trim(),
                color: const Color(0xFFE53935),
              ),
          ],
        ],
      ),
    );
  }

  static double _mainPrice(UserDeliveryTariff tariff) {
    final prices = <double>[
      if (tariff.baseCost > 0) tariff.baseCost,
      ...tariff.weightTiers
          .map((tier) => tier.pricePerKg)
          .where((price) => price > 0),
    ];
    if (prices.isEmpty) return tariff.baseCost;
    return prices.reduce((a, b) => a < b ? a : b);
  }
}

class _MainPriceBadge extends StatelessWidget {
  final double price;

  const _MainPriceBadge({required this.price});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 86),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        gradient: context.brandGradient,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: context.brandPrimary.withValues(alpha: 0.18),
            blurRadius: 18,
            spreadRadius: -10,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            '\$${_fmt(price)}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'Gilroy',
              fontSize: 22,
              height: 1,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'за кг',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xE6FFFFFF),
              fontFamily: 'Gilroy',
              fontSize: 11.5,
              height: 1,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _SmallPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontFamily: 'Gilroy',
              fontSize: 11.5,
              height: 1,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _WeightTiersBlock extends StatelessWidget {
  final List<UserWeightTier> tiers;

  const _WeightTiersBlock({required this.tiers});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: TariffsUi.softDecoration(),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.scale_rounded, color: context.brandPrimary, size: 18),
              const SizedBox(width: 7),
              const Expanded(
                child: Text(
                  'Весовые диапазоны',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontFamily: 'Gilroy',
                    fontSize: 14,
                    height: 17 / 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < tiers.length; i++) ...[
            _ValueRow(
              label: tiers[i].maxWeight != null
                  ? '${_fmt(tiers[i].minWeight)} – ${_fmt(tiers[i].maxWeight!)} кг'
                  : 'от ${_fmt(tiers[i].minWeight)} кг',
              value: '\$${_fmt(tiers[i].pricePerKg)} / кг',
            ),
            if (i != tiers.length - 1) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _RulesTextBlock extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;
  final Color color;

  const _RulesTextBlock({
    required this.icon,
    required this.title,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: TariffsUi.softDecoration(
        color: color.withValues(alpha: 0.06),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 7),
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontFamily: 'Gilroy',
                  fontSize: 13,
                  height: 16 / 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            text,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontFamily: 'Gilroy',
              fontSize: 13,
              height: 17 / 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PackagingCard extends StatelessWidget {
  final List<UserPackagingType> types;

  const _PackagingCard({required this.types});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: TariffsUi.cardDecoration(),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          for (var i = 0; i < types.length; i++) ...[
            _ServicePriceRow(
              icon: Icons.inventory_2_rounded,
              title: types[i].name,
              price: '\$${_fmt(types[i].baseCost)}',
            ),
            if (i < types.length - 1) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _PhotoReportCard extends StatelessWidget {
  final List<UserPhotoCoefficient> coefficients;

  const _PhotoReportCard({required this.coefficients});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: TariffsUi.cardDecoration(),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          for (var i = 0; i < coefficients.length; i++) ...[
            _ServicePriceRow(
              icon: Icons.photo_camera_rounded,
              title: coefficients[i].rangeLabel,
              price: '×${coefficients[i].coefficient.toStringAsFixed(2)}',
              priceLabel: 'коэф.',
            ),
            if (i < coefficients.length - 1) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _ServicePriceRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String price;
  final String? priceLabel;

  const _ServicePriceRow({
    required this.icon,
    required this.title,
    required this.price,
    this.priceLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: TariffsUi.softDecoration(),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: context.brandPrimary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: context.brandPrimary, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontFamily: 'Gilroy',
                fontSize: 14,
                height: 18 / 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                price,
                style: TextStyle(
                  color: context.brandPrimary,
                  fontFamily: 'Gilroy',
                  fontSize: 16,
                  height: 1,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (priceLabel != null) ...[
                const SizedBox(height: 3),
                Text(
                  priceLabel!,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontFamily: 'Gilroy',
                    fontSize: 11,
                    height: 1,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _ValueRow extends StatelessWidget {
  final String label;
  final String value;

  const _ValueRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontFamily: 'Gilroy',
              fontSize: 13.5,
              height: 18 / 13.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          value,
          style: TextStyle(
            color: context.brandPrimary,
            fontFamily: 'Gilroy',
            fontSize: 13.5,
            height: 18 / 13.5,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _TariffInfoNote extends StatelessWidget {
  const _TariffInfoNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: TariffsUi.cardDecoration(
        color: context.brandPrimary.withValues(alpha: 0.06),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: context.brandPrimary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.info_outline_rounded,
              color: context.brandPrimary,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Итоговая стоимость может отличаться: менеджер учитывает фактический вес, упаковку и дополнительные услуги.',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontFamily: 'Gilroy',
                fontSize: 13,
                height: 17 / 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _fmt(double value) {
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value
      .toStringAsFixed(2)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}
