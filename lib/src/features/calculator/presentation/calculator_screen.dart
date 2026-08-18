import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/api_client.dart';
import '../../../core/ui/animated_hero_glow_backdrop.dart';
import '../../../core/ui/app_colors.dart';
import '../../../core/ui/app_input_decoration.dart';
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

final _coefsProvider = FutureProvider.autoDispose<List<_PhotoCoef>>((
  ref,
) async {
  final apiClient = ref.read(apiClientProvider);
  final response = await apiClient.get('/photo-report-coefficients');
  final data = response.data as Map<String, dynamic>;
  final list = data['coefficients'] as List? ?? [];
  return list
      .map((e) => _PhotoCoef.fromJson(e as Map<String, dynamic>))
      .where((c) => c.isActive)
      .toList();
});

final _packagingsProvider = FutureProvider.autoDispose<List<_Packaging>>((
  ref,
) async {
  final apiClient = ref.read(apiClientProvider);
  final response = await apiClient.get('/packagings');
  final d = response.data;
  final list = d is List ? d : (d['packagings'] ?? d['data'] ?? []);
  return (list as List)
      .map((e) => _Packaging.fromJson(e as Map<String, dynamic>))
      .where((p) => p.isActive)
      .toList();
});

final _unloadingQuoteProvider = FutureProvider.autoDispose
    .family<int, ({double volumeM3, String packagingTypeIds})>((
      ref,
      request,
    ) async {
      var disposed = false;
      ref.onDispose(() => disposed = true);
      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (disposed) throw StateError('quote request cancelled');

      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.post(
        '/client/unloading-quote',
        data: {
          'volumeM3': request.volumeM3,
          'packagingTypeIds': request.packagingTypeIds.isEmpty
              ? const <int>[]
              : request.packagingTypeIds.split(',').map(int.parse).toList(),
        },
      );
      final data = response.data as Map<String, dynamic>;
      final quote = data['data'] as Map<String, dynamic>;
      return (quote['clientCostUsd'] as num).ceil();
    });

// ─── Data models ─────────────────────────────────────────────────────────────

class _WeightTier {
  final double minWeight;
  final double maxWeight;
  final double pricePerKg;
  _WeightTier({
    required this.minWeight,
    required this.maxWeight,
    required this.pricePerKg,
  });

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

  _DensityTier({
    required this.minDensity,
    this.maxDensity,
    this.clientPricePerKg,
    this.clientPricePerM3,
  });

  bool get isVolumetric => clientPricePerM3 != null;

  factory _DensityTier.fromJson(Map<String, dynamic> j) => _DensityTier(
    minDensity: (j['minDensity'] as num?)?.toDouble() ?? 0,
    maxDensity: j['maxDensity'] != null
        ? (j['maxDensity'] as num).toDouble()
        : null,
    clientPricePerKg: j['clientPricePerKg'] != null
        ? (j['clientPricePerKg'] as num).toDouble()
        : null,
    clientPricePerM3: j['clientPricePerM3'] != null
        ? (j['clientPricePerM3'] as num).toDouble()
        : null,
  );
}

class _Tariff {
  final int id;
  final String name;
  final double baseCost;
  final String pricingType; // 'weight' или 'density'
  final List<_WeightTier> weightTiers;
  final List<_DensityTier> densityTiers;

  _Tariff({
    required this.id,
    required this.name,
    required this.baseCost,
    this.pricingType = 'weight',
    required this.weightTiers,
    this.densityTiers = const [],
  });

  bool get isDensity => pricingType == 'density';

