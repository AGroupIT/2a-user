enum PackagingRemovalOption { none, transportOnly, all }

enum AssemblyPlacePreference { singleIfPossible, splitAllowed }

const double assemblyInsuranceCnyPerUsd = 7.25;
const double defaultClientInsurancePercent = 2.5;

double _number(Object? value, [double fallback = 0]) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? fallback;
}

double _roundMoney(double value) => (value * 100).round() / 100;

class CalculatorWeightTier {
  final double minWeight;
  final double? maxWeight;
  final double pricePerKg;

  const CalculatorWeightTier({
    required this.minWeight,
    this.maxWeight,
    required this.pricePerKg,
  });

  factory CalculatorWeightTier.fromJson(Map<String, dynamic> json) {
    return CalculatorWeightTier(
      minWeight: _number(json['minWeight']),
      maxWeight: json['maxWeight'] == null ? null : _number(json['maxWeight']),
      pricePerKg: _number(json['pricePerKg']),
    );
  }
}

class CalculatorDensityTier {
  final double minDensity;
  final double? maxDensity;
  final double? clientPricePerKg;
  final double? clientPricePerM3;

  const CalculatorDensityTier({
    required this.minDensity,
    this.maxDensity,
    this.clientPricePerKg,
    this.clientPricePerM3,
  });

  bool get isVolumetric => clientPricePerM3 != null;

  factory CalculatorDensityTier.fromJson(Map<String, dynamic> json) {
    return CalculatorDensityTier(
      minDensity: _number(json['minDensity']),
      maxDensity: json['maxDensity'] == null
          ? null
          : _number(json['maxDensity']),
      clientPricePerKg: json['clientPricePerKg'] == null
          ? null
          : _number(json['clientPricePerKg']),
      clientPricePerM3: json['clientPricePerM3'] == null
          ? null
          : _number(json['clientPricePerM3']),
    );
  }
}

class CalculatorPackagingSurcharge {
  final int packagingTypeId;
  final double amount;
  final bool isActive;

  const CalculatorPackagingSurcharge({
    required this.packagingTypeId,
    required this.amount,
    required this.isActive,
  });

  factory CalculatorPackagingSurcharge.fromJson(Map<String, dynamic> json) {
    return CalculatorPackagingSurcharge(
      packagingTypeId: _number(json['packagingTypeId']).toInt(),
      amount: _number(json['amount']),
      isActive: json['isActive'] != false,
    );
  }
}

class CalculatorTariff {
  final int id;
  final String name;
  final double baseCost;
  final String pricingType;
  final bool paidPhotoReport;
  final double? packagingRemovalTransportPrice;
  final double? packagingRemovalAllPrice;
  final List<CalculatorWeightTier> weightTiers;
  final List<CalculatorDensityTier> densityTiers;
  final List<CalculatorPackagingSurcharge> packagingSurcharges;

  const CalculatorTariff({
    required this.id,
    required this.name,
    required this.baseCost,
    this.pricingType = 'weight',
    this.paidPhotoReport = true,
    this.packagingRemovalTransportPrice,
    this.packagingRemovalAllPrice,
    this.weightTiers = const [],
    this.densityTiers = const [],
    this.packagingSurcharges = const [],
  });

  bool get isDensity => pricingType == 'density';

