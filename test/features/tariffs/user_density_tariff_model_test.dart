import 'package:flutter_test/flutter_test.dart';
import 'package:twoalogisticcabineuser/src/features/calculator/domain/assembly_cost_calculation.dart';
import 'package:twoalogisticcabineuser/src/features/tariffs/data/tariffs_provider.dart';

void main() {
  test(
    'complete product requirement is reflected in the client catalog badge',
    () {
      for (final flags in [
        (false, true),
        (true, false),
        (true, true),
        (false, false),
      ]) {
        final tariff = UserDeliveryTariff.fromJson({
          'requiresProductInfo': flags.$1,
          'requiresCompleteProductInfo': flags.$2,
        });
        expect(tariff.requiresProductInfo, flags.$1 || flags.$2);
      }
      expect(UserDeliveryTariff.fromJson({}).requiresProductInfo, isFalse);
    },
  );

  test('legacy JSON and existing constructors retain weight defaults', () {
    final tariff = UserDeliveryTariff.fromJson({
      'id': 1,
      'name': 'Legacy',
      'baseCost': '2.5',
      'weightTiers': [
        {'minWeight': 10, 'maxWeight': 20, 'pricePerKg': 3},
      ],
    });
    expect(tariff.pricingType, 'weight');
    expect(tariff.isDensityBased, isFalse);
    expect(tariff.densityTiers, isEmpty);
    expect(tariff.weightTiers.single.pricePerKg, 3);
    expect(tariff.baseCost, 2.5);
    expect(
      const UserDeliveryTariff(
        id: 1,
        name: 'Existing',
        baseCost: 2,
      ).isDensityBased,
      isFalse,
    );
  });

  test(
    'density parsing preserves decimal strings, zero bounds, zero rates and nulls',
    () {
      final tariff = UserDeliveryTariff.fromJson({
        'pricingType': 'density',
        'densityTiers': [
          {'minDensity': '0', 'maxDensity': 0, 'clientPricePerKg': '0'},
          {
            'minDensity': '125.5',
            'maxDensity': null,
            'clientPricePerM3': '80.25',
          },
        ],
      });
      expect(tariff.isDensityBased, isTrue);
      final zero = tariff.densityTiers.first;
      expect(zero.minDensity, 0);
      expect(zero.maxDensity, 0);
      expect(zero.price, 0);
      expect(zero.clientPricePerM3, isNull);
      expect(zero.isVolumetric, isFalse);
      final volume = tariff.densityTiers.last;
      expect(volume.minDensity, 125.5);
      expect(volume.maxDensity, isNull);
      expect(volume.clientPricePerKg, isNull);
      expect(volume.price, 80.25);
      expect(volume.isVolumetric, isTrue);
    },
  );

  test(
    'mixed density minima stay separate and prefer m3 when both prices exist',
    () {
      final tariff = UserDeliveryTariff.fromJson({
        'pricingType': 'density',
        'baseCost': 0.01,
        'weightTiers': [
          {'minWeight': 0, 'pricePerKg': 0.001},
        ],
        'densityTiers': [
          {
            'minDensity': 0,
            'maxDensity': 100,
            'clientPricePerKg': 1,
            'clientPricePerM3': 80,
          },
          {'minDensity': 100, 'maxDensity': 200, 'clientPricePerKg': 4},
          {'minDensity': 200, 'clientPricePerKg': 3},
          {'minDensity': 300, 'clientPricePerM3': 100},
        ],
      });
      expect(tariff.minimumDensityPricePerKg, 3);
      expect(tariff.minimumDensityPricePerM3, 80);
      expect(tariff.densityTiers.first.price, 80);
    },
  );

  test('a zero m3 price takes precedence just like the calculator', () {
    final json = {
      'minDensity': 0,
      'clientPricePerKg': 5,
      'clientPricePerM3': 0,
    };
    final tier = UserDensityTier.fromJson(json);
    final calculator = CalculatorDensityTier.fromJson(json);
    expect(tier.isVolumetric, calculator.isVolumetric);
    expect(tier.price, 0);
    final tariff = UserDeliveryTariff(
      id: 1,
      name: 'Zero',
      baseCost: 9,
      pricingType: 'density',
      densityTiers: [tier],
    );
    expect(tariff.minimumDensityPricePerKg, isNull);
    expect(tariff.minimumDensityPricePerM3, 0);
  });

  test(
    'missing density rates never fall back to base cost or legacy weight tiers',
    () {
      final tariff = UserDeliveryTariff.fromJson({
        'pricingType': 'density',
        'baseCost': 55,
        'weightTiers': [
          {'minWeight': 0, 'pricePerKg': 0.5},
        ],
        'densityTiers': [
          {'minDensity': 0, 'maxDensity': 200},
        ],
      });
      expect(tariff.densityTiers.single.price, isNull);
      expect(tariff.minimumDensityPricePerKg, isNull);
      expect(tariff.minimumDensityPricePerM3, isNull);
    },
  );

  test(
    'invalid or nonfinite optional prices remain unavailable rather than invented zero',
    () {
      for (final value in ['', 'invalid', 'NaN', double.infinity]) {
        final tier = UserDensityTier.fromJson({
          'minDensity': 0,
          'clientPricePerM3': value,
        });
        expect(tier.clientPricePerM3, isNull);
        expect(tier.price, isNull);
      }
    },
  );
}