  factory _Tariff.fromJson(Map<String, dynamic> j) => _Tariff(
    id: (j['id'] is int)
        ? j['id'] as int
        : int.tryParse(j['id'].toString()) ?? 0,
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
      if (weight >= tier.minWeight &&
          (tier.maxWeight == double.infinity || weight < tier.maxWeight)) {
        return tier.pricePerKg;
      }
    }
    return baseCost;
  }

  /// Расчёт для тарифа по плотности
  ({double price, double shipping, String unit}) calcDensity(
    double weight,
    double volume,
    double photoCoef,
  ) {
    if (volume <= 0 || weight <= 0) {
      return (
        price: baseCost,
        shipping: weight * baseCost * photoCoef,
        unit: 'кг',
      );
    }
    final density = weight / volume;
    final sorted = List<_DensityTier>.from(densityTiers)
      ..sort((a, b) => a.minDensity.compareTo(b.minDensity));
    for (int i = sorted.length - 1; i >= 0; i--) {
      final tier = sorted[i];
      if (density >= tier.minDensity &&
          (tier.maxDensity == null || density <= tier.maxDensity!)) {
        if (tier.isVolumetric) {
          final p = tier.clientPricePerM3 ?? 0;
          return (price: p, shipping: volume * p * photoCoef, unit: 'м³');
        } else {
          final p = tier.clientPricePerKg ?? baseCost;
          return (price: p, shipping: weight * p * photoCoef, unit: 'кг');
        }
      }
    }
    return (
      price: baseCost,
      shipping: weight * baseCost * photoCoef,
      unit: 'кг',
    );
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
  final String unitLabel;
  final String kind;
  final bool suitableForFragileGoods;

  _Packaging({
    required this.id,
    required this.name,
    required this.baseCost,
    required this.isActive,
    required this.unitLabel,
    required this.kind,
    required this.suitableForFragileGoods,
  });

  factory _Packaging.fromJson(Map<String, dynamic> j) => _Packaging(
    id: (j['id'] is int)
        ? j['id'] as int
        : int.tryParse(j['id'].toString()) ?? 0,
    name: (j['nameRu'] as String?) ?? (j['name'] as String?) ?? '',
    baseCost: (j['baseCost'] as num?)?.toDouble() ?? 0,
    isActive: (j['isActive'] as bool?) ?? true,
    unitLabel: (j['unitLabel'] as String?) ?? 'место',
    kind: (j['kind'] as String?) ?? 'primary',
    suitableForFragileGoods: (j['suitableForFragileGoods'] as bool?) ?? false,
  );

  bool get isPrimary => kind != 'addon';
  bool get isAddon => kind == 'addon';
}

// ─── Screen ──────────────────────────────────────────────────────────────────

class CalculatorScreen extends ConsumerStatefulWidget {
  const CalculatorScreen({super.key});

