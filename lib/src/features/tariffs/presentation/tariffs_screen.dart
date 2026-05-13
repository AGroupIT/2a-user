import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/app_colors.dart';
import '../../../core/ui/app_layout.dart';
import '../../../core/ui/app_page_header.dart';
import '../../../core/ui/scroll_to_top_button.dart';
import '../../../core/ui/tutorial_card.dart';
import '../data/tariffs_provider.dart';

const _tariffsTextColor = Color(0xFF2F2F2F);
const _tariffsMutedTextColor = Color(0x992F2F2F);
const _tariffsDividerColor = Color(0x142F2F2F);

BoxDecoration _tariffsCardDecoration({Color color = Colors.white}) {
  return BoxDecoration(
    color: color,
    borderRadius: BorderRadius.circular(10),
    boxShadow: const [
      BoxShadow(color: Color(0x1A000000), offset: Offset(3, 4), blurRadius: 25),
    ],
  );
}

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

    return tariffsAsync.when(
      loading: () => buildFrame(
        children: const [
          AppPageHeader(title: 'Тарифы', showBack: true),
          SizedBox(height: 15),
          _TariffsStateCard(
            icon: Icons.price_change_rounded,
            title: 'Загружаем тарифы',
            message: 'Получаем актуальные тарифы доставки и услуг.',
            isLoading: true,
          ),
        ],
      ),
      error: (e, _) => buildFrame(
        children: [
          const AppPageHeader(title: 'Тарифы', showBack: true),
          const SizedBox(height: 15),
          _TariffsStateCard(
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
            children: const [
              AppPageHeader(title: 'Тарифы', showBack: true),
              SizedBox(height: 15),
              _TariffsStateCard(
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
              const AppPageHeader(title: 'Тарифы', showBack: true),
              const SizedBox(height: 15),
              if (data.deliveryTariffs.isNotEmpty) ...[
                KeyedSubtree(
                  key: _tariffsListKey,
                  child: const _SectionHeader(
                    icon: Icons.local_shipping_rounded,
                    title: 'Доставка',
                  ),
                ),
                const SizedBox(height: 10),
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
                    const SizedBox(height: 15),
                ],
                const SizedBox(height: 15),
              ],
              if (data.packagingTypes.isNotEmpty) ...[
                KeyedSubtree(
                  key: _packagingKey,
                  child: const _SectionHeader(
                    icon: Icons.inventory_2_rounded,
                    title: 'Упаковка',
                  ),
                ),
                const SizedBox(height: 10),
                _PackagingCard(types: data.packagingTypes),
                const SizedBox(height: 15),
              ],
              if (data.photoCoefficients.isNotEmpty) ...[
                const _SectionHeader(
                  icon: Icons.photo_camera_rounded,
                  title: 'Фотоотчёт',
                ),
                const SizedBox(height: 10),
                _TariffNote(
                  text:
                      'Коэффициент применяется к стоимости фотоотчёта в зависимости от количества фотографий.',
                ),
                const SizedBox(height: 10),
                _PhotoReportCard(coefficients: data.photoCoefficients),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _TariffsStateCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final bool isLoading;
  final bool isError;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _TariffsStateCard({
    required this.icon,
    required this.title,
    this.message,
    this.isLoading = false,
    this.isError = false,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final accent = isError ? const Color(0xFFE53935) : context.brandPrimary;
    return Container(
      decoration: _tariffsCardDecoration(),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: accent,
                      ),
                    )
                  : Icon(icon, color: accent, size: 22),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _tariffsTextColor,
                    fontFamily: 'Gilroy',
                    fontSize: 16,
                    height: 20 / 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (message != null && message!.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    message!,
                    style: const TextStyle(
                      color: _tariffsMutedTextColor,
                      fontFamily: 'Gilroy',
                      fontSize: 13,
                      height: 16 / 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: onAction,
                    icon: Icon(
                      Icons.refresh_rounded,
                      size: 18,
                      color: context.brandPrimary,
                    ),
                    label: Text(
                      actionLabel!,
                      style: TextStyle(
                        color: context.brandPrimary,
                        fontFamily: 'Gilroy',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: context.brandPrimary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: context.brandPrimary, size: 18),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            color: _tariffsTextColor,
            fontFamily: 'Gilroy',
            fontSize: 18,
            height: 22 / 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _TariffNote extends StatelessWidget {
  final String text;

  const _TariffNote({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _tariffsCardDecoration(
        color: context.brandPrimary.withValues(alpha: 0.06),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: context.brandPrimary,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: _tariffsTextColor,
                fontFamily: 'Gilroy',
                fontSize: 13,
                height: 16 / 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeliveryTariffCard extends StatelessWidget {
  final UserDeliveryTariff tariff;

  const _DeliveryTariffCard({required this.tariff});

  String _fmt(double v) =>
      v == v.truncateToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _tariffsCardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        tariff.name,
                        style: const TextStyle(
                          color: _tariffsTextColor,
                          fontFamily: 'Gilroy',
                          fontSize: 17,
                          height: 21 / 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _PricePill(text: '\$${_fmt(tariff.baseCost)} / кг'),
                  ],
                ),
                const SizedBox(height: 10),
                _ProductInfoPill(
                  requiresProductInfo: tariff.requiresProductInfo,
                ),
              ],
            ),
          ),
          if (tariff.weightTiers.isNotEmpty) ...[
            const Divider(height: 1, color: _tariffsDividerColor),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: _TableHeader(left: 'Вес (кг)', right: 'Цена за кг'),
            ),
            for (final tier in tariff.weightTiers)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 5, 16, 5),
                child: _ValueRow(
                  label: tier.maxWeight != null
                      ? '${_fmt(tier.minWeight)} – ${_fmt(tier.maxWeight!)} кг'
                      : 'от ${_fmt(tier.minWeight)} кг',
                  value: '\$${_fmt(tier.pricePerKg)}',
                ),
              ),
            const SizedBox(height: 10),
          ],
          if (tariff.allowedItems?.trim().isNotEmpty == true) ...[
            const Divider(height: 1, color: _tariffsDividerColor),
            _TextBlock(
              icon: Icons.check_circle_outline_rounded,
              title: 'Разрешено',
              text: tariff.allowedItems!.trim(),
              color: const Color(0xFF2EAD63),
            ),
          ],
          if (tariff.prohibitedItems?.trim().isNotEmpty == true) ...[
            const Divider(height: 1, color: _tariffsDividerColor),
            _TextBlock(
              icon: Icons.cancel_outlined,
              title: 'Запрещено',
              text: tariff.prohibitedItems!.trim(),
              color: const Color(0xFFE53935),
            ),
          ],
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

class _ProductInfoPill extends StatelessWidget {
  final bool requiresProductInfo;

  const _ProductInfoPill({required this.requiresProductInfo});

  @override
  Widget build(BuildContext context) {
    final color = requiresProductInfo
        ? context.brandPrimary
        : const Color(0xFF2EAD63);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            requiresProductInfo
                ? Icons.assignment_outlined
                : Icons.assignment_turned_in_outlined,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              requiresProductInfo ? 'Нужны данные о товаре' : 'Данные не нужны',
              style: TextStyle(
                color: color,
                fontFamily: 'Gilroy',
                fontSize: 12,
                height: 14 / 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PricePill extends StatelessWidget {
  final String text;

  const _PricePill({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: context.brandPrimary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: context.brandPrimary,
          fontFamily: 'Gilroy',
          fontSize: 13,
          height: 16 / 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  final String left;
  final String right;

  const _TableHeader({required this.left, required this.right});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            left,
            style: const TextStyle(
              color: _tariffsMutedTextColor,
              fontFamily: 'Gilroy',
              fontSize: 12,
              height: 14 / 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          right,
          style: const TextStyle(
            color: _tariffsMutedTextColor,
            fontFamily: 'Gilroy',
            fontSize: 12,
            height: 14 / 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
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
              color: _tariffsTextColor,
              fontFamily: 'Gilroy',
              fontSize: 14,
              height: 18 / 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          value,
          style: TextStyle(
            color: context.brandPrimary,
            fontFamily: 'Gilroy',
            fontSize: 14,
            height: 18 / 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _TextBlock extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;
  final Color color;

  const _TextBlock({
    required this.icon,
    required this.title,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontFamily: 'Gilroy',
                  fontSize: 13,
                  height: 16 / 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            text,
            style: const TextStyle(
              color: _tariffsTextColor,
              fontFamily: 'Gilroy',
              fontSize: 13,
              height: 17 / 13,
              fontWeight: FontWeight.w500,
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

  String _fmt(double v) =>
      v == v.truncateToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _tariffsCardDecoration(),
      child: Column(
        children: [
          for (var i = 0; i < types.length; i++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              child: _ValueRow(
                label: types[i].name,
                value: '\$${_fmt(types[i].baseCost)}',
              ),
            ),
            if (i < types.length - 1)
              const Divider(height: 1, indent: 16, endIndent: 16),
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
      decoration: _tariffsCardDecoration(),
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: _TableHeader(left: 'Кол-во фото', right: 'Коэффициент'),
          ),
          const Divider(height: 1, color: _tariffsDividerColor),
          for (var i = 0; i < coefficients.length; i++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: _ValueRow(
                label: coefficients[i].rangeLabel,
                value: '×${coefficients[i].coefficient.toStringAsFixed(2)}',
              ),
            ),
            if (i < coefficients.length - 1)
              const Divider(height: 1, indent: 16, endIndent: 16),
          ],
        ],
      ),
    );
  }
}
