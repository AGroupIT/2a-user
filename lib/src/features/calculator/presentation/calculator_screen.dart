import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/api_client.dart';
import '../../../core/ui/animated_hero_glow_backdrop.dart';
import '../../../core/ui/app_colors.dart';
import '../../../core/ui/app_input_decoration.dart';
import '../../../core/ui/app_layout.dart';
import '../../../core/ui/blurred_modal_bottom_sheet.dart';
import '../../../core/ui/scroll_to_top_button.dart';
import '../../../core/ui/tutorial_card.dart';
import '../../auth/data/auth_provider.dart';
import '../domain/assembly_cost_calculation.dart';

// ─── Providers ───────────────────────────────────────────────────────────────

final _tariffsProvider = FutureProvider.autoDispose<List<CalculatorTariff>>((
  ref,
) async {
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
  return list
      .map((e) => CalculatorTariff.fromJson(e as Map<String, dynamic>))
      .toList();
});

final _coefsProvider =
    FutureProvider.autoDispose<List<CalculatorPhotoCoefficient>>((ref) async {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.get('/photo-report-coefficients');
      final data = response.data as Map<String, dynamic>;
      final list = data['coefficients'] as List? ?? [];
      return list
          .map(
            (e) =>
                CalculatorPhotoCoefficient.fromJson(e as Map<String, dynamic>),
          )
          .where((c) => c.isActive)
          .toList();
    });

