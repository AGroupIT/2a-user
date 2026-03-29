import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/ui/app_colors.dart';
import '../../../core/ui/app_layout.dart';
import '../../../core/ui/scroll_to_top_button.dart';
import '../../../core/ui/tutorial_card.dart';
import '../../auth/data/auth_provider.dart';

// ─── Providers ───────────────────────────────────────────────────────────────

final _tariffsProvider = FutureProvider.autoDispose<List<_Tariff>>((ref) async {
  final apiClient = ref.read(apiClientProvider);
  final authState = ref.read(authProvider);
  final clientId = authState.clientId;

  final response = await apiClient.get(
    '/tariffs',
    queryParameters: {
      'activeOnly': 'true',
      if (clientId != null) 'clientId': clientId.toString(),
    },
  );

  final data = response.data as Map<String, dynamic>;
  final list = data['tariffs'] as List? ?? [];
  return list.map((e) => _Tariff.fromJson(e as Map<String, dynamic>)).toList();
});

final _coefsProvider = FutureProvider.autoDispose<List<_PhotoCoef>>((ref) async {
  final apiClient = ref.read(apiClientProvider);
  final response = await apiClient.get('/photo-report-coefficients');
  final data = response.data as Map<String, dynamic>;
  final list = data['coefficients'] as List? ?? [];
  return list
      .map((e) => _PhotoCoef.fromJson(e as Map<String, dynamic>))
      .where((c) => c.isActive)
      .toList();
});

final _packagingsProvider = FutureProvider.autoDispose<List<_Packaging>>((ref) async {
  final apiClient = ref.read(apiClientProvider);
  final response = await apiClient.get('/packagings');
  final d = response.data;
  final list = d is List ? d : (d['packagings'] ?? d['data'] ?? []);
  return (list as List)
      .map((e) => _Packaging.fromJson(e as Map<String, dynamic>))
      .where((p) => p.isActive)
      .toList();
});

// ─── Data models ─────────────────────────────────────────────────────────────

class _WeightTier {
  final double minWeight;
  final double maxWeight;
  final double pricePerKg;
  _WeightTier({required this.minWeight, required this.maxWeight, required this.pricePerKg});

  factory _WeightTier.fromJson(Map<String, dynamic> j) => _WeightTier(
        minWeight: (j['minWeight'] as num?)?.toDouble() ?? 0,
        maxWeight: (j['maxWeight'] as num?)?.toDouble() ?? double.infinity,
        pricePerKg: (j['pricePerKg'] as num?)?.toDouble() ?? 0,
      );
}

class _DensityTier {
  final double minDensity;
  final double? maxDensity;
  final double? clientPricePerKg;
  final double? clientPricePerM3;

  _DensityTier({required this.minDensity, this.maxDensity, this.clientPricePerKg, this.clientPricePerM3});

  bool get isVolumetric => clientPricePerM3 != null;

  factory _DensityTier.fromJson(Map<String, dynamic> j) => _DensityTier(
        minDensity: (j['minDensity'] as num?)?.toDouble() ?? 0,
        maxDensity: j['maxDensity'] != null ? (j['maxDensity'] as num).toDouble() : null,
        clientPricePerKg: j['clientPricePerKg'] != null ? (j['clientPricePerKg'] as num).toDouble() : null,
        clientPricePerM3: j['clientPricePerM3'] != null ? (j['clientPricePerM3'] as num).toDouble() : null,
      );
}

class _Tariff {
  final int id;
  final String name;
  final double baseCost;
  final String pricingType; // 'weight' или 'density'
  final List<_WeightTier> weightTiers;
  final List<_DensityTier> densityTiers;

  _Tariff({required this.id, required this.name, required this.baseCost, this.pricingType = 'weight', required this.weightTiers, this.densityTiers = const []});

  bool get isDensity => pricingType == 'density';

