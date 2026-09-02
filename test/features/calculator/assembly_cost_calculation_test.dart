import 'package:flutter_test/flutter_test.dart';
import 'package:twoalogisticcabineuser/src/features/calculator/domain/assembly_cost_calculation.dart';

void main() {
  const primaryPackaging = CalculatorPackaging(
    id: 10,
    name: 'Коробка',
    baseCost: 3,
  );
  const addonPackaging = CalculatorPackaging(
    id: 20,
    name: 'Пенопласт',
    baseCost: 2,
    kind: 'addon',
  );
  const photoCoefficients = [
    CalculatorPhotoCoefficient(minPercent: 0, maxPercent: 49, coefficient: 1.2),
    CalculatorPhotoCoefficient(
      minPercent: 50,
      maxPercent: 100,
      coefficient: 1.1,
    ),
  ];

  group('calculateAssemblyCost', () {
    test('parses the current tariff API pricing contract', () {
      final tariff = CalculatorTariff.fromJson({
        'id': '7',
        'name': 'API tariff',
        'baseCost': 4.2,
        'paidPhotoReport': false,
        'packagingRemovalTransportPrice': 3.1,
        'packagingRemovalAllPrice': 2.8,
        'weightTiers': [
          {'minWeight': 0, 'maxWeight': null, 'pricePerKg': 4},
        ],
        'packagingSurcharges': [
          {'packagingTypeId': 10, 'amount': 0.4, 'isActive': true},
        ],
        'pricingType': 'density',
        'densityTiers': [
          {'minDensity': 0, 'maxDensity': 100, 'clientPricePerM3': 320},
        ],
      });

      expect(tariff.id, 7);
      expect(tariff.paidPhotoReport, isFalse);
      expect(tariff.packagingRemovalTransportPrice, 3.1);
      expect(tariff.packagingRemovalAllPrice, 2.8);
      expect(tariff.weightTiers.single.maxWeight, isNull);
      expect(tariff.packagingSurcharges.single.amount, 0.4);
      expect(tariff.isDensity, isTrue);
      expect(tariff.densityTiers.single.clientPricePerM3, 320);
    });

    test('includes all priced assembly options in the total', () {
      const tariff = CalculatorTariff(
        id: 1,
        name: 'Весовой',
        baseCost: 4,
        weightTiers: [
          CalculatorWeightTier(minWeight: 0, maxWeight: 10, pricePerKg: 5),
          CalculatorWeightTier(minWeight: 10, pricePerKg: 4),
        ],
        packagingSurcharges: [
          CalculatorPackagingSurcharge(
            packagingTypeId: 20,
            amount: 0.5,
            isActive: true,
          ),
        ],
      );

      final result = calculateAssemblyCost(
        const AssemblyCostInput(
          tariff: tariff,
          photoCoefficients: photoCoefficients,
          selectedPackagings: [primaryPackaging, addonPackaging],
          weightKg: 20,
          volumeM3: 0.2,
          places: 2,
          tracksTotal: 4,
          tracksWithPhoto: 2,
          unloadingCostUsd: 7,
          hasInsurance: true,
          insuranceAmountCny: 725,
          hasFragileGoods: true,
          placePreference: AssemblyPlacePreference.splitAllowed,
        ),
      );

      expect(result, isNotNull);
      expect(result!.clientPrice, 4.5);
      expect(result.photoCoefficient, 1.1);
      expect(result.shippingCost, closeTo(99, 0.0001));
      expect(result.packagingCost, 10);
      expect(result.insuranceBaseUsd, 100);
      expect(result.insuranceCost, 2.5);
      expect(result.total, closeTo(118.5, 0.0001));
    });

    test('packaging removal price overrides tier and surcharge', () {
      const tariff = CalculatorTariff(
        id: 1,
        name: 'Весовой',
        baseCost: 5,
        packagingRemovalAllPrice: 2.25,
        weightTiers: [CalculatorWeightTier(minWeight: 0, pricePerKg: 4)],
        packagingSurcharges: [
          CalculatorPackagingSurcharge(
            packagingTypeId: 10,
            amount: 1,
            isActive: true,
          ),
        ],
      );

      final result = calculateAssemblyCost(
        const AssemblyCostInput(
          tariff: tariff,
          photoCoefficients: [],
          selectedPackagings: [primaryPackaging],
          weightKg: 10,
          volumeM3: 0.1,
          places: 1,
          tracksTotal: 1,
          tracksWithPhoto: 0,
          unloadingCostUsd: 5,
          packagingRemoval: PackagingRemovalOption.all,
        ),
      )!;

      expect(result.clientPrice, 2.25);
      expect(result.packagingTariffSurcharge, 0);
      expect(result.shippingCost, 22.5);
      expect(result.removalPriceApplied, isTrue);
    });

    test('does not apply photo coefficient for a free-photo tariff', () {
      const tariff = CalculatorTariff(
        id: 1,
        name: 'Фото включено',
        baseCost: 5,
        paidPhotoReport: false,
      );

      final result = calculateAssemblyCost(
        const AssemblyCostInput(
          tariff: tariff,
          photoCoefficients: photoCoefficients,
          selectedPackagings: [primaryPackaging],
          weightKg: 10,
          volumeM3: 0.1,
          places: 1,
          tracksTotal: 10,
          tracksWithPhoto: 1,
          unloadingCostUsd: 5,
        ),
      )!;

      expect(result.photoCoefficient, 1);
      expect(result.shippingCost, 50);
    });

    test('uses inclusive upper weight boundary like backend', () {
      const tariff = CalculatorTariff(
        id: 1,
        name: 'Граница',
        baseCost: 9,
        weightTiers: [
          CalculatorWeightTier(minWeight: 0, maxWeight: 10, pricePerKg: 6),
          CalculatorWeightTier(minWeight: 11, pricePerKg: 5),
        ],
      );

      final result = calculateAssemblyCost(
        const AssemblyCostInput(
          tariff: tariff,
          photoCoefficients: [],
          selectedPackagings: [primaryPackaging],
          weightKg: 10,
          volumeM3: 0.1,
          places: 1,
          tracksTotal: 1,
          tracksWithPhoto: 0,
          unloadingCostUsd: 0,
        ),
      )!;

      expect(result.clientPrice, 6);
    });

    test('uses density volume basis without packaging tariff surcharge', () {
      const tariff = CalculatorTariff(
        id: 1,
        name: 'Плотность',
        baseCost: 5,
        pricingType: 'density',
        densityTiers: [
          CalculatorDensityTier(
            minDensity: 0,
            maxDensity: 200,
            clientPricePerM3: 300,
          ),
        ],
        packagingSurcharges: [
          CalculatorPackagingSurcharge(
            packagingTypeId: 10,
            amount: 2,
            isActive: true,
          ),
        ],
      );

      final result = calculateAssemblyCost(
        const AssemblyCostInput(
          tariff: tariff,
          photoCoefficients: [],
          selectedPackagings: [primaryPackaging],
          weightKg: 20,
          volumeM3: 0.2,
          places: 1,
          tracksTotal: 1,
          tracksWithPhoto: 0,
          unloadingCostUsd: 0,
        ),
      )!;

      expect(result.priceUnit, 'м³');
      expect(result.shippingBasis, 0.2);
      expect(result.packagingTariffSurcharge, 0);
      expect(result.shippingCost, 60);
    });

    test('matches backend density tier selection on an inclusive boundary', () {
      const tariff = CalculatorTariff(
        id: 1,
        name: 'Плотность с границей',
        baseCost: 9,
        pricingType: 'density',
        densityTiers: [
          CalculatorDensityTier(
            minDensity: 100,
            maxDensity: 200,
            clientPricePerKg: 5,
          ),
          CalculatorDensityTier(
            minDensity: 0,
            maxDensity: 100,
            clientPricePerM3: 300,
          ),
        ],
      );

      final result = calculateAssemblyCost(
        const AssemblyCostInput(
          tariff: tariff,
          photoCoefficients: [],
          selectedPackagings: [primaryPackaging],
          weightKg: 50,
          volumeM3: 0.5,
          places: 1,
          tracksTotal: 1,
          tracksWithPhoto: 0,
          unloadingCostUsd: 0,
        ),
      )!;

      expect(result.priceUnit, 'кг');
      expect(result.shippingBasis, 50);
      expect(result.clientPrice, 5);
      expect(result.shippingCost, 250);
    });

    test('applies photo coefficient to the volumetric density amount', () {
      const tariff = CalculatorTariff(
        id: 1,
        name: 'Объёмный с фото',
        baseCost: 5,
        pricingType: 'density',
        densityTiers: [
          CalculatorDensityTier(
            minDensity: 0,
            maxDensity: 200,
            clientPricePerM3: 300,
          ),
        ],
      );

      final result = calculateAssemblyCost(
        const AssemblyCostInput(
          tariff: tariff,
          photoCoefficients: photoCoefficients,
          selectedPackagings: [primaryPackaging],
          weightKg: 20,
          volumeM3: 0.2,
          places: 1,
          tracksTotal: 2,
          tracksWithPhoto: 1,
          unloadingCostUsd: 0,
        ),
      )!;

      expect(result.priceUnit, 'м³');
      expect(result.photoCoefficient, 1.1);
      expect(result.shippingCost, closeTo(66, 0.0001));
    });

    test('keeps volume basis when removal overrides a volumetric tariff', () {
      const tariff = CalculatorTariff(
        id: 1,
        name: 'Объёмный со снятием',
        baseCost: 5,
        pricingType: 'density',
        packagingRemovalAllPrice: 230,
        densityTiers: [
          CalculatorDensityTier(
            minDensity: 0,
            maxDensity: 100,
            clientPricePerM3: 200,
          ),
        ],
      );

      final result = calculateAssemblyCost(
        const AssemblyCostInput(
          tariff: tariff,
          photoCoefficients: [],
          selectedPackagings: [primaryPackaging],
          weightKg: 50,
          volumeM3: 1,
          places: 1,
          tracksTotal: 1,
          tracksWithPhoto: 0,
          unloadingCostUsd: 0,
          packagingRemoval: PackagingRemovalOption.all,
        ),
      )!;

      expect(result.priceUnit, 'м³');
      expect(result.shippingBasis, 1);
      expect(result.clientPrice, 230);
      expect(result.shippingCost, 230);
      expect(result.removalPriceApplied, isTrue);
    });

    test(
      'rejects invalid photo count, missing packaging and empty insurance',
      () {
        const tariff = CalculatorTariff(id: 1, name: 'Тариф', baseCost: 5);

        AssemblyCostInput input({
          List<CalculatorPackaging> packagings = const [primaryPackaging],
          int tracksWithPhoto = 0,
          bool hasInsurance = false,
        }) {
          return AssemblyCostInput(
            tariff: tariff,
            photoCoefficients: const [],
            selectedPackagings: packagings,
            weightKg: 10,
            volumeM3: 0.1,
            places: 1,
            tracksTotal: 1,
            tracksWithPhoto: tracksWithPhoto,
            unloadingCostUsd: 0,
            hasInsurance: hasInsurance,
          );
        }

        expect(calculateAssemblyCost(input(tracksWithPhoto: 2)), isNull);
        expect(calculateAssemblyCost(input(packagings: const [])), isNull);
        expect(calculateAssemblyCost(input(hasInsurance: true)), isNull);
      },
    );
  });
}