final _packagingsProvider =
    FutureProvider.autoDispose<List<CalculatorPackaging>>((ref) async {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.get('/packagings');
      final d = response.data;
      final list = d is List ? d : (d['packagings'] ?? d['data'] ?? []);
      return (list as List)
          .map((e) => CalculatorPackaging.fromJson(e as Map<String, dynamic>))
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
  final _insuranceAmountCtrl = TextEditingController();

  CalculatorTariff? _selectedTariff;
  CalculatorPackaging? _selectedPrimaryPackaging;
  final Set<int> _selectedAddonPackagingIds = <int>{};
  PackagingRemovalOption _packagingRemoval = PackagingRemovalOption.none;
  AssemblyPlacePreference _placePreference =
      AssemblyPlacePreference.singleIfPossible;
  bool _hasFragileGoods = false;
  bool _hasInsurance = false;

  @override
  void dispose() {
    _scrollController.dispose();
    _weightCtrl.dispose();
    _volumeCtrl.dispose();
    _placesCtrl.dispose();
    _totalCtrl.dispose();
    _photoCtrl.dispose();
    _insuranceAmountCtrl.dispose();
    super.dispose();
  }

  // ── Calculation ────────────────────────────────────────────────────────────

  _CalcResult? _calculate(
    List<CalculatorTariff> tariffs,
    List<CalculatorPhotoCoefficient> coefs,
    List<CalculatorPackaging> packagings,
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
    final insuranceAmount =
        double.tryParse(_insuranceAmountCtrl.text.replaceAll(',', '.')) ?? 0;
    final selectedAddonPackagings = packagings
        .where((p) => _selectedAddonPackagingIds.contains(p.id))
        .toList();
    final selectedPackagings = [
      if (_selectedPrimaryPackaging != null) _selectedPrimaryPackaging!,
      ...selectedAddonPackagings,
    ];
    final calculation = calculateAssemblyCost(
      AssemblyCostInput(
        tariff: tariff,
        photoCoefficients: coefs,
        selectedPackagings: selectedPackagings,
        weightKg: weight,
        volumeM3: volume,
        places: places,
        tracksTotal: total,
        tracksWithPhoto: withPhoto,
        unloadingCostUsd: transshipment.toDouble(),
        packagingRemoval: _packagingRemoval,
        hasInsurance: _hasInsurance,
        insuranceAmountCny: insuranceAmount,
        hasFragileGoods: _hasFragileGoods,
        placePreference: _placePreference,
      ),
    );
    if (calculation == null) return null;

    return _CalcResult(
      tariffName: tariff.name,
      pricePerKg: calculation.clientPrice,
      weight: weight,
      volume: volume,
      places: places,
      photoCoef: calculation.photoCoefficient,
      photoPercent: calculation.photoPercent,
      tracksTotal: total,
      tracksWithPhoto: withPhoto,
      shipping: calculation.shippingCost,
      transshipment: transshipment,
      packagingCost: calculation.packagingCost,
      packagingNames: selectedPackagings.map((p) => p.name).toList(),
      packagingBaseCost: calculation.packagingBaseCost,
      packagingTariffSurcharge: calculation.packagingTariffSurcharge,
      insuranceAmountCny: insuranceAmount,
      insuranceBaseUsd: calculation.insuranceBaseUsd,
      insuranceCost: calculation.insuranceCost,
      hasInsurance: _hasInsurance,
      hasFragileGoods: _hasFragileGoods,
      placePreference: _placePreference,
      packagingRemoval: _packagingRemoval,
      removalPriceApplied: calculation.removalPriceApplied,
      total: calculation.total,
      priceUnit: calculation.priceUnit,
    );
  }

  Future<void> _showTariffSheet(List<CalculatorTariff> tariffs) async {
    final selectedId = await showBlurredModalBottomSheet<int>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _TariffSelectionSheet(
        options: tariffs,
        selectedId: _selectedTariff?.id,
      ),
    );
    if (!mounted || selectedId == null) return;
    final selected = tariffs.firstWhere((tariff) => tariff.id == selectedId);
    setState(() {
      _selectedTariff = selected;
      _packagingRemoval = PackagingRemovalOption.none;
    });
  }

  Widget _buildTariffSection(AsyncValue<List<CalculatorTariff>> tariffsAsync) {
    return KeyedSubtree(
      key: _tariffKey,
      child: tariffsAsync.when(
        loading: () => const _CalculatorStateCard(
          step: 1,
          icon: Icons.local_shipping_rounded,
          title: 'Тариф доставки',
          message: 'Загружаем доступные тарифы.',
          isLoading: true,
        ),
        error: (_, _) => _CalculatorStateCard(
          step: 1,
          icon: Icons.local_shipping_rounded,
          title: 'Тариф доставки',
          message: 'Не удалось загрузить тарифы. Проверьте соединение.',
          onRetry: () => ref.invalidate(_tariffsProvider),
        ),
        data: (tariffs) {
          if (_selectedTariff == null && tariffs.isNotEmpty) {
            _selectedTariff = tariffs.first;
          }
          if (tariffs.isEmpty) {
            return const _CalculatorStateCard(
              step: 1,
              icon: Icons.local_shipping_rounded,
              title: 'Тариф доставки',
              message: 'Для вашего кабинета пока нет доступных тарифов.',
            );
          }
          final selectedTariff = _selectedTariff ?? tariffs.first;
          return _SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _CalculatorStepHeader(
                  step: 1,
                  icon: Icons.local_shipping_rounded,
                  title: 'Тариф доставки',
                  subtitle: 'Выберите способ расчёта стоимости перевозки.',
                ),
                const SizedBox(height: 14),
                _PackagingSummaryTile(
                  title: 'Выбранный тариф',
                  value: selectedTariff.name,
                  detail: _tariffPricingDescription(selectedTariff),
                  icon: Icons.local_shipping_outlined,
                  isSelected: true,
                  onTap: () => _showTariffSheet(tariffs),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCargoSection() {
    return KeyedSubtree(
      key: _calcFormKey,
      child: _SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _CalculatorStepHeader(
              step: 2,
              icon: Icons.inventory_2_rounded,
              title: 'Параметры груза',
              subtitle: 'Укажите ожидаемые данные будущей сборки.',
            ),
            const SizedBox(height: 14),
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
    );
  }

  Widget _buildAssemblySection() {
    final tariff = _selectedTariff;
    if (tariff == null) return const SizedBox.shrink();
    return _AssemblyOptionsCard(
      tariff: tariff,
      packagingRemoval: _packagingRemoval,
      placePreference: _placePreference,
      hasFragileGoods: _hasFragileGoods,
      hasInsurance: _hasInsurance,
      insuranceAmountController: _insuranceAmountCtrl,
      onPackagingRemovalChanged: (value) =>
          setState(() => _packagingRemoval = value),
      onPlacePreferenceChanged: (value) =>
          setState(() => _placePreference = value),
      onFragileGoodsChanged: (value) =>
          setState(() => _hasFragileGoods = value),
      onInsuranceChanged: (value) => setState(() => _hasInsurance = value),
      onInsuranceAmountChanged: (_) => setState(() {}),
    );
  }

  Widget _buildPackagingSection(
    AsyncValue<List<CalculatorPackaging>> packagingsAsync,
  ) {
    return KeyedSubtree(
      key: _packagingKey,
      child: packagingsAsync.when(
        loading: () => const _CalculatorStateCard(
          step: 4,
          icon: Icons.inventory_rounded,
          title: 'Упаковка',
          message: 'Загружаем варианты упаковки.',
          isLoading: true,
        ),
        error: (_, _) => _CalculatorStateCard(
          step: 4,
          icon: Icons.inventory_rounded,
          title: 'Упаковка',
          message: 'Не удалось загрузить варианты упаковки.',
          onRetry: () => ref.invalidate(_packagingsProvider),
        ),
        data: (packagings) {
          final primaryPackagings = packagings
              .where((packaging) => packaging.isPrimary)
              .toList();
          if (_selectedPrimaryPackaging == null &&
              primaryPackagings.isNotEmpty) {
            _selectedPrimaryPackaging = primaryPackagings.first;
          }
          return _PackagingPickerCard(
            packagings: packagings,
            selectedPrimaryPackaging: _selectedPrimaryPackaging,
            selectedAddonPackagingIds: _selectedAddonPackagingIds,
            hasFragileGoods: _hasFragileGoods,
            onPrimaryChanged: (packaging) =>
                setState(() => _selectedPrimaryPackaging = packaging),
            onAddonSelectionChanged: (ids) => setState(() {
              _selectedAddonPackagingIds
                ..clear()
                ..addAll(ids);
            }),
          );
        },
      ),
    );
  }

  Widget _buildResultSection({
    required AsyncValue<List<CalculatorTariff>> tariffsAsync,
    required AsyncValue<List<CalculatorPhotoCoefficient>> coefsAsync,
    required AsyncValue<List<CalculatorPackaging>> packagingsAsync,
    required AsyncValue<int>? unloadingQuoteAsync,
    required double volumeM3,
    required String packagingTypeIds,
  }) {
    Widget result;
    if (tariffsAsync.isLoading || coefsAsync.isLoading) {
      result = const _CalculationPendingCard(
        title: 'Подготавливаем расчёт',
        message: 'Получаем тарифы и коэффициенты.',
        isLoading: true,
      );
    } else if (tariffsAsync.hasError || coefsAsync.hasError) {
      result = _CalculationPendingCard(
        title: 'Расчёт пока недоступен',
        message: 'Не удалось получить данные для расчёта.',
        onRetry: () {
          ref.invalidate(_tariffsProvider);
          ref.invalidate(_coefsProvider);
        },
      );
    } else if (volumeM3 > 0 && unloadingQuoteAsync?.isLoading == true) {
      result = const _CalculationPendingCard(
        title: 'Считаем разгрузку',
        message: 'Получаем стоимость по объёму и выбранной упаковке.',
        isLoading: true,
      );
    } else if (unloadingQuoteAsync?.hasError == true) {
      result = _CalculationPendingCard(
        title: 'Не удалось рассчитать разгрузку',
        message: 'Проверьте соединение и повторите попытку.',
        onRetry: () => ref.invalidate(
          _unloadingQuoteProvider((
            volumeM3: volumeM3,
            packagingTypeIds: packagingTypeIds,
          )),
        ),
      );
    } else {
      final tariffs = tariffsAsync.value ?? const <CalculatorTariff>[];
      final coefficients =
          coefsAsync.value ?? const <CalculatorPhotoCoefficient>[];
      final packagings = packagingsAsync.value ?? const <CalculatorPackaging>[];
      final calculation = _calculate(
        tariffs,
        coefficients,
        packagings,
        unloadingQuoteAsync?.value ?? 0,
      );
      result = calculation == null
          ? const _CalculationPendingCard(
              title: 'Заполните параметры',
              message:
                  'Нужны тариф, основная упаковка, вес, объём и количество треков. Фотоотчётов не может быть больше, чем треков.',
            )
          : _ResultCard(result: calculation);
    }

    return KeyedSubtree(
      key: _calcButtonKey,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: KeyedSubtree(key: ValueKey(result.runtimeType), child: result),
      ),
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
    final packagingTypeIdsValue = packagingTypeIds.join(',');
    final unloadingQuoteAsync = volumeM3 > 0
        ? ref.watch(
            _unloadingQuoteProvider((
              volumeM3: volumeM3,
              packagingTypeIds: packagingTypeIdsValue,
            )),
          )
        : null;

    final topPad = AppLayout.topBarTotalHeight(context);
    final bottomPad = AppLayout.bottomScrollPadding(context);
    final tariffSection = _buildTariffSection(tariffsAsync);
    final cargoSection = _buildCargoSection();
    final assemblySection = _buildAssemblySection();
    final packagingSection = _buildPackagingSection(packagingsAsync);
    final resultSection = _buildResultSection(
      tariffsAsync: tariffsAsync,
      coefsAsync: coefsAsync,
      packagingsAsync: packagingsAsync,
      unloadingQuoteAsync: unloadingQuoteAsync,
      volumeM3: volumeM3,
      packagingTypeIds: packagingTypeIdsValue,
    );

    final hasAssemblyOptions = _selectedTariff != null;

    Widget formColumn() => Column(
      children: [
        tariffSection,
        const SizedBox(height: 15),
        cargoSection,
        if (hasAssemblyOptions) ...[
          const SizedBox(height: 15),
          assemblySection,
        ],
        const SizedBox(height: 15),
        packagingSection,
      ],
    );

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
              'Если фотоотчёт платный по выбранному тарифу, его коэффициент будет учтён автоматически.',
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
          title: 'Автоматический расчёт',
          description:
              'После заполнения всех полей появится итоговая стоимость с разбивкой по статьям.',
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
              const _CalculatorPageHeader(),
              const SizedBox(height: 12),
              const _CalculatorHeroCard(),
              const SizedBox(height: 14),
              const _InfoCard(
                text:
                    'Расчёт предварительный: для упаковки предполагается по одной единице каждого выбранного материала на место. Финальная сумма зависит от фактического веса, объёма и расхода упаковки.',
              ),
              const SizedBox(height: 15),
              LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 900) {
                    return Column(
                      children: [
                        formColumn(),
                        const SizedBox(height: 15),
                        resultSection,
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 11, child: formColumn()),
                      const SizedBox(width: 16),
                      Expanded(flex: 9, child: resultSection),
                    ],
                  );
                },
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
  final double volume;
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
  final double packagingTariffSurcharge;
  final double insuranceAmountCny;
  final double insuranceBaseUsd;
  final double insuranceCost;
  final bool hasInsurance;
  final bool hasFragileGoods;
  final AssemblyPlacePreference placePreference;
  final PackagingRemovalOption packagingRemoval;
  final bool removalPriceApplied;
  final double total;
  final String priceUnit;

  const _CalcResult({
    required this.tariffName,
    required this.pricePerKg,
    required this.weight,
    required this.volume,
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
    required this.packagingTariffSurcharge,
    required this.insuranceAmountCny,
    required this.insuranceBaseUsd,
    required this.insuranceCost,
    required this.hasInsurance,
    required this.hasFragileGoods,
    required this.placePreference,
    required this.packagingRemoval,
    required this.removalPriceApplied,
    required this.total,
    this.priceUnit = 'кг',
  });
}

class _ResultCard extends StatelessWidget {
  final _CalcResult result;
  const _ResultCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final hasPhotoMarkup = (result.photoCoef - 1).abs() > 0.001;
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
            subtitle: result.removalPriceApplied
                ? 'применена ставка за снятие упаковки'
                : result.packagingTariffSurcharge > 0
                ? 'включая наценку за упаковку \$${result.packagingTariffSurcharge.toStringAsFixed(2)}'
                : null,
          ),
          _Row('Вес', '${result.weight.toStringAsFixed(2)} кг'),
          if (result.packagingRemoval != PackagingRemovalOption.none)
            _Row(
              'Снятие упаковки',
              result.packagingRemoval == PackagingRemovalOption.all
                  ? 'Снять всю'
                  : 'Только транспортировочную',
              subtitle: result.removalPriceApplied
                  ? 'применена специальная ставка тарифа'
                  : 'специальная ставка не задана — расчёт по обычному тарифу',
            ),
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
                ? '${result.volume.toStringAsFixed(3)} м³ × \$${result.pricePerKg.toStringAsFixed(2)}${hasPhotoMarkup ? ' × ${result.photoCoef.toStringAsFixed(2)}' : ''}'
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
          if (result.hasInsurance)
            _Row(
              'Страховка',
              '\$${result.insuranceCost.toStringAsFixed(2)}',
              subtitle:
                  '${result.insuranceAmountCny.toStringAsFixed(2)} CNY = \$${result.insuranceBaseUsd.toStringAsFixed(2)} × ${defaultClientInsurancePercent.toStringAsFixed(1)}%',
            ),
          _Row(
            'Пожелание по местам',
            result.placePreference == AssemblyPlacePreference.singleIfPossible
                ? 'По возможности 1 место'
                : 'Можно разделить',
          ),
          if (result.hasFragileGoods)
            const _Row(
              'Хрупкий груз',
              'Да',
              subtitle: 'учтено как требование к выбору упаковки',
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

class _CalculatorStepHeader extends StatelessWidget {
  final int step;
  final IconData icon;
  final String title;
  final String subtitle;

  const _CalculatorStepHeader({
    required this.step,
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
            borderRadius: BorderRadius.circular(15),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Center(child: Icon(icon, color: context.brandPrimary, size: 21)),
              Positioned(
                right: -4,
                top: -5,
                child: Container(
                  width: 18,
                  height: 18,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: context.brandPrimary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Text(
                    '$step',
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'Gilroy',
                      fontSize: 9,
                      height: 1,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontFamily: 'Gilroy',
                  fontSize: 17,
                  height: 1.05,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontFamily: 'Gilroy',
                  fontSize: 12,
                  height: 1.2,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CalculatorStateCard extends StatelessWidget {
  final int step;
  final IconData icon;
  final String title;
  final String message;
  final bool isLoading;
  final VoidCallback? onRetry;

  const _CalculatorStateCard({
    required this.step,
    required this.icon,
    required this.title,
    required this.message,
    this.isLoading = false,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CalculatorStepHeader(
            step: step,
            icon: icon,
            title: title,
            subtitle: message,
          ),
          if (isLoading) ...[
            const SizedBox(height: 14),
            LinearProgressIndicator(
              minHeight: 3,
              color: context.brandPrimary,
              backgroundColor: context.brandPrimary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(99),
            ),
          ],
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Повторить'),
                style: TextButton.styleFrom(
                  foregroundColor: context.brandPrimary,
                  textStyle: const TextStyle(
                    fontFamily: 'Gilroy',
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CalculationPendingCard extends StatelessWidget {
  final String title;
  final String message;
  final bool isLoading;
  final VoidCallback? onRetry;

  const _CalculationPendingCard({
    required this.title,
    required this.message,
    this.isLoading = false,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.brandPrimary.withValues(alpha: 0.065),
              borderRadius: BorderRadius.circular(19),
              border: Border.all(
                color: context.brandPrimary.withValues(alpha: 0.12),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: isLoading
                      ? Padding(
                          padding: const EdgeInsets.all(12),
                          child: CircularProgressIndicator(
                            strokeWidth: 2.3,
                            color: context.brandPrimary,
                          ),
                        )
                      : Icon(
                          Icons.calculate_outlined,
                          color: context.brandPrimary,
                          size: 22,
                        ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontFamily: 'Gilroy',
                          fontSize: 16,
                          height: 1.05,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        message,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontFamily: 'Gilroy',
                          fontSize: 12,
                          height: 1.25,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Повторить расчёт'),
              style: OutlinedButton.styleFrom(
                foregroundColor: context.brandPrimary,
                side: BorderSide(
                  color: context.brandPrimary.withValues(alpha: 0.35),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                textStyle: const TextStyle(
                  fontFamily: 'Gilroy',
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

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

class _AssemblyOptionsCard extends StatelessWidget {
  final CalculatorTariff tariff;
  final PackagingRemovalOption packagingRemoval;
  final AssemblyPlacePreference placePreference;
  final bool hasFragileGoods;
  final bool hasInsurance;
  final TextEditingController insuranceAmountController;
  final ValueChanged<PackagingRemovalOption> onPackagingRemovalChanged;
  final ValueChanged<AssemblyPlacePreference> onPlacePreferenceChanged;
  final ValueChanged<bool> onFragileGoodsChanged;
  final ValueChanged<bool> onInsuranceChanged;
  final ValueChanged<String> onInsuranceAmountChanged;

  const _AssemblyOptionsCard({
    required this.tariff,
    required this.packagingRemoval,
    required this.placePreference,
    required this.hasFragileGoods,
    required this.hasInsurance,
    required this.insuranceAmountController,
    required this.onPackagingRemovalChanged,
    required this.onPlacePreferenceChanged,
    required this.onFragileGoodsChanged,
    required this.onInsuranceChanged,
    required this.onInsuranceAmountChanged,
  });

  String _removalTitle(PackagingRemovalOption option) {
    return switch (option) {
      PackagingRemovalOption.none => 'Не снимать',
      PackagingRemovalOption.transportOnly => 'Снять транспортировочную',
      PackagingRemovalOption.all => 'Снять всю упаковку',
    };
  }

  String _removalDescription(PackagingRemovalOption option) {
    final price = switch (option) {
      PackagingRemovalOption.none => null,
      PackagingRemovalOption.transportOnly =>
        tariff.packagingRemovalTransportPrice,
      PackagingRemovalOption.all => tariff.packagingRemovalAllPrice,
    };
    if (option == PackagingRemovalOption.none) {
      return 'Обычная ставка выбранного тарифа';
    }
    if (price != null && price > 0) {
      return 'Специальная ставка \$${price.toStringAsFixed(2)} за расчётную единицу';
    }
    return 'Специальная ставка не задана — расчёт по обычному тарифу';
  }

  IconData _removalIcon(PackagingRemovalOption option) {
    return switch (option) {
      PackagingRemovalOption.none => Icons.inventory_2_outlined,
      PackagingRemovalOption.transportOnly => Icons.layers_clear_outlined,
      PackagingRemovalOption.all => Icons.delete_sweep_outlined,
    };
  }

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _CalculatorStepHeader(
            step: 3,
            icon: Icons.tune_rounded,
            title: 'Параметры сборки',
            subtitle: 'Настройте снятие упаковки, места и защиту груза.',
          ),
          const SizedBox(height: 14),
          const _SubsectionLabel('Снятие упаковки'),
          const SizedBox(height: 8),
          Column(
            children: PackagingRemovalOption.values
                .map(
                  (option) => Padding(
                    padding: EdgeInsets.only(
                      bottom: option == PackagingRemovalOption.values.last
                          ? 0
                          : 8,
                    ),
                    child: _AssemblyOptionTile(
                      title: _removalTitle(option),
                      subtitle: _removalDescription(option),
                      icon: _removalIcon(option),
                      selected: packagingRemoval == option,
                      onTap: () => onPackagingRemovalChanged(option),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 14),
          const _SubsectionLabel('Пожелание по упаковке'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _AssemblyChoiceCard(
                  title: 'По возможности 1',
                  subtitle: 'Собрать в одно место',
                  icon: Icons.inventory_2_outlined,
                  selected:
                      placePreference ==
                      AssemblyPlacePreference.singleIfPossible,
                  onTap: () => onPlacePreferenceChanged(
                    AssemblyPlacePreference.singleIfPossible,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _AssemblyChoiceCard(
                  title: 'Можно разделить',
                  subtitle: 'Разрешить несколько мест',
                  icon: Icons.view_module_outlined,
                  selected:
                      placePreference == AssemblyPlacePreference.splitAllowed,
                  onTap: () => onPlacePreferenceChanged(
                    AssemblyPlacePreference.splitAllowed,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            dense: true,
            visualDensity: VisualDensity.compact,
            title: const Text(
              'Хрупкий груз',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontFamily: 'Gilroy',
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
            subtitle: const Text(
              'На сумму напрямую не влияет, но требует подходящей упаковки',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontFamily: 'Gilroy',
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            value: hasFragileGoods,
            activeTrackColor: context.brandPrimary.withValues(alpha: 0.45),
            activeThumbColor: context.brandPrimary,
            onChanged: onFragileGoodsChanged,
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            dense: true,
            visualDensity: VisualDensity.compact,
            title: const Text(
              'Страховка',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontFamily: 'Gilroy',
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
            subtitle: const Text(
              '2,5% от стоимости товаров, пересчитанной из CNY в USD',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontFamily: 'Gilroy',
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            value: hasInsurance,
            activeTrackColor: context.brandPrimary.withValues(alpha: 0.45),
            activeThumbColor: context.brandPrimary,
            onChanged: onInsuranceChanged,
          ),
          if (hasInsurance) ...[
            const SizedBox(height: 8),
            _NumField(
              label: 'Стоимость товаров, CNY',
              controller: insuranceAmountController,
              hint: 'например 1500',
              decimal: true,
              onChanged: onInsuranceAmountChanged,
            ),
          ],
        ],
      ),
    );
  }
}

class _AssemblyOptionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _AssemblyOptionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: selected
                  ? context.brandPrimary.withValues(alpha: 0.065)
                  : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected
                    ? context.brandPrimary
                    : const Color(0xFFE4E8EF),
                width: selected ? 1.3 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: selected
                        ? context.brandPrimary.withValues(alpha: 0.12)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    icon,
                    size: 19,
                    color: selected
                        ? context.brandPrimary
                        : AppColors.textSecondary,
                  ),
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
                          fontSize: 13.5,
                          height: 1.08,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontFamily: 'Gilroy',
                          fontSize: 11.5,
                          height: 1.18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: selected
                      ? context.brandPrimary
                      : AppColors.textSecondary.withValues(alpha: 0.65),
                  size: 21,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AssemblyChoiceCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _AssemblyChoiceCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(17),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(17),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            constraints: const BoxConstraints(minHeight: 96),
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: selected
                  ? context.brandPrimary.withValues(alpha: 0.065)
                  : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(17),
              border: Border.all(
                color: selected
                    ? context.brandPrimary
                    : const Color(0xFFE4E8EF),
                width: selected ? 1.3 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      icon,
                      size: 20,
                      color: selected
                          ? context.brandPrimary
                          : AppColors.textSecondary,
                    ),
                    const Spacer(),
                    Icon(
                      selected
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_unchecked_rounded,
                      size: 20,
                      color: selected
                          ? context.brandPrimary
                          : AppColors.textSecondary.withValues(alpha: 0.65),
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontFamily: 'Gilroy',
                    fontSize: 13,
                    height: 1.08,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontFamily: 'Gilroy',
                    fontSize: 11,
                    height: 1.12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PackagingPickerCard extends StatelessWidget {
  final List<CalculatorPackaging> packagings;
  final CalculatorPackaging? selectedPrimaryPackaging;
  final Set<int> selectedAddonPackagingIds;
  final bool hasFragileGoods;
  final ValueChanged<CalculatorPackaging?> onPrimaryChanged;
  final ValueChanged<Set<int>> onAddonSelectionChanged;

  const _PackagingPickerCard({
    required this.packagings,
    required this.selectedPrimaryPackaging,
    required this.selectedAddonPackagingIds,
    required this.hasFragileGoods,
    required this.onPrimaryChanged,
    required this.onAddonSelectionChanged,
  });

  String _priceLabel(CalculatorPackaging packaging) {
    if (packaging.baseCost <= 0) return 'Без дополнительной стоимости';
    return '\$${packaging.baseCost.toStringAsFixed(2)} / ${packaging.unitLabel}';
  }

  Future<void> _showPrimaryPackagingSheet(
    BuildContext context,
    List<CalculatorPackaging> options,
  ) async {
    if (options.isEmpty) return;
    final selectedId = await showBlurredModalBottomSheet<int>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _PrimaryPackagingSheet(
        options: options,
        selectedId: selectedPrimaryPackaging?.id,
      ),
    );
    if (selectedId == null) return;
    final selected = options.firstWhere((option) => option.id == selectedId);
    onPrimaryChanged(selected);
  }

  Future<void> _showAddonPackagingSheet(
    BuildContext context,
    List<CalculatorPackaging> options,
  ) async {
    if (options.isEmpty) return;
    final selectedIds = await showBlurredModalBottomSheet<Set<int>>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _AddonPackagingSheet(
        options: options,
        selectedIds: selectedAddonPackagingIds,
      ),
    );
    if (selectedIds != null) onAddonSelectionChanged(selectedIds);
  }

  @override
  Widget build(BuildContext context) {
    final primaryPackagings = packagings.where((p) => p.isPrimary).toList();
    final addonPackagings = packagings.where((p) => p.isAddon).toList();
    final selectedAddonPackagings = addonPackagings
        .where((packaging) => selectedAddonPackagingIds.contains(packaging.id))
        .toList();
    final selectedPackagings = packagings
        .where(
          (packaging) =>
              packaging.id == selectedPrimaryPackaging?.id ||
              selectedAddonPackagingIds.contains(packaging.id),
        )
        .toList();
    final fragilePackagingSelected = selectedPackagings.any(
      (packaging) => packaging.suitableForFragileGoods,
    );

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _CalculatorStepHeader(
            step: 4,
            icon: Icons.inventory_rounded,
            title: 'Упаковка',
            subtitle:
                'Основная упаковка обязательна, защита добавляется отдельно.',
          ),
          const SizedBox(height: 12),
          if (hasFragileGoods && !fragilePackagingSelected) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.orange.withValues(alpha: 0.20),
                ),
              ),
              child: const Text(
                'Для хрупкого груза выберите упаковку с отметкой «Для хрупкого».',
                style: TextStyle(
                  color: Colors.deepOrange,
                  fontFamily: 'Gilroy',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          _PackagingSummaryTile(
            title: 'Основная упаковка',
            value:
                selectedPrimaryPackaging?.name ??
                (primaryPackagings.isEmpty
                    ? 'Нет доступных вариантов'
                    : 'Выберите упаковку'),
            detail: selectedPrimaryPackaging == null
                ? 'Один обязательный вариант'
                : _priceLabel(selectedPrimaryPackaging!),
            icon: Icons.inventory_2_outlined,
            isSelected: selectedPrimaryPackaging != null,
            onTap: primaryPackagings.isEmpty
                ? null
                : () => _showPrimaryPackagingSheet(context, primaryPackagings),
          ),
          const SizedBox(height: 10),
          _PackagingSummaryTile(
            title: 'Дополнительная защита',
            value: selectedAddonPackagings.isEmpty
                ? 'Без дополнительной защиты'
                : selectedAddonPackagings.map((item) => item.name).join(', '),
            detail: selectedAddonPackagings.isEmpty
                ? 'Можно выбрать несколько вариантов'
                : 'Выбрано: ${selectedAddonPackagings.length}',
            icon: Icons.health_and_safety_outlined,
            isSelected: selectedAddonPackagings.isNotEmpty,
            onTap: addonPackagings.isEmpty
                ? null
                : () => _showAddonPackagingSheet(context, addonPackagings),
          ),
        ],
      ),
    );
  }
}

class _PackagingSummaryTile extends StatelessWidget {
  final String title;
  final String value;
  final String detail;
  final IconData icon;
  final bool isSelected;
  final VoidCallback? onTap;

  const _PackagingSummaryTile({
    required this.title,
    required this.value,
    required this.detail,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected
                ? context.brandPrimary.withValues(alpha: 0.055)
                : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected
                  ? context.brandPrimary.withValues(alpha: 0.28)
                  : const Color(0xFFE4E8EF),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: context.brandPrimary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: context.brandPrimary, size: 21),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontFamily: 'Gilroy',
                        fontSize: 11.5,
                        height: 1,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontFamily: 'Gilroy',
                        fontSize: 14,
                        height: 1.12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      detail,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontFamily: 'Gilroy',
                        fontSize: 11.5,
                        height: 1.1,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                onTap == null
                    ? Icons.remove_rounded
                    : Icons.chevron_right_rounded,
                color: onTap == null
                    ? AppColors.textSecondary.withValues(alpha: 0.45)
                    : context.brandPrimary,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _tariffPricingDescription(CalculatorTariff tariff) {
  if (!tariff.isDensity) return 'Расчёт по весу · ставка за кг';
  final hasPerM3 = tariff.densityTiers.any(
    (tier) => tier.clientPricePerM3 != null,
  );
  final hasPerKg = tariff.densityTiers.any(
    (tier) => tier.clientPricePerKg != null,
  );
  if (hasPerM3 && hasPerKg) {
    return 'Расчёт по плотности · ставка за кг или м³';
  }
  if (hasPerM3) return 'Расчёт по плотности · ставка за м³';
  return 'Расчёт по плотности · ставка за кг';
}

class _TariffSelectionSheet extends StatelessWidget {
  final List<CalculatorTariff> options;
  final int? selectedId;

  const _TariffSelectionSheet({
    required this.options,
    required this.selectedId,
  });

  @override
  Widget build(BuildContext context) {
    final sheetHeight = (MediaQuery.sizeOf(context).height * 0.74)
        .clamp(340.0, 680.0)
        .toDouble();
    return SizedBox(
      height: sheetHeight,
      child: ColoredBox(
        color: Colors.white,
        child: Column(
          children: [
            const _PackagingSheetHeader(
              icon: Icons.local_shipping_outlined,
              title: 'Тариф доставки',
              subtitle: 'Выберите тариф для предварительного расчёта.',
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
                itemCount: options.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final tariff = options[index];
                  return _PackagingOptionTile(
                    title: tariff.name,
                    subtitle: _tariffPricingDescription(tariff),
                    selected: selectedId == tariff.id,
                    primary: true,
                    badges: [
                      _PackagingBadgeData(
                        label: tariff.isDensity ? 'По плотности' : 'По весу',
                        color: context.brandPrimary,
                      ),
                      if (!tariff.paidPhotoReport)
                        _PackagingBadgeData(
                          label: 'Фото включено',
                          color: Colors.green.shade700,
                        ),
                    ],
                    onTap: () => Navigator.of(context).pop(tariff.id),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrimaryPackagingSheet extends StatelessWidget {
  final List<CalculatorPackaging> options;
  final int? selectedId;

  const _PrimaryPackagingSheet({
    required this.options,
    required this.selectedId,
  });

  @override
  Widget build(BuildContext context) {
    final sheetHeight = (MediaQuery.sizeOf(context).height * 0.82)
        .clamp(360.0, 760.0)
        .toDouble();
    return SizedBox(
      height: sheetHeight,
      child: ColoredBox(
        color: Colors.white,
        child: Column(
          children: [
            const _PackagingSheetHeader(
              icon: Icons.inventory_2_outlined,
              title: 'Основная упаковка',
              subtitle: 'Выберите один вариант для расчёта.',
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
                itemCount: options.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final packaging = options[index];
                  return _PackagingOptionTile(
                    title: packaging.name,
                    subtitle: packaging.baseCost > 0
                        ? '\$${packaging.baseCost.toStringAsFixed(2)} / ${packaging.unitLabel}'
                        : 'Без дополнительной стоимости',
                    selected: selectedId == packaging.id,
                    primary: true,
                    badges: [
                      _PackagingBadgeData(
                        label: 'Основная',
                        color: context.brandPrimary,
                      ),
                      if (packaging.suitableForFragileGoods)
                        _PackagingBadgeData(
                          label: 'Для хрупкого',
                          color: Colors.green.shade700,
                        ),
                    ],
                    onTap: () => Navigator.of(context).pop(packaging.id),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddonPackagingSheet extends StatefulWidget {
  final List<CalculatorPackaging> options;
  final Set<int> selectedIds;

  const _AddonPackagingSheet({
    required this.options,
    required this.selectedIds,
  });

  @override
  State<_AddonPackagingSheet> createState() => _AddonPackagingSheetState();
}

class _AddonPackagingSheetState extends State<_AddonPackagingSheet> {
  late final Set<int> _selectedIds = {...widget.selectedIds};

  void _toggle(int id) {
    setState(() {
      if (!_selectedIds.add(id)) _selectedIds.remove(id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final sheetHeight = (MediaQuery.sizeOf(context).height * 0.82)
        .clamp(420.0, 760.0)
        .toDouble();
    return SizedBox(
      height: sheetHeight,
      child: ColoredBox(
        color: Colors.white,
        child: Column(
          children: [
            const _PackagingSheetHeader(
              icon: Icons.health_and_safety_outlined,
              title: 'Дополнительная защита',
              subtitle: 'Выберите несколько вариантов или оставьте без защиты.',
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                itemCount: widget.options.length + 1,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _PackagingOptionTile(
                      title: 'Без дополнительной защиты',
                      subtitle: 'Учитывать только основную упаковку',
                      selected: _selectedIds.isEmpty,
                      primary: true,
                      badges: const [],
                      onTap: () => setState(_selectedIds.clear),
                    );
                  }
                  final packaging = widget.options[index - 1];
                  return _PackagingOptionTile(
                    title: packaging.name,
                    subtitle: packaging.baseCost > 0
                        ? '\$${packaging.baseCost.toStringAsFixed(2)} / ${packaging.unitLabel}'
                        : 'Без дополнительной стоимости',
                    selected: _selectedIds.contains(packaging.id),
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
                    onTap: () => _toggle(packaging.id),
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFEEF0F4))),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: () => Navigator.of(
                    context,
                  ).pop(Set<int>.unmodifiable(_selectedIds)),
                  style: FilledButton.styleFrom(
                    backgroundColor: context.brandPrimary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(17),
                    ),
                  ),
                  child: Text(
                    _selectedIds.isEmpty
                        ? 'Готово · без защиты'
                        : 'Готово · выбрано ${_selectedIds.length}',
                    style: const TextStyle(
                      fontFamily: 'Gilroy',
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PackagingSheetHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _PackagingSheetHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 10, 14),
      child: Column(
        children: [
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFDDE0E5),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: context.brandPrimary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: context.brandPrimary, size: 22),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontFamily: 'Gilroy',
                        fontSize: 18,
                        height: 1.05,
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
                        height: 1.16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                tooltip: 'Закрыть',
                icon: const Icon(Icons.close_rounded),
                color: AppColors.textSecondary,
              ),
            ],
          ),
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

class _SubsectionLabel extends StatelessWidget {
  final String text;

  const _SubsectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontFamily: 'Gilroy',
        fontWeight: FontWeight.w900,
        fontSize: 14,
        height: 18 / 14,
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