  @override
  ConsumerState<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorPageHeader extends StatelessWidget {
  const _CalculatorPageHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/');
              }
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: 46,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.black.withValues(alpha: 0.035),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 18,
                    spreadRadius: -12,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 18,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Text(
            'Калькулятор',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontFamily: 'Gilroy',
              fontSize: 26,
              height: 1.05,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.35,
            ),
          ),
        ),
      ],
    );
  }
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
  _Packaging? _selectedPrimaryPackaging;
  final Set<int> _selectedAddonPackagingIds = <int>{};

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

  _CalcResult? _calculate(
    List<_Tariff> tariffs,
    List<_PhotoCoef> coefs,
    List<_Packaging> packagings,
    int transshipment,
  ) {
    final tariff =
        _selectedTariff ?? (tariffs.isNotEmpty ? tariffs.first : null);
    if (tariff == null) return null;

    final weight = double.tryParse(_weightCtrl.text.replaceAll(',', '.')) ?? 0;
    final volume = double.tryParse(_volumeCtrl.text.replaceAll(',', '.')) ?? 0;
    final places = int.tryParse(_placesCtrl.text) ?? 0;
    final total = int.tryParse(_totalCtrl.text) ?? 0;
    final withPhoto = int.tryParse(_photoCtrl.text) ?? 0;
    if (weight <= 0 || volume <= 0 || places <= 0 || total <= 0) return null;

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
    final selectedAddonPackagings = packagings
        .where((p) => _selectedAddonPackagingIds.contains(p.id))
        .toList();
    final selectedPackagings = [
      if (_selectedPrimaryPackaging != null) _selectedPrimaryPackaging!,
      ...selectedAddonPackagings,
    ];
    // Упаковка = сумма базовых стоимостей выбранных упаковок × кол-во мест
    final packagingBaseCost = selectedPackagings.fold<double>(
      0,
      (sum, packaging) => sum + packaging.baseCost,
    );
    final packagingCost = packagingBaseCost * places;
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
      packagingNames: selectedPackagings.map((p) => p.name).toList(),
      packagingBaseCost: packagingBaseCost,
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
    final volumeM3 =
        double.tryParse(_volumeCtrl.text.replaceAll(',', '.')) ?? 0;
    final packagingTypeIds = <int>{
      if (_selectedPrimaryPackaging != null) _selectedPrimaryPackaging!.id,
      ..._selectedAddonPackagingIds,
    }.toList()..sort();
    final unloadingQuoteAsync = volumeM3 > 0
        ? ref.watch(
            _unloadingQuoteProvider((
              volumeM3: volumeM3,
              packagingTypeIds: packagingTypeIds.join(','),
            )),
          )
        : null;

    final topPad = AppLayout.topBarTotalHeight(context);
    final bottomPad = AppLayout.bottomScrollPadding(context);

    return TutorialScreenWrapper(
      screenKey: 'calculator',
      steps: [
        TutorialStep(
          icon: Icons.calculate_rounded,
          title: 'Калькулятор стоимости',
          description:
              'Рассчитайте примерную стоимость доставки заранее. Выберите тариф, введите вес и объём посылки.',
          targetKey: _calcFormKey,
        ),
        TutorialStep(
          icon: Icons.local_shipping_rounded,
          title: 'Выбор тарифа',
          description:
              'Тариф определяет цену за кг. Уточните у менеджера, какой тариф применяется к вашим товарам.',
          targetKey: _tariffKey,
        ),
        TutorialStep(
          icon: Icons.photo_camera_rounded,
          title: 'Надбавка за фотоотчёты',
          description:
              'Чем больше позиций сфотографировано — тем ниже итоговая стоимость. Коэффициент виден в строке «Фотоотчёт».',
          targetKey: _photoSurchargeKey,
        ),
        TutorialStep(
          icon: Icons.inventory_rounded,
          title: 'Упаковка',
          description:
              'Выберите тип упаковки, чтобы добавить её стоимость к расчёту. Упаковка оплачивается отдельно.',
          targetKey: _packagingKey,
        ),
        TutorialStep(
          icon: Icons.calculate_outlined,
          title: 'Кнопка «Рассчитать»',
          description:
              'После заполнения всех полей нажмите «Рассчитать» — внизу появится итоговая стоимость с разбивкой по статьям.',
          targetKey: _calcButtonKey,
        ),
      ],
      child: Stack(
        children: [
          ListView(
            controller: _scrollController,
            padding: EdgeInsets.fromLTRB(
              16,
              topPad * 0.7 + 16,
              16,
              bottomPad + 16,
            ),
            children: [
              // ── Header ──
              const _CalculatorPageHeader(),
              const SizedBox(height: 12),
              const _CalculatorHeroCard(),
              const SizedBox(height: 14),
              const _InfoCard(
                text:
                    'Расчёт носит информационный характер. Фактический вес, количество мест и плотность груза могут быть определены только непосредственно перед отправкой товара.',
              ),
              const SizedBox(height: 14),

              // ── Тариф ──
              tariffsAsync.when(
                loading: () => const _SectionCard(
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => _SectionCard(
                  child: Text(
                    'Не удалось загрузить тарифы: $e',
                    style: const TextStyle(
                      color: Colors.red,
                      fontFamily: 'Gilroy',
                      fontSize: 14,
                      height: 18 / 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                data: (tariffs) {
                  if (_selectedTariff == null && tariffs.isNotEmpty) {
                    _selectedTariff = tariffs.first;
                  }
                  if (tariffs.isEmpty) {
                    return const _SectionCard(
                      child: _MutedMessage('Тарифы не найдены'),
                    );
                  }
                  return KeyedSubtree(
                    key: _tariffKey,
                    child: _SectionCard(
                      child: _CalcDropdown<_Tariff>(
                        value: _selectedTariff ?? tariffs.first,
                        label: 'Тариф',
                        items: tariffs
                            .map(
                              (t) => _CalcDropdownItem(value: t, label: t.name),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => _selectedTariff = v),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 15),

              // ── Упаковка ──
              packagingsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.only(bottom: 15),
                  child: _SectionCard(
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
                error: (e, st) => const SizedBox.shrink(),
                data: (packagings) {
                  if (packagings.isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 15),
                    child: KeyedSubtree(
                      key: _packagingKey,
                      child: _PackagingPickerCard(
                        packagings: packagings,
                        selectedPrimaryPackaging: _selectedPrimaryPackaging,
                        selectedAddonPackagingIds: _selectedAddonPackagingIds,
                        onPrimaryChanged: (packaging) => setState(
                          () => _selectedPrimaryPackaging = packaging,
                        ),
                        onAddonToggled: (packaging) => setState(() {
                          if (_selectedAddonPackagingIds.contains(
                            packaging.id,
                          )) {
                            _selectedAddonPackagingIds.remove(packaging.id);
                          } else {
                            _selectedAddonPackagingIds.add(packaging.id);
                          }
                        }),
                      ),
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
                        const SizedBox(height: 10),
                        _NumField(
                          label: 'Объём, м³',
                          controller: _volumeCtrl,
                          hint: 'например 0.15',
                          decimal: true,
                          onChanged: (_) => setState(() {}),
                        ),
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
              const SizedBox(height: 15),

              // ── Результат ──
              tariffsAsync.maybeWhen(
                data: (tariffs) => coefsAsync.maybeWhen(
                  data: (coefs) {
                    if (volumeM3 > 0 &&
                        unloadingQuoteAsync?.isLoading == true) {
                      return const _SectionCard(
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (unloadingQuoteAsync?.hasError == true) {
                      return const _SectionCard(
                        child: _MutedMessage(
                          'Не удалось рассчитать разгрузку. Проверьте соединение и повторите попытку.',
                        ),
                      );
                    }
                    final result = _calculate(
                      tariffs,
                      coefs,
                      packagingsAsync.maybeWhen(
                        data: (packagings) => packagings,
                        orElse: () => const <_Packaging>[],
                      ),
                      unloadingQuoteAsync?.value ?? 0,
                    );
                    if (result == null) {
                      return _SectionCard(
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: context.brandPrimary.withValues(
                                  alpha: 0.10,
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(
                                Icons.edit_note_rounded,
                                color: context.brandPrimary,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Введите вес, количество мест и треков — расчёт появится автоматически',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontFamily: 'Gilroy',
                                  fontSize: 13.5,
                                  height: 1.25,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
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
          ScrollToTopButton(controller: _scrollController),
        ],
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
  final int transshipment;
  final double packagingCost;
  final List<String> packagingNames;
  final double packagingBaseCost;
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
    required this.packagingNames,
    required this.packagingBaseCost,
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
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [context.brandPrimary, context.brandSecondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: context.brandPrimary.withValues(alpha: 0.18),
                  blurRadius: 20,
                  spreadRadius: -12,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(17),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.22),
                    ),
                  ),
                  child: const Icon(
                    Icons.payments_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Итого к оплате',
                        style: TextStyle(
                          color: Color(0xE6FFFFFF),
                          fontFamily: 'Gilroy',
                          fontSize: 12.5,
                          height: 1,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '\$${result.total.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'Gilroy',
                          fontSize: 30,
                          height: 1,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const _Label('Расчёт стоимости'),
          const SizedBox(height: 10),
          _Row('Тариф', result.tariffName),
          _Row(
            'Цена за ${result.priceUnit}',
            '\$${result.pricePerKg.toStringAsFixed(2)}/${result.priceUnit}',
          ),
          _Row('Вес', '${result.weight.toStringAsFixed(2)} кг'),
          if (hasPhotoMarkup)
            _Row(
              'Надбавка за фотоотчёт',
              '×${result.photoCoef.toStringAsFixed(2)}',
              subtitle:
                  '${result.tracksWithPhoto} из ${result.tracksTotal} треков (${result.photoPercent.toStringAsFixed(0)}%)',
            ),
          const SizedBox(height: 4),
          const _Label('Статьи расходов'),
          const SizedBox(height: 10),
          _Row(
            'Доставка',
            '\$${result.shipping.toStringAsFixed(2)}',
            subtitle: result.priceUnit == 'м³'
                ? '${(result.shipping / (result.pricePerKg * result.photoCoef)).toStringAsFixed(3)} м³ × \$${result.pricePerKg.toStringAsFixed(2)}${hasPhotoMarkup ? ' × ${result.photoCoef.toStringAsFixed(2)}' : ''}'
                : '${result.weight.toStringAsFixed(2)} кг × \$${result.pricePerKg.toStringAsFixed(2)}${hasPhotoMarkup ? ' × ${result.photoCoef.toStringAsFixed(2)}' : ''}',
          ),
          _Row(
            'Разгрузка',
            '\$${result.transshipment}',
            subtitle: 'по объёму, минимум \$5',
          ),
          if (result.packagingCost > 0)
            _Row(
              'Упаковка',
              '\$${result.packagingCost.toStringAsFixed(2)}',
              subtitle:
                  '${result.packagingNames.join(', ')} · ${result.places} мест × \$${result.packagingBaseCost.toStringAsFixed(2)}',
            ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.18)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.info_outline_rounded,
                    size: 18,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Финальная стоимость уточняется после фактического взвешивания и проверки груза перед отправкой.',
                    style: TextStyle(
                      fontFamily: 'Gilroy',
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.orange[800],
                      height: 1.25,
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

class _CalculatorHeroCard extends StatelessWidget {
  const _CalculatorHeroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: context.brandGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: context.brandPrimary.withValues(alpha: 0.22),
            blurRadius: 28,
            spreadRadius: -12,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            const Positioned.fill(child: AnimatedHeroGlowBackdrop()),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.22),
                      ),
                    ),
                    child: const Icon(
                      Icons.calculate_rounded,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Предварительный расчёт',
                          style: TextStyle(
                            color: Colors.white,
                            fontFamily: 'Gilroy',
                            fontSize: 22,
                            height: 1.04,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.25,
                          ),
                        ),
                        SizedBox(height: 7),
                        Text(
                          'Введите параметры груза — сразу увидите доставку, разгрузку и упаковку.',
                          style: TextStyle(
                            color: Color(0xE6FFFFFF),
                            fontFamily: 'Gilroy',
                            fontSize: 13,
                            height: 1.2,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String text;

  const _InfoCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.045),
            blurRadius: 22,
            spreadRadius: -14,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: context.brandPrimary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              Icons.info_outline_rounded,
              size: 18,
              color: context.brandPrimary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontFamily: 'Gilroy',
                fontSize: 13,
                height: 17 / 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PackagingPickerCard extends StatelessWidget {
  final List<_Packaging> packagings;
  final _Packaging? selectedPrimaryPackaging;
  final Set<int> selectedAddonPackagingIds;
  final ValueChanged<_Packaging?> onPrimaryChanged;
  final ValueChanged<_Packaging> onAddonToggled;

  const _PackagingPickerCard({
    required this.packagings,
    required this.selectedPrimaryPackaging,
    required this.selectedAddonPackagingIds,
    required this.onPrimaryChanged,
    required this.onAddonToggled,
  });

  @override
  Widget build(BuildContext context) {
    final primaryPackagings = packagings.where((p) => p.isPrimary).toList();
    final addonPackagings = packagings.where((p) => p.isAddon).toList();

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Label('Упаковка'),
          const SizedBox(height: 5),
          const Text(
            'Выберите основную упаковку и при необходимости дополнительную защиту.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontFamily: 'Gilroy',
              fontSize: 12.5,
              height: 1.22,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          _PackagingGroupCard(
            title: 'Основная упаковка',
            subtitle: 'Выберите один вариант или оставьте расчёт без упаковки.',
            children: [
              _PackagingOptionTile(
                title: 'Без основной упаковки',
                subtitle: 'Не добавлять основную упаковку в расчёт',
                selected: selectedPrimaryPackaging == null,
                primary: true,
                badges: [
                  _PackagingBadgeData(
                    label: 'Без доп. затрат',
                    color: AppColors.textSecondary,
                  ),
                ],
                onTap: () => onPrimaryChanged(null),
              ),
              if (primaryPackagings.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Нет доступной основной упаковки',
                    style: TextStyle(
                      color: Colors.red,
                      fontFamily: 'Gilroy',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              else
                ...primaryPackagings.map(
                  (packaging) => Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: _PackagingOptionTile(
                      title: packaging.name,
                      subtitle: packaging.baseCost > 0
                          ? '\$${packaging.baseCost.toStringAsFixed(2)} / ${packaging.unitLabel}'
                          : 'Без доп. стоимости',
                      selected: selectedPrimaryPackaging?.id == packaging.id,
                      primary: true,
                      badges: [
                        _PackagingBadgeData(
                          label: 'Основная упаковка',
                          color: context.brandPrimary,
                        ),
                        if (packaging.suitableForFragileGoods)
                          _PackagingBadgeData(
                            label: 'Для хрупкого',
                            color: Colors.green.shade700,
                          ),
                      ],
                      onTap: () => onPrimaryChanged(packaging),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _PackagingGroupCard(
            title: 'Дополнительная защита',
            subtitle:
                'Можно выбрать несколько вариантов или оставить без доп. защиты.',
            backgroundColor: Colors.white,
            children: [
              if (addonPackagings.isEmpty)
                const Text(
                  'Дополнительная защита недоступна',
                  style: TextStyle(
                    color: Colors.black45,
                    fontFamily: 'Gilroy',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                )
              else
                ...addonPackagings.map(
                  (packaging) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _PackagingOptionTile(
                      title: packaging.name,
                      subtitle: packaging.baseCost > 0
                          ? '\$${packaging.baseCost.toStringAsFixed(2)} / ${packaging.unitLabel}'
                          : 'Без доп. стоимости',
                      selected: selectedAddonPackagingIds.contains(
                        packaging.id,
                      ),
                      primary: false,
                      badges: [
                        _PackagingBadgeData(
                          label: 'Доп. защита',
                          color: Colors.blue.shade700,
                        ),
                        if (packaging.suitableForFragileGoods)
                          _PackagingBadgeData(
                            label: 'Для хрупкого',
                            color: Colors.green.shade700,
                          ),
                      ],
                      onTap: () => onAddonToggled(packaging),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PackagingGroupCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> children;
  final Color? backgroundColor;

  const _PackagingGroupCard({
    required this.title,
    required this.subtitle,
    required this.children,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor ?? const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8EAEE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontFamily: 'Gilroy',
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontFamily: 'Gilroy',
              fontSize: 12,
              height: 1.22,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _PackagingOptionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool selected;
  final bool primary;
  final List<_PackagingBadgeData> badges;
  final VoidCallback onTap;

  const _PackagingOptionTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.primary,
    required this.badges,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected
                ? context.brandPrimary.withValues(alpha: 0.08)
                : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? context.brandPrimary : const Color(0xFFE8EAEE),
              width: selected ? 1.2 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                primary
                    ? (selected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked)
                    : (selected
                          ? Icons.check_box
                          : Icons.check_box_outline_blank),
                color: selected ? context.brandPrimary : Colors.black45,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontFamily: 'Gilroy',
                        fontSize: 14,
                        height: 1.15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: badges
                          .map(
                            (badge) => _CalcPackagingBadge(
                              label: badge.label,
                              color: badge.color,
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontFamily: 'Gilroy',
                        fontSize: 12,
                        height: 1.18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
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

class _PackagingBadgeData {
  final String label;
  final Color color;

  const _PackagingBadgeData({required this.label, required this.color});
}

class _CalcPackagingBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _CalcPackagingBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontFamily: 'Gilroy',
          fontSize: 11,
          height: 1,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _MutedMessage extends StatelessWidget {
  final String text;

  const _MutedMessage(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: AppColors.textSecondary,
        fontFamily: 'Gilroy',
        fontSize: 14,
        height: 18 / 14,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final Widget child;
  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withValues(alpha: 0.035)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 24,
            spreadRadius: -14,
            offset: const Offset(0, 14),
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
        color: AppColors.textPrimary,
        fontFamily: 'Gilroy',
        fontWeight: FontWeight.w900,
        fontSize: 18,
        height: 22 / 18,
        letterSpacing: -0.15,
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
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.025)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'Gilroy',
                    fontSize: 14,
                    height: 18 / 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontFamily: 'Gilroy',
                      fontSize: 11,
                      height: 14 / 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontFamily: 'Gilroy',
              fontSize: 14,
              height: 18 / 14,
              fontWeight: FontWeight.w900,
            ),
          ),
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
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontFamily: 'Gilroy',
            fontSize: 13,
            height: 16 / 13,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 7),
        AppOutlinedInputFrame(
          radius: 18,
          borderWidth: 1.2,
          focusedBorderWidth: 1.6,
          fillColor: const Color(0xFFF8FAFC),
          borderColor: const Color(0xFFE1E5ED),
          focusedBorderColor: context.brandPrimary,
          builder: (context, focusNode) {
            return TextFormField(
              controller: controller,
              focusNode: focusNode,
              onChanged: onChanged,
              keyboardType: decimal
                  ? const TextInputType.numberWithOptions(decimal: true)
                  : TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                  decimal ? RegExp(r'[\d.,]') : RegExp(r'\d'),
                ),
              ],
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(
                  color: Color(0xFFB0B4BE),
                  fontFamily: 'Gilroy',
                  fontSize: 14,
                  height: 16 / 14,
                  fontWeight: FontWeight.w600,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 13,
                ),
                isDense: true,
              ),
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontFamily: 'Gilroy',
                fontSize: 15,
                height: 18 / 15,
                fontWeight: FontWeight.w800,
              ),
            );
          },
        ),
      ],
    );
  }
}

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
    final renderBox =
        _targetKey.currentContext?.findRenderObject() as RenderBox?;
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
                    elevation: 10,
                    shadowColor: Colors.black.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
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
                                top: isFirst
                                    ? const Radius.circular(20)
                                    : Radius.zero,
                                bottom: isLast
                                    ? const Radius.circular(20)
                                    : Radius.zero,
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 13,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? context.brandPrimary.withValues(
                                          alpha: 0.1,
                                        )
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.vertical(
                                    top: isFirst
                                        ? const Radius.circular(20)
                                        : Radius.zero,
                                    bottom: isLast
                                        ? const Radius.circular(20)
                                        : Radius.zero,
                                  ),
                                ),
                                child: Text(
                                  item.label,
                                  style: TextStyle(
                                    fontFamily: 'Gilroy',
                                    fontSize: 14,
                                    height: 18 / 14,
                                    fontWeight: isSelected
                                        ? FontWeight.w800
                                        : FontWeight.w700,
                                    color: isSelected
                                        ? context.brandPrimary
                                        : AppColors.textPrimary,
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
    setState(() {});
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
        onTap: () {
          if (_overlayEntry == null) {
            _showMenu();
            return;
          }
          _hideMenu();
          setState(() {});
        },
        child: Container(
          key: _targetKey,
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE1E5ED), width: 1.2),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
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
                        color: AppColors.textSecondary,
                        fontFamily: 'Gilroy',
                        fontSize: 12,
                        height: 14 / 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      selectedLabel,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontFamily: 'Gilroy',
                        fontSize: 14,
                        height: 18 / 14,
                        fontWeight: FontWeight.w800,
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
                color: context.brandPrimary,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