  factory _Tariff.fromJson(Map<String, dynamic> j) => _Tariff(
        id: (j['id'] is int) ? j['id'] as int : int.tryParse(j['id'].toString()) ?? 0,
        name: (j['name'] as String?) ?? '',
        baseCost: (j['baseCost'] as num?)?.toDouble() ?? 0,
        pricingType: (j['pricingType'] as String?) ?? 'weight',
        weightTiers: ((j['weightTiers'] as List?) ?? [])
            .map((t) => _WeightTier.fromJson(t as Map<String, dynamic>))
            .toList(),
        densityTiers: ((j['densityTiers'] as List?) ?? [])
            .map((t) => _DensityTier.fromJson(t as Map<String, dynamic>))
            .toList(),
      );

  double priceForWeight(double weight) {
    for (final tier in weightTiers) {
      if (weight >= tier.minWeight && (tier.maxWeight == double.infinity || weight < tier.maxWeight)) {
        return tier.pricePerKg;
      }
    }
    return baseCost;
  }

  /// Расчёт для тарифа по плотности
  ({double price, double shipping, String unit}) calcDensity(double weight, double volume, double photoCoef) {
    if (volume <= 0 || weight <= 0) return (price: baseCost, shipping: weight * baseCost * photoCoef, unit: 'кг');
    final density = weight / volume;
    final sorted = List<_DensityTier>.from(densityTiers)
      ..sort((a, b) => a.minDensity.compareTo(b.minDensity));
    for (int i = sorted.length - 1; i >= 0; i--) {
      final tier = sorted[i];
      if (density >= tier.minDensity && (tier.maxDensity == null || density <= tier.maxDensity!)) {
        if (tier.isVolumetric) {
          final p = tier.clientPricePerM3 ?? 0;
          return (price: p, shipping: volume * p * photoCoef, unit: 'м³');
        } else {
          final p = tier.clientPricePerKg ?? baseCost;
          return (price: p, shipping: weight * p * photoCoef, unit: 'кг');
        }
      }
    }
    return (price: baseCost, shipping: weight * baseCost * photoCoef, unit: 'кг');
  }
}

class _PhotoCoef {
  final double minPercent;
  final double maxPercent;
  final double coefficient;
  final bool isActive;

  _PhotoCoef({
    required this.minPercent,
    required this.maxPercent,
    required this.coefficient,
    required this.isActive,
  });

  factory _PhotoCoef.fromJson(Map<String, dynamic> j) => _PhotoCoef(
        minPercent: (j['minPercent'] as num?)?.toDouble() ?? 0,
        maxPercent: (j['maxPercent'] as num?)?.toDouble() ?? 100,
        coefficient: (j['coefficient'] as num?)?.toDouble() ?? 1.0,
        isActive: (j['isActive'] as bool?) ?? true,
      );
}

class _Packaging {
  final int id;
  final String name;
  final double baseCost;
  final bool isActive;

  _Packaging({required this.id, required this.name, required this.baseCost, required this.isActive});

  factory _Packaging.fromJson(Map<String, dynamic> j) => _Packaging(
        id: (j['id'] is int) ? j['id'] as int : int.tryParse(j['id'].toString()) ?? 0,
        name: (j['nameRu'] as String?) ?? (j['name'] as String?) ?? '',
        baseCost: (j['baseCost'] as num?)?.toDouble() ?? 0,
        isActive: (j['isActive'] as bool?) ?? true,
      );
}

// ─── Screen ──────────────────────────────────────────────────────────────────

class CalculatorScreen extends ConsumerStatefulWidget {
  const CalculatorScreen({super.key});

