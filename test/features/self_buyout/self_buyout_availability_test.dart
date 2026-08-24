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

  test('availability parses first Alipay exchange answer and maximum', () {
    final availability = SelfBuyoutAvailability.fromJson({
      'available': true,
      'limits': {'minCny': 100, 'maxCny': 1000},
      'firstExchange': {
        'active': true,
        'showOnboarding': true,
        'alipayTopUpExperienced': false,
        'requiresAlipayExperienceAnswer': false,
        'inexperiencedMaxCny': 1000,
      },
    });

    expect(availability.firstExchangeActive, isTrue);
    expect(availability.showFirstExchangeOnboarding, isTrue);
    expect(availability.alipayTopUpExperienced, isFalse);
    expect(availability.requiresAlipayExperienceAnswer, isFalse);
    expect(availability.maxCny, 1000);
    expect(availability.firstExchangeInexperiencedMaxCny, 1000);
  });

  test('availability parses exchange operator sleep status', () {
    final availability = SelfBuyoutAvailability.fromJson({
      'available': true,
      'operatorStatus': {
        'sleeping': false,
        'working': true,
        'reachable': true,
        'updatedAt': '2026-07-24T11:59:00.000Z',
        'checkedAt': '2026-07-24T12:00:00.000Z',
      },
    });

    expect(availability.operatorSleeping, isFalse);
    expect(availability.operatorWorking, isTrue);
    expect(availability.operatorStatusReachable, isTrue);
    expect(
      availability.operatorStatusUpdatedAt,
      DateTime.parse('2026-07-24T11:59:00.000Z'),
    );
    expect(
      availability.operatorStatusCheckedAt,
      DateTime.parse('2026-07-24T12:00:00.000Z'),
    );
  });

  test('availability tolerates unavailable operator status', () {
    final availability = SelfBuyoutAvailability.fromJson({
      'available': true,
      'operatorStatus': {
        'sleeping': null,
        'working': null,
        'reachable': false,
        'updatedAt': null,
        'checkedAt': '2026-07-24T12:00:00.000Z',
      },
    });

    expect(availability.available, isTrue);
    expect(availability.operatorSleeping, isNull);
    expect(availability.operatorWorking, isTrue);
    expect(availability.operatorStatusReachable, isFalse);
  });

  test('availability parses required self-buyout verification', () {
    final availability = SelfBuyoutAvailability.fromJson({
      'available': false,
      'reason': 'verification_rejected',
      'verification': {
        'required': true,
        'status': 'rejected',
        'verificationId': 42,
        'requestVersion': 2,
        'submittedAt': '2026-07-26T01:00:00.000Z',
        'decidedAt': '2026-07-26T02:00:00.000Z',
        'decisionSource': 'partner_api',
        'rejectionReason': 'Не удалось подтвердить клиента',
        'canSubmit': true,
        'contact': {
          'fullName': 'Иванов Иван',
          'phone': '+79991234567',
          'telegram': '@ivanov',
        },
      },
    });

    expect(availability.verification.required, isTrue);
    expect(availability.verification.isRejected, isTrue);
    expect(availability.verification.canSubmit, isTrue);
    expect(availability.verification.verificationId, 42);
    expect(availability.verification.requestVersion, 2);
    expect(
      availability.verification.rejectionReason,
      'Не удалось подтвердить клиента',
    );
    expect(availability.verification.contact.fullName, 'Иванов Иван');
    expect(availability.verification.contact.phone, '+79991234567');
    expect(availability.verification.contact.telegram, '@ivanov');
  });

  test('legacy availability without verification remains compatible', () {
    final availability = SelfBuyoutAvailability.fromJson({'available': true});

    expect(availability.verification.required, isFalse);
    expect(availability.verification.status, 'not_required');
    expect(availability.verification.isApproved, isTrue);
  });
}