  factory CalculatorTariff.fromJson(Map<String, dynamic> json) {
    return CalculatorTariff(
      id: _number(json['id']).toInt(),
      name: json['name'] as String? ?? '',
      baseCost: _number(json['baseCost']),
      pricingType: json['pricingType'] as String? ?? 'weight',
      paidPhotoReport: json['paidPhotoReport'] != false,
      packagingRemovalTransportPrice:
          json['packagingRemovalTransportPrice'] == null
          ? null
          : _number(json['packagingRemovalTransportPrice']),
      packagingRemovalAllPrice: json['packagingRemovalAllPrice'] == null
          ? null
          : _number(json['packagingRemovalAllPrice']),
      weightTiers: ((json['weightTiers'] as List?) ?? const [])
          .map(
            (item) =>
                CalculatorWeightTier.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
      densityTiers: ((json['densityTiers'] as List?) ?? const [])
          .map(
            (item) =>
                CalculatorDensityTier.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
      packagingSurcharges: ((json['packagingSurcharges'] as List?) ?? const [])
          .map(
            (item) => CalculatorPackagingSurcharge.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .toList(),
    );
  }
}

class CalculatorPhotoCoefficient {
  final double minPercent;
  final double? maxPercent;
  final double coefficient;
  final bool isActive;
  final int sortOrder;

  const CalculatorPhotoCoefficient({
    required this.minPercent,
    this.maxPercent,
    required this.coefficient,
    this.isActive = true,
    this.sortOrder = 0,
  });

  factory CalculatorPhotoCoefficient.fromJson(Map<String, dynamic> json) {
    return CalculatorPhotoCoefficient(
      minPercent: _number(json['minPercent']),
      maxPercent: json['maxPercent'] == null
          ? null
          : _number(json['maxPercent']),
      coefficient: _number(json['coefficient'], 1),
      isActive: json['isActive'] != false,
      sortOrder: _number(json['sortOrder']).toInt(),
    );
  }
}

class CalculatorPackaging {
  final int id;
  final String name;
  final double baseCost;
  final bool isActive;
  final String unitLabel;
  final String kind;
  final bool suitableForFragileGoods;

  const CalculatorPackaging({
    required this.id,
    required this.name,
    required this.baseCost,
    this.isActive = true,
    this.unitLabel = 'место',
    this.kind = 'primary',
    this.suitableForFragileGoods = false,
  });

  bool get isPrimary => kind != 'addon';
  bool get isAddon => kind == 'addon';

  factory CalculatorPackaging.fromJson(Map<String, dynamic> json) {
    return CalculatorPackaging(
      id: _number(json['id']).toInt(),
      name: json['nameRu'] as String? ?? json['name'] as String? ?? '',
      baseCost: _number(json['baseCost']),
      isActive: json['isActive'] != false,
      unitLabel: json['unitLabel'] as String? ?? 'место',
      kind: json['kind'] as String? ?? 'primary',
      suitableForFragileGoods: json['suitableForFragileGoods'] == true,
    );
  }
}

class AssemblyCostInput {
  final CalculatorTariff tariff;
  final List<CalculatorPhotoCoefficient> photoCoefficients;
  final List<CalculatorPackaging> selectedPackagings;
  final double weightKg;
  final double volumeM3;
  final int places;
  final int tracksTotal;
  final int tracksWithPhoto;
  final double unloadingCostUsd;
  final PackagingRemovalOption packagingRemoval;
  final bool hasInsurance;
  final double insuranceAmountCny;
  final bool hasFragileGoods;
  final AssemblyPlacePreference placePreference;

  const AssemblyCostInput({
    required this.tariff,
    required this.photoCoefficients,
    required this.selectedPackagings,
    required this.weightKg,
    required this.volumeM3,
    required this.places,
    required this.tracksTotal,
    required this.tracksWithPhoto,
    required this.unloadingCostUsd,
    this.packagingRemoval = PackagingRemovalOption.none,
    this.hasInsurance = false,
    this.insuranceAmountCny = 0,
    this.hasFragileGoods = false,
    this.placePreference = AssemblyPlacePreference.singleIfPossible,
  });

  bool get isValid =>
      weightKg > 0 &&
      volumeM3 > 0 &&
      places > 0 &&
      tracksTotal > 0 &&
      tracksWithPhoto >= 0 &&
      tracksWithPhoto <= tracksTotal &&
      selectedPackagings.any((packaging) => packaging.isPrimary) &&
      (!hasInsurance || insuranceAmountCny > 0);
}

class AssemblyCostResult {
  final double clientPrice;
  final double shippingBasis;
  final String priceUnit;
  final double photoCoefficient;
  final double photoPercent;
  final double packagingTariffSurcharge;
  final double shippingCost;
  final double unloadingCost;
  final double packagingBaseCost;
  final double packagingCost;
  final double insuranceBaseUsd;
  final double insuranceCost;
  final double total;
  final bool removalPriceApplied;

  const AssemblyCostResult({
    required this.clientPrice,
    required this.shippingBasis,
    required this.priceUnit,
    required this.photoCoefficient,
    required this.photoPercent,
    required this.packagingTariffSurcharge,
    required this.shippingCost,
    required this.unloadingCost,
    required this.packagingBaseCost,
    required this.packagingCost,
    required this.insuranceBaseUsd,
    required this.insuranceCost,
    required this.total,
    required this.removalPriceApplied,
  });
}

AssemblyCostResult? calculateAssemblyCost(AssemblyCostInput input) {
  if (!input.isValid) return null;

  final photoPercent = input.tracksWithPhoto / input.tracksTotal * 100;
  final photoCoefficient = input.tariff.paidPhotoReport
      ? _resolvePhotoCoefficient(photoPercent, input.photoCoefficients)
      : 1.0;
  final removalPrice = _resolveRemovalPrice(
    input.tariff,
    input.packagingRemoval,
  );

  final selectedPackagingIds = input.selectedPackagings
      .map((packaging) => packaging.id)
      .toSet();
  final packagingTariffSurcharge = input.tariff.isDensity
      ? 0.0
      : input.tariff.packagingSurcharges
            .where(
              (row) =>
                  row.isActive &&
                  selectedPackagingIds.contains(row.packagingTypeId),
            )
            .fold<double>(0, (sum, row) => sum + row.amount);

  late final double clientPrice;
  late final double shippingBasis;
  late final String priceUnit;

  final densityTier = input.tariff.isDensity
      ? _resolveDensityTier(
          input.tariff.densityTiers,
          input.weightKg / input.volumeM3,
        )
      : null;

  if (densityTier?.isVolumetric == true) {
    shippingBasis = input.volumeM3;
    priceUnit = 'м³';
    clientPrice = removalPrice ?? densityTier!.clientPricePerM3 ?? 0;
  } else {
    shippingBasis = input.weightKg;
    priceUnit = 'кг';
    if (removalPrice != null) {
      clientPrice = removalPrice;
    } else if (input.tariff.isDensity) {
      clientPrice = densityTier?.clientPricePerKg ?? input.tariff.baseCost;
    } else {
      clientPrice =
          _resolveWeightPrice(input.tariff, input.weightKg) +
          packagingTariffSurcharge;
    }
  }

  final shippingCost = shippingBasis * clientPrice * photoCoefficient;
  final packagingBaseCost = input.selectedPackagings.fold<double>(
    0,
    (sum, packaging) => sum + packaging.baseCost,
  );
  final packagingCost = packagingBaseCost * input.places;
  final insuranceBaseUsd = input.hasInsurance
      ? _roundMoney(input.insuranceAmountCny / assemblyInsuranceCnyPerUsd)
      : 0.0;
  final insuranceCost = input.hasInsurance
      ? _roundMoney(insuranceBaseUsd * defaultClientInsurancePercent / 100)
      : 0.0;
  final total =
      shippingCost + input.unloadingCostUsd + packagingCost + insuranceCost;

  return AssemblyCostResult(
    clientPrice: clientPrice,
    shippingBasis: shippingBasis,
    priceUnit: priceUnit,
    photoCoefficient: photoCoefficient,
    photoPercent: photoPercent,
    packagingTariffSurcharge: removalPrice == null
        ? packagingTariffSurcharge
        : 0,
    shippingCost: shippingCost,
    unloadingCost: input.unloadingCostUsd,
    packagingBaseCost: packagingBaseCost,
    packagingCost: packagingCost,
    insuranceBaseUsd: insuranceBaseUsd,
    insuranceCost: insuranceCost,
    total: total,
    removalPriceApplied: removalPrice != null,
  );
}

double _resolvePhotoCoefficient(
  double photoPercent,
  List<CalculatorPhotoCoefficient> coefficients,
) {
  final active = coefficients.where((item) => item.isActive).toList()
    ..sort((a, b) {
      final bySortOrder = a.sortOrder.compareTo(b.sortOrder);
      return bySortOrder != 0
          ? bySortOrder
          : a.minPercent.compareTo(b.minPercent);
    });
  for (final item in active) {
    final matchesMax =
        item.maxPercent == null || photoPercent <= item.maxPercent!;
    if (photoPercent >= item.minPercent && matchesMax) {
      return item.coefficient > 0 ? item.coefficient : 1;
    }
  }
  return 1;
}

double _resolveWeightPrice(CalculatorTariff tariff, double weightKg) {
  final tiers = [...tariff.weightTiers]
    ..sort((a, b) => a.minWeight.compareTo(b.minWeight));
  for (var index = tiers.length - 1; index >= 0; index--) {
    final tier = tiers[index];
    if (weightKg >= tier.minWeight &&
        (tier.maxWeight == null || weightKg <= tier.maxWeight!)) {
      return tier.pricePerKg;
    }
  }
  return tariff.baseCost;
}

CalculatorDensityTier? _resolveDensityTier(
  List<CalculatorDensityTier> densityTiers,
  double density,
) {
  final tiers = [...densityTiers]
    ..sort((a, b) => a.minDensity.compareTo(b.minDensity));
  for (var index = tiers.length - 1; index >= 0; index--) {
    final tier = tiers[index];
    if (density >= tier.minDensity &&
        (tier.maxDensity == null || density <= tier.maxDensity!)) {
      return tier;
    }
  }
  return null;
}

double? _resolveRemovalPrice(
  CalculatorTariff tariff,
  PackagingRemovalOption option,
) {
  final price = switch (option) {
    PackagingRemovalOption.none => null,
    PackagingRemovalOption.transportOnly =>
      tariff.packagingRemovalTransportPrice,
    PackagingRemovalOption.all => tariff.packagingRemovalAllPrice,
  };
  return price != null && price > 0 ? price : null;
}