  @override
  ConsumerState<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends ConsumerState<CalculatorScreen> {
  final GlobalKey _calcFormKey = GlobalKey();
  final GlobalKey _tariffKey = GlobalKey();
  final GlobalKey _packagingKey = GlobalKey();
  final GlobalKey _calcButtonKey = GlobalKey();
  final GlobalKey _photoSurchargeKey = GlobalKey();

  final _scrollController = ScrollController();
  final _weightCtrl = TextEditingController();
  final _volumeCtrl = TextEditingController();
  final _placesCtrl = TextEditingController(text: '1');
  final _totalCtrl = TextEditingController(text: '1');
  final _photoCtrl = TextEditingController(text: '0');

  _Tariff? _selectedTariff;
  _Packaging? _selectedPackaging;

  @override
  void dispose() {
    _scrollController.dispose();
    _weightCtrl.dispose();
    _volumeCtrl.dispose();
    _placesCtrl.dispose();
    _totalCtrl.dispose();
    _photoCtrl.dispose();
    super.dispose();
  }

  // ── Calculation ────────────────────────────────────────────────────────────

  _CalcResult? _calculate(List<_Tariff> tariffs, List<_PhotoCoef> coefs) {
    final tariff = _selectedTariff ?? (tariffs.isNotEmpty ? tariffs.first : null);
    if (tariff == null) return null;

    final weight = double.tryParse(_weightCtrl.text.replaceAll(',', '.')) ?? 0;
    final volume = double.tryParse(_volumeCtrl.text.replaceAll(',', '.')) ?? 0;
    final places = int.tryParse(_placesCtrl.text) ?? 0;
    final total = int.tryParse(_totalCtrl.text) ?? 0;
    final withPhoto = int.tryParse(_photoCtrl.text) ?? 0;
    if (weight <= 0 || places <= 0 || total <= 0) return null;

    // Процент треков с фото
    final photoPercent = total > 0 ? (withPhoto / total * 100) : 0.0;
    double photoCoef = 1.0;
    for (final c in coefs) {
      if (photoPercent >= c.minPercent && photoPercent < c.maxPercent) {
        photoCoef = c.coefficient;
        break;
      }
      if (photoPercent >= 100 && c.maxPercent >= 100) {
        photoCoef = c.coefficient;
      }
    }

    double pricePerKg;
    double shipping;
    String priceUnit = 'кг';

    if (tariff.isDensity && volume > 0) {
      final result = tariff.calcDensity(weight, volume, photoCoef);
      pricePerKg = result.price;
      shipping = result.shipping;
      priceUnit = result.unit;
    } else {
      pricePerKg = tariff.priceForWeight(weight);
      shipping = weight * pricePerKg * photoCoef;
    }
    // Разгрузка = кол-во мест × $5
    final transshipment = places * 5.0;
    // Упаковка = базовая стоимость × кол-во мест
    final packagingCost = _selectedPackaging != null
        ? _selectedPackaging!.baseCost * places
        : 0.0;
    final totalCost = shipping + transshipment + packagingCost;

    return _CalcResult(
      tariffName: tariff.name,
      pricePerKg: pricePerKg,
      weight: weight,
      places: places,
      photoCoef: photoCoef,
      photoPercent: photoPercent,
      tracksTotal: total,
      tracksWithPhoto: withPhoto,
      shipping: shipping,
      transshipment: transshipment,
      packagingCost: packagingCost,
      packagingName: _selectedPackaging?.name,
      total: totalCost,
      priceUnit: priceUnit,
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final tariffsAsync = ref.watch(_tariffsProvider);
    final coefsAsync = ref.watch(_coefsProvider);
    final packagingsAsync = ref.watch(_packagingsProvider);

    final topPad = AppLayout.topBarTotalHeight(context);
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return TutorialScreenWrapper(
      screenKey: 'calculator',
      steps: [
        TutorialStep(
          icon: Icons.calculate_rounded,
          title: 'Калькулятор стоимости',
          description: 'Рассчитайте примерную стоимость доставки заранее. Выберите тариф, введите вес и объём посылки.',
          targetKey: _calcFormKey,
        ),
        TutorialStep(
          icon: Icons.local_shipping_rounded,
          title: 'Выбор тарифа',
          description: 'Тариф определяет цену за кг. Уточните у менеджера, какой тариф применяется к вашим товарам.',
          targetKey: _tariffKey,
        ),
        TutorialStep(
          icon: Icons.photo_camera_rounded,
          title: 'Надбавка за фотоотчёты',
          description: 'Чем больше позиций сфотографировано — тем ниже итоговая стоимость. Коэффициент виден в строке «Фотоотчёт».',
          targetKey: _photoSurchargeKey,
        ),
        TutorialStep(
          icon: Icons.inventory_rounded,
          title: 'Упаковка',
          description: 'Выберите тип упаковки, чтобы добавить её стоимость к расчёту. Упаковка оплачивается отдельно.',
          targetKey: _packagingKey,
        ),
        TutorialStep(
          icon: Icons.calculate_outlined,
          title: 'Кнопка «Рассчитать»',
          description: 'После заполнения всех полей нажмите «Рассчитать» — внизу появится итоговая стоимость с разбивкой по статьям.',
          targetKey: _calcButtonKey,
        ),
      ],
      child: Scaffold(
        backgroundColor: Colors.transparent,
      body: Stack(
        children: [
        SingleChildScrollView(
          controller: _scrollController,
          padding: EdgeInsets.fromLTRB(16, topPad * 0.7 + 6, 16, 32 + bottomPad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header ──
              const Text(
                'Калькулятор доставки',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Расчёт носит информационный характер. Фактический вес, количество мест и плотность груза могут быть определены только непосредственно перед отправкой товара.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textPrimary.withValues(alpha: 0.5),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),

              // ── Тариф ──
              tariffsAsync.when(
                loading: () => const _SectionCard(
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => _SectionCard(
                  child: Text('Не удалось загрузить тарифы: $e',
                      style: const TextStyle(color: Colors.red)),
                ),
                data: (tariffs) {
                  if (_selectedTariff == null && tariffs.isNotEmpty) {
                    _selectedTariff = tariffs.first;
                  }
                  if (tariffs.isEmpty) {
                    return const _SectionCard(child: Text('Тарифы не найдены'));
                  }
                  return KeyedSubtree(
                    key: _tariffKey,
                    child: _SectionCard(
                      child: _CalcDropdown<_Tariff>(
                        value: _selectedTariff ?? tariffs.first,
                        label: 'Тариф',
                        items: tariffs
                            .map((t) => _CalcDropdownItem(value: t, label: t.name))
                            .toList(),
                        onChanged: (v) => setState(() => _selectedTariff = v),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),

              // ── Упаковка ──
              packagingsAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (e, st) => const SizedBox.shrink(),
                data: (packagings) {
                  if (packagings.isEmpty) return const SizedBox.shrink();
                  return KeyedSubtree(
                    key: _packagingKey,
                    child: Column(
                    children: [
                      _SectionCard(
                        child: _CalcDropdown<_Packaging?>(
                          value: _selectedPackaging,
                          label: 'Упаковка',
                          items: [
                            const _CalcDropdownItem<_Packaging?>(
                              value: null,
                              label: 'Без упаковки',
                            ),
                            ...packagings.map((p) => _CalcDropdownItem<_Packaging?>(
                                  value: p,
                                  label: '${p.name}  (\$${p.baseCost.toStringAsFixed(2)}/мест)',
                                )),
                          ],
                          onChanged: (v) => setState(() => _selectedPackaging = v),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                  );
                },
              ),

              // ── Входные данные ──
              KeyedSubtree(
                key: _calcFormKey,
                child: KeyedSubtree(
                  key: _calcButtonKey,
                  child: _SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _Label('Параметры груза'),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _NumField(
                                label: 'Вес, кг',
                                controller: _weightCtrl,
                                hint: 'например 15.5',
                                decimal: true,
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _NumField(
                                label: 'Мест',
                                controller: _placesCtrl,
                                hint: '1',
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                          ],
                        ),
                        // Объём (для тарифов по плотности)
                        if (_selectedTariff?.isDensity == true) ...[
                          const SizedBox(height: 10),
                          _NumField(
                            label: 'Объём, м³',
                            controller: _volumeCtrl,
                            hint: 'например 0.15',
                            decimal: true,
                            onChanged: (_) => setState(() {}),
                          ),
                        ],
                        const SizedBox(height: 10),
                        KeyedSubtree(
                          key: _photoSurchargeKey,
                          child: Row(
                            children: [
                              Expanded(
                                child: _NumField(
                                  label: 'Треков всего',
                                  controller: _totalCtrl,
                                  hint: '1',
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _NumField(
                                  label: 'С фотоотчётом',
                                  controller: _photoCtrl,
                                  hint: '0',
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // ── Результат ──
              tariffsAsync.maybeWhen(
                data: (tariffs) => coefsAsync.maybeWhen(
                  data: (coefs) {
                    final result = _calculate(tariffs, coefs);
                    if (result == null) {
                      return _SectionCard(
                        child: Center(
                          child: Text(
                            'Введите вес, мест и количество треков',
                            style: TextStyle(
                              color: AppColors.textPrimary.withValues(alpha: 0.4),
                              fontSize: 14,
                            ),
                          ),
                        ),
                      );
                    }
                    return _ResultCard(result: result);
                  },
                  orElse: () => const SizedBox.shrink(),
                ),
                orElse: () => const SizedBox.shrink(),
              ),
            ],
          ),
        ),
        ScrollToTopButton(controller: _scrollController),
        ],
      ),
      ),
    );
  }
}

// ─── Result ───────────────────────────────────────────────────────────────────

class _CalcResult {
  final String tariffName;
  final double pricePerKg;
  final double weight;
  final int places;
  final double photoCoef;
  final double photoPercent;
  final int tracksTotal;
  final int tracksWithPhoto;
  final double shipping;
  final double transshipment;
  final double packagingCost;
  final String? packagingName;
  final double total;
  final String priceUnit;

  const _CalcResult({
    required this.tariffName,
    required this.pricePerKg,
    required this.weight,
    required this.places,
    required this.photoCoef,
    required this.photoPercent,
    required this.tracksTotal,
    required this.tracksWithPhoto,
    required this.shipping,
    required this.transshipment,
    required this.packagingCost,
    this.packagingName,
    required this.total,
    this.priceUnit = 'кг',
  });
}

class _ResultCard extends StatelessWidget {
  final _CalcResult result;
  const _ResultCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final hasPhotoMarkup = result.photoCoef > 1.0;
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Label('Расчёт стоимости'),
          const SizedBox(height: 12),

          // Тариф
          _Row('Тариф', result.tariffName),
          _Row('Цена за ${result.priceUnit}', '\$${result.pricePerKg.toStringAsFixed(2)}/${result.priceUnit}'),
          _Row('Вес', '${result.weight.toStringAsFixed(2)} кг'),

          // Фотоотчёт
          if (hasPhotoMarkup) ...[
            const Divider(height: 16),
            _Row(
              'Надбавка за фотоотчёт',
              '×${result.photoCoef.toStringAsFixed(2)}',
              subtitle:
                  '${result.tracksWithPhoto} из ${result.tracksTotal} треков (${result.photoPercent.toStringAsFixed(0)}%)',
            ),
          ],

          const Divider(height: 16),

          // Стоимости
          _Row(
            'Доставка',
            '\$${result.shipping.toStringAsFixed(2)}',
            subtitle:
                '${result.priceUnit == 'м³' ? '${(result.shipping / (result.pricePerKg * result.photoCoef)).toStringAsFixed(3)} м³' : '${result.weight.toStringAsFixed(2)} кг'} × \$${result.pricePerKg.toStringAsFixed(2)}${hasPhotoMarkup ? ' × ${result.photoCoef.toStringAsFixed(2)}' : ''}',
          ),
          const SizedBox(height: 6),
          _Row(
            'Разгрузка',
            '\$${result.transshipment.toStringAsFixed(2)}',
            subtitle: '${result.places} мест × \$5',
          ),
          if (result.packagingCost > 0) ...[
            const SizedBox(height: 6),
            _Row(
              'Упаковка${result.packagingName != null ? ' (${result.packagingName})' : ''}',
              '\$${result.packagingCost.toStringAsFixed(2)}',
              subtitle: '${result.places} мест × \$${(result.packagingCost / result.places).toStringAsFixed(2)}',
            ),
          ],

          const Divider(height: 16),

          // Итого
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Итого',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                '\$${result.total.toStringAsFixed(2)}',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                  color: context.brandSecondary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Disclaimer
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.25)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded,
                    size: 16, color: Colors.orange),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Расчёт носит информационный характер. Фактический вес, количество мест и плотность груза могут быть определены только непосредственно перед отправкой товара.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange[800],
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── UI helpers ───────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final Widget child;
  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 15,
        color: AppColors.textPrimary,
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final String? subtitle;
  const _Row(this.label, this.value, {this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimary.withValues(alpha: 0.7),
                    )),
                if (subtitle != null)
                  Text(subtitle!,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textPrimary.withValues(alpha: 0.45),
                      )),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              )),
        ],
      ),
    );
  }
}

class _NumField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final bool decimal;
  final ValueChanged<String> onChanged;

  const _NumField({
    required this.label,
    required this.controller,
    required this.hint,
    required this.onChanged,
    this.decimal = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary.withValues(alpha: 0.7),
            )),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          onChanged: onChanged,
          keyboardType: decimal
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.allow(
                decimal ? RegExp(r'[\d.,]') : RegExp(r'\d')),
          ],
          decoration: _inputDecoration(hint),
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

InputDecoration _inputDecoration(String hint) => InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: AppColors.textPrimary.withValues(alpha: 0.3)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.brandOrange, width: 1.5),
      ),
      filled: true,
      fillColor: Colors.grey.shade50,
    );

// ─── Dropdown (same style as status filter on tracks screen) ─────────────────

class _CalcDropdownItem<T> {
  final T value;
  final String label;
  const _CalcDropdownItem({required this.value, required this.label});
}

class _CalcDropdown<T> extends StatefulWidget {
  final T value;
  final String label;
  final List<_CalcDropdownItem<T>> items;
  final ValueChanged<T?> onChanged;

  const _CalcDropdown({
    required this.value,
    required this.label,
    required this.items,
    required this.onChanged,
  });

  @override
  State<_CalcDropdown<T>> createState() => _CalcDropdownState<T>();
}

class _CalcDropdownState<T> extends State<_CalcDropdown<T>> {
  late T _selectedValue;
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();
  final GlobalKey _targetKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _selectedValue = widget.value;
  }

  @override
  void didUpdateWidget(_CalcDropdown<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _selectedValue = widget.value;
    }
  }

  void _showMenu() {
    final renderBox = _targetKey.currentContext?.findRenderObject() as RenderBox?;
    final menuWidth = renderBox?.size.width ?? 200.0;

    _overlayEntry = OverlayEntry(
      builder: (ctx) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _hideMenu,
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              child: CompositedTransformFollower(
                link: _layerLink,
                showWhenUnlinked: false,
                offset: const Offset(0, 54),
                child: GestureDetector(
                  onTap: () {},
                  child: Material(
                    elevation: 8,
                    borderRadius: BorderRadius.circular(14),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        width: menuWidth,
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.of(ctx).size.height * 0.4,
                        ),
                        color: Colors.white,
                        child: ListView(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          physics: const ClampingScrollPhysics(),
                          children: widget.items.asMap().entries.map((entry) {
                            final index = entry.key;
                            final item = entry.value;
                            final isFirst = index == 0;
                            final isLast = index == widget.items.length - 1;
                            final isSelected = _selectedValue == item.value;

                            return InkWell(
                              onTap: () {
                                setState(() => _selectedValue = item.value);
                                widget.onChanged(item.value);
                                _hideMenu();
                              },
                              borderRadius: BorderRadius.vertical(
                                top: isFirst ? const Radius.circular(14) : Radius.zero,
                                bottom: isLast ? const Radius.circular(14) : Radius.zero,
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.brandOrange.withValues(alpha: 0.1)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.vertical(
                                    top: isFirst ? const Radius.circular(14) : Radius.zero,
                                    bottom: isLast ? const Radius.circular(14) : Radius.zero,
                                  ),
                                ),
                                child: Text(
                                  item.label,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                    color: isSelected ? AppColors.brandOrange : Colors.black87,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideMenu() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  void dispose() {
    _hideMenu();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedLabel = widget.items
        .firstWhere(
          (item) => item.value == _selectedValue,
          orElse: () => _CalcDropdownItem(value: _selectedValue, label: '—'),
        )
        .label;

    return CompositedTransformTarget(
      link: _layerLink,
      child: GestureDetector(
        onTap: () => _overlayEntry == null ? _showMenu() : _hideMenu(),
        child: Container(
          key: _targetKey,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade300),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.label,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF999999),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      selectedLabel,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
              Icon(
                _overlayEntry != null
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                color: AppColors.brandOrange,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
