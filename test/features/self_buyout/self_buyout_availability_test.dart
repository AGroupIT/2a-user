import 'package:flutter_test/flutter_test.dart';
import 'package:twoalogisticcabineuser/src/features/self_buyout/data/self_buyout_models.dart';

void main() {
  test('availability parses minimum in CNY and has no upper limit', () {
    final availability = SelfBuyoutAvailability.fromJson({
      'available': true,
      'rate': {'clientCnyRubRate': 12.5},
      'limits': {'minCny': 100, 'maxCny': null},
    });

    expect(availability.minCny, 100);
    expect(availability.isBelowMinimum(99.99), isTrue);
    expect(availability.isBelowMinimum(100), isFalse);
    expect(availability.isBelowMinimum(1000000), isFalse);
  });

  test('availability supports legacy RUB minimum during staggered rollout', () {
    final availability = SelfBuyoutAvailability.fromJson({
      'available': true,
      'rate': {'clientCnyRubRate': 10},
      'limits': {'minRub': 1000},
    });

    expect(availability.minCny, 100);
  });
}
