import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/app_colors.dart';
import '../../../core/ui/app_layout.dart';
import '../data/tariffs_provider.dart';

class TariffsScreen extends ConsumerWidget {
  const TariffsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tariffsAsync = ref.watch(userTariffsProvider);

    return tariffsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'Не удалось загрузить тарифы',
                style: TextStyle(color: Colors.grey[600], fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () => ref.invalidate(userTariffsProvider),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Повторить'),
              ),
            ],
          ),
        ),
      ),
      data: (data) {
        final topPad = AppLayout.topBarTotalHeight(context);
        final bottomPad = MediaQuery.paddingOf(context).bottom;
        final isEmpty = data.deliveryTariffs.isEmpty &&
            data.packagingTypes.isEmpty &&
            data.photoCoefficients.isEmpty;

        if (isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.price_change_outlined,
                      size: 56, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    'Тарифы не настроены',
                    style: TextStyle(color: Colors.grey[500], fontSize: 16),
                  ),
                ],
              ),
            ),
          );
        }

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16, topPad * 0.7 + 6, 16, 24 + bottomPad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Доставка ──────────────────────────────────────
              if (data.deliveryTariffs.isNotEmpty) ...[
                _SectionHeader(
                  icon: Icons.local_shipping_rounded,
                  title: 'Доставка',
                  color: context.brandPrimary,
                ),
                const SizedBox(height: 12),
                ...data.deliveryTariffs.map((t) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _DeliveryTariffCard(tariff: t),
                    )),
                const SizedBox(height: 8),
              ],

              // ── Упаковка ──────────────────────────────────────
              if (data.packagingTypes.isNotEmpty) ...[
                _SectionHeader(
                  icon: Icons.inventory_2_rounded,
                  title: 'Упаковка',
                  color: const Color(0xFF9C27B0),
                ),
                const SizedBox(height: 12),
                _PackagingCard(types: data.packagingTypes),
                const SizedBox(height: 20),
              ],

              // ── Фотоотчёт ─────────────────────────────────────
              if (data.photoCoefficients.isNotEmpty) ...[
                _SectionHeader(
                  icon: Icons.photo_camera_rounded,
                  title: 'Фотоотчёт',
                  color: const Color(0xFF2196F3),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    'Коэффициент умножается на стоимость фотоотчёта в зависимости от количества фотографий',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                ),
                _PhotoReportCard(coefficients: data.photoCoefficients),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Виджеты
// ─────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
      ],
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
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color(0x0F000000), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Text(
              tariff.name,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
          ),

          // Weight tiers table
          if (tariff.weightTiers.isNotEmpty) ...[
            const Divider(height: 1, indent: 16, endIndent: 16),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Вес (кг)',
                        style: TextStyle(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w500)),
                  ),
                  Text('Цена за кг',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            ...tariff.weightTiers.map((tier) => Padding(
                  padding: const EdgeInsets.fromLTRB(16, 5, 16, 5),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          tier.maxWeight != null
                              ? '${_fmt(tier.minWeight)} – ${_fmt(tier.maxWeight!)} кг'
                              : 'от ${_fmt(tier.minWeight)} кг',
                          style: const TextStyle(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.w500),
                        ),
                      ),
                      Text(
                        '\$${_fmt(tier.pricePerKg)}',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.brandPrimary),
                      ),
                    ],
                  ),
                )),
            const SizedBox(height: 6),
          ] else ...[
            // No tiers — show flat baseCost
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Row(
                children: [
                  Text('Стоимость: ', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                  Text(
                    '\$${_fmt(tariff.baseCost)} / кг',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.brandPrimary),
                  ),
                ],
              ),
            ),
          ],

          // Allowed items
          if (tariff.allowedItems != null && tariff.allowedItems!.isNotEmpty) ...[
            const Divider(height: 1, indent: 16, endIndent: 16),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.check_circle_outline, size: 14, color: Colors.green[600]),
                      const SizedBox(width: 4),
                      Text('Разрешено:',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.green[700])),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(tariff.allowedItems!, style: const TextStyle(fontSize: 13, color: Colors.black87)),
                ],
              ),
            ),
          ],

          // Prohibited items
          if (tariff.prohibitedItems != null && tariff.prohibitedItems!.isNotEmpty) ...[
            const Divider(height: 1, indent: 16, endIndent: 16),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.cancel_outlined, size: 14, color: Colors.red[600]),
                      const SizedBox(width: 4),
                      Text('Запрещено:',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.red[700])),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(tariff.prohibitedItems!, style: const TextStyle(fontSize: 13, color: Colors.black87)),
                ],
              ),
            ),
          ] else
            const SizedBox(height: 10),
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
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color(0x0F000000), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          for (var i = 0; i < types.length; i++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              child: Row(
                children: [
                  Expanded(
                    child: Text(types[i].name,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black87)),
                  ),
                  Text(
                    '\$${_fmt(types[i].baseCost)}',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF9C27B0)),
                  ),
                ],
              ),
            ),
            if (i < types.length - 1) const Divider(height: 1, indent: 16, endIndent: 16),
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
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color(0x0F000000), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text('Кол-во фото',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w500)),
                ),
                Text('Коэффициент',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          const Divider(height: 1),
          for (var i = 0; i < coefficients.length; i++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(coefficients[i].rangeLabel,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black87)),
                  ),
                  Text(
                    '×${coefficients[i].coefficient.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF2196F3)),
                  ),
                ],
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
