import 'package:flutter_test/flutter_test.dart';
import 'package:twoalogisticcabineuser/src/features/sp_finance/data/sp_organizer_calculation_models.dart';

void main() {
  test('draft profile input serializes full safe profile deterministically', () {
    const input = SpOrganizerCalculationProfileInput(
      scope: 'client',
      currency: 'RUB',
      cnyRubRate: 13.25,
      deliveryCnyRubRate: 13.4,
      usdRubRate: 92,
      pricePerKg: 5.5,
      pricePerKgCurrency: 'CNY',
      packingAmount: 10,
      packingCurrency: 'USD',
      insuranceMode: 'percent',
      insurancePercent: 2.5,
      domesticDeliveryAmount: 20,
      domesticDeliveryCurrency: 'CNY',
      additionalExpensesAmount: 30,
      additionalExpensesCurrency: 'RUB',
      commissionMode: 'percent',
      commissionPercent: 5,
      commissionBase: 'total',
    );

    expect(input.toJson(), {
      'scope': 'client',
      'currency': 'RUB',
      'cnyRubRate': 13.25,
      'deliveryCnyRubRate': 13.4,
      'usdRubRate': 92,
      'pricePerKg': 5.5,
      'pricePerKgCurrency': 'CNY',
      'packingAmount': 10,
      'packingCurrency': 'USD',
      'parcelWeightKg': null,
      'insuranceMode': 'percent',
      'insurancePercent': 2.5,
      'insuranceFixedAmount': null,
      'insuranceFixedCurrency': null,
      'domesticDeliveryAmount': 20,
      'domesticDeliveryCurrency': 'CNY',
      'additionalExpensesAmount': 30,
      'additionalExpensesCurrency': 'RUB',
      'commissionMode': 'percent',
      'commissionPercent': 5,
      'commissionFixedAmount': null,
      'commissionBase': 'total',
    });
    expect(
      input.signature,
      'client:RUB:13.250000:13.400000:92.000000:5.500000:CNY:10.000000:USD::percent:2.500000:::20.000000:CNY:30.000000:RUB:percent:5.000000::total',
    );
  });

  test(
    'self profile keeps parcel weight and never sends client commission',
    () {
      const input = SpOrganizerCalculationProfileInput(
        scope: 'self',
        currency: 'CNY',
        cnyRubRate: 12.2,
        usdRubRate: 87,
        pricePerKg: 3.4,
        pricePerKgCurrency: 'USD',
        parcelWeightKg: 0.15,
        commissionMode: 'percent',
        commissionPercent: 8,
        commissionBase: 'total',
      );

      expect(input.toJson()['parcelWeightKg'], 0.15);
      expect(input.toJson()['commissionMode'], isNull);
      expect(input.toJson()['commissionPercent'], isNull);
      expect(input.toJson()['commissionBase'], isNull);
      expect(input.toJson(includeScope: false), isNot(contains('scope')));
    },
  );

  test(
    'server calculation preview keeps participant and 2A money separate',
    () {
      final preview = SpOrganizerCalculationPreview.fromJson({
        'contractVersion': 2,
        'engine': 'legacy_v1_shadow',
        'mode': 'preview',
        'persisted': false,
        'inputHash': 'abc123',
        'effectiveProfile': {
          'source': 'legacy',
          'scope': 'client',
          'currency': 'CNY',
          'cnyRubRate': '12.5000',
          'deliveryCnyRubRate': '12.7',
          'usdRubRate': '91.5',
          'pricePerKg': '5.4',
          'pricePerKgCurrency': 'CNY',
          'packingAmount': '20',
          'insuranceMode': 'percent',
          'insurancePercent': '2.5',
          'domesticDeliveryAmount': '15',
          'commissionMode': 'fixed',
          'commissionFixedAmount': '100',
        },
        'effectiveProfiles': {
          'self': {
            'source': 'profile',
            'scope': 'self',
            'currency': 'CNY',
            'cnyRubRate': '12.2',
            'usdRubRate': '87',
            'pricePerKg': '3.4',
            'pricePerKgCurrency': 'USD',
            'packingAmount': '15',
            'packingCurrency': 'CNY',
            'parcelWeightKg': '0.15',
            'additionalExpensesAmount': '20',
            'additionalExpensesCurrency': 'RUB',
          },
          'client': {
            'source': 'profile',
            'scope': 'client',
            'currency': 'CNY',
            'cnyRubRate': '12.5',
            'commissionMode': 'percent',
            'commissionPercent': '5',
            'commissionBase': 'total',
          },
        },
        'referencePreview': {
          'contractVersion': 2,
          'mode': 'read_only',
          'persisted': false,
          'allocationApplied': false,
          'complete': false,
          'self': {
            'scope': 'self',
            'complete': true,
            'goodsRub': 244,
            'weightKg': 0.15,
            'internationalDeliveryRub': 44.37,
            'packingRub': 186,
            'insuranceRub': 3.66,
            'domesticDeliveryRub': 100,
            'additionalExpensesRub': 248,
            'commissionRub': 0,
            'totalRub': 826.03,
            'missingRequirements': <String>[],
          },
          'client': {
            'scope': 'client',
            'complete': false,
            'goodsRub': 405,
            'weightKg': 0,
            'internationalDeliveryRub': 0,
            'packingRub': 920,
            'insuranceRub': 4600,
            'domesticDeliveryRub': 274,
            'additionalExpensesRub': 25,
            'commissionRub': 311.2,
            'totalRub': 6535.2,
            'missingRequirements': ['client_weight'],
          },
          'expectedProfitRub': 5709.17,
          'allocation': {
            'method': 'owned_goods_and_weight',
            'rounding': 'largest_remainder_by_sp_customer_id',
            'persisted': false,
            'applied': false,
            'ledgerPosted': true,
            'complete': false,
            'totalsMatch': true,
            'allocatedSelfRub': 826.03,
            'allocatedClientRub': 6535.2,
            'participants': [
              {
                'spCustomerId': 7,
                'displayName': 'Анна',
                'isOrganizerSelf': false,
                'itemsCount': 2,
                'self': {
                  'goodsRub': 244,
                  'internationalDeliveryRub': 44.37,
                  'packingRub': 186,
                  'insuranceRub': 3.66,
                  'domesticDeliveryRub': 100,
                  'additionalExpensesRub': 248,
                  'commissionRub': 0,
                  'totalRub': 826.03,
                },
                'client': {
                  'goodsRub': 405,
                  'internationalDeliveryRub': 0,
                  'packingRub': 920,
                  'insuranceRub': 4600,
                  'domesticDeliveryRub': 274,
                  'additionalExpensesRub': 25,
                  'commissionRub': 311.2,
                  'totalRub': 6535.2,
                },
                'expectedProfitRub': 5709.17,
              },
            ],
          },
        },
        'postedAllocation': {
          'id': 21,
          'version': 1,
          'appliedSnapshotId': 11,
          'supersedesPostingId': null,
          'inputHash': 'abc123',
          'createdAt': '2026-07-27T11:00:00.000Z',
          'stale': false,
          'legacyPaymentsApplied': false,
          'totalSelfRub': 826.03,
          'totalDueRub': 6535.2,
          'totalPaidRub': 0,
          'balanceRub': 6535.2,
          'expectedProfitRub': 5709.17,
          'participants': [
            {
              'spCustomerId': 7,
              'displayName': 'Анна',
              'isOrganizerSelf': false,
              'itemsCount': 2,
              'selfRub': 826.03,
              'dueRub': 6535.2,
              'paidRub': 0,
              'balanceRub': 6535.2,
              'expectedProfitRub': 5709.17,
            },
          ],
        },
        'summary': {
          'customersCount': 2,
          'itemsCount': 3,
          'goodsDueRub': 900,
          'goodsPaidRub': 400,
          'deliveryDueRub': 120,
          'deliveryPaidRub': 20,
          'extraDueRub': 30,
          'extraPaidRub': 0,
          'totalDueRub': 1050,
          'paidRub': 420,
          'totalProfitRub': 215,
        },
        'participants': [
          {
            'spCustomerId': '7',
            'displayName': 'Анна',
            'isOrganizerSelf': false,
            'itemsCount': 2,
            'totalDueRub': 700,
            'paidRub': 400,
            'balanceRub': 300,
          },
        ],
        'allocation': {'unallocatedExpensesRub': '30', 'unassignedPaidRub': 5},
        'organizerTo2A': {
          'available': true,
          'linked': true,
          'amountRub': 2355,
          'reason': null,
          'financialScope': 'explicit_linked_2a_obligations',
          'affectsParticipantDebt': false,
          'affectsLegacyProfit': false,
          'mayContainOverlaps': true,
          'stale': false,
          'breakdown': {
            'selfBuyoutRub': 1300,
            'garageRub': 715,
            'invoicesRub': 340,
          },
          'actualizedSnapshot': {
            'id': 12,
            'version': 2,
            'mode': 'actualized',
            'inputHash': 'actualized-hash',
            'createdAt': '2026-07-27T10:00:00.000Z',
          },
        },
        'shadowComparison': {
          'matchesLegacy': false,
          'totalDueDeltaRub': '45',
          'paidDeltaRub': 0,
          'profitDeltaRub': 15,
        },
        'latestSnapshot': {
          'id': 12,
          'version': 2,
          'mode': 'actualized',
          'inputHash': 'actualized-hash',
        },
        'latestAppliedSnapshot': {
          'id': 11,
          'version': 1,
          'mode': 'applied',
          'inputHash': 'abc123',
        },
        'currentAppliedSnapshot': {
          'id': 11,
          'version': 1,
          'mode': 'applied',
          'inputHash': 'abc123',
        },
        'latestActualizedSnapshot': {
          'id': 12,
          'version': 2,
          'mode': 'actualized',
          'inputHash': 'actualized-hash',
        },
        'applyState': {
          'canApply': false,
          'alreadyApplied': true,
          'blockingWarnings': <String>[],
        },
        'postingState': {
          'canPost': false,
          'alreadyPosted': true,
          'requiresApply': false,
        },
        'actualizeState': {'canActualize': true, 'needsRefresh': false},
        'warnings': [
          'organizer_2a_obligation_not_linked',
          'unallocated_purchase_expenses',
        ],
      });

      expect(preview.persisted, isFalse);
      expect(preview.summary.balanceRub, 630);
      expect(preview.effectiveProfile.usesLegacyFallback, isTrue);
      expect(preview.effectiveProfile.cnyRubRate, 12.5);
      expect(preview.effectiveProfile.deliveryCnyRubRate, 12.7);
      expect(preview.effectiveProfile.usdRubRate, 91.5);
      expect(preview.effectiveProfile.pricePerKg, 5.4);
      expect(preview.effectiveProfile.insurancePercent, 2.5);
      expect(preview.effectiveProfile.commissionFixedAmount, 100);
      expect(preview.effectiveSelfProfile?.scope, 'self');
      expect(preview.effectiveSelfProfile?.parcelWeightKg, 0.15);
      expect(preview.effectiveSelfProfile?.packingCurrency, 'CNY');
      expect(preview.effectiveSelfProfile?.additionalExpensesAmount, 20);
      expect(preview.effectiveClientProfile?.scope, 'client');
      expect(preview.effectiveClientProfile?.commissionBase, 'total');
      expect(preview.referencePreview?.persisted, isFalse);
      expect(preview.referencePreview?.allocationApplied, isFalse);
      expect(preview.referencePreview?.complete, isFalse);
      expect(preview.referencePreview?.self.totalRub, 826.03);
      expect(preview.referencePreview?.client.commissionRub, 311.2);
      expect(preview.referencePreview?.client.missingRequirements, [
        'client_weight',
      ]);
      expect(preview.referencePreview?.expectedProfitRub, 5709.17);
      expect(
        preview.referencePreview?.allocation?.method,
        'owned_goods_and_weight',
      );
      expect(preview.referencePreview?.allocation?.persisted, isFalse);
      expect(preview.referencePreview?.allocation?.applied, isFalse);
      expect(preview.referencePreview?.allocation?.ledgerPosted, isTrue);
      expect(preview.referencePreview?.allocation?.totalsMatch, isTrue);
      expect(
        preview.referencePreview?.allocation?.participants.single.displayName,
        'Анна',
      );
      expect(
        preview
            .referencePreview
            ?.allocation
            ?.participants
            .single
            .client
            .totalRub,
        6535.2,
      );
      expect(preview.postedAllocation?.version, 1);
      expect(preview.postedAllocation?.legacyPaymentsApplied, isFalse);
      expect(preview.postedAllocation?.totalPaidRub, 0);
      expect(preview.postedAllocation?.balanceRub, 6535.2);
      expect(preview.postedAllocation?.participants.single.paidRub, 0);
      expect(preview.postedAllocation?.participants.single.balanceRub, 6535.2);
      expect(preview.participants.single.spCustomerId, 7);
      expect(preview.participants.single.balanceRub, 300);
      expect(preview.unallocatedExpensesRub, 30);
      expect(preview.unassignedPaidRub, 5);
      expect(preview.organizerTo2A.available, isTrue);
      expect(preview.organizerTo2A.amountRub, 2355);
      expect(preview.organizerTo2A.breakdown.selfBuyoutRub, 1300);
      expect(preview.organizerTo2A.breakdown.garageRub, 715);
      expect(preview.organizerTo2A.breakdown.invoicesRub, 340);
      expect(preview.organizerTo2A.mayContainOverlaps, isTrue);
      expect(preview.organizerTo2A.affectsParticipantDebt, isFalse);
      expect(preview.matchesLegacy, isFalse);
      expect(preview.totalDueDeltaRub, 45);
      expect(preview.paidDeltaRub, 0);
      expect(preview.profitDeltaRub, 15);
      expect(preview.latestSnapshot?.version, 2);
      expect(preview.currentAppliedSnapshot?.id, 11);
      expect(preview.latestActualizedSnapshot?.id, 12);
      expect(preview.calculationAlreadyApplied, isTrue);
      expect(preview.canApplyCalculation, isFalse);
      expect(preview.canPostAllocation, isFalse);
      expect(preview.allocationAlreadyPosted, isTrue);
      expect(preview.postingRequiresApply, isFalse);
      expect(preview.canActualizeCalculation, isTrue);
    },
  );

  test('missing optional fields fail closed without inventing a snapshot', () {
    final preview = SpOrganizerCalculationPreview.fromJson({});

    expect(preview.persisted, isFalse);
    expect(preview.participants, isEmpty);
    expect(preview.organizerTo2A.available, isFalse);
    expect(preview.latestSnapshot, isNull);
    expect(preview.summary.totalDueRub, 0);
  });

  test('calculation action parses immutable snapshot and 2A result', () {
    final action = SpOrganizerCalculationActionResult.fromJson({
      'created': true,
      'snapshot': {
        'id': 18,
        'version': 3,
        'mode': 'actualized',
        'inputHash': 'hash-18',
      },
      'legacyFieldsUpdated': false,
      'participantLedgerUpdated': false,
      'referenceAllocationPersisted': true,
      'organizerTo2A': {
        'available': true,
        'linked': true,
        'amountRub': '2365.00',
        'breakdown': {
          'selfBuyoutRub': 1310,
          'garageRub': 715,
          'invoicesRub': 340,
        },
      },
      'warnings': ['possible_cross_source_overlap'],
    });

    expect(action.created, isTrue);
    expect(action.snapshot.version, 3);
    expect(action.legacyFieldsUpdated, isFalse);
    expect(action.participantLedgerUpdated, isFalse);
    expect(action.referenceAllocationPersisted, isTrue);
    expect(action.organizerTo2A?.amountRub, 2365);
    expect(action.organizerTo2A?.breakdown.garageRub, 715);
    expect(action.warnings, contains('possible_cross_source_overlap'));
  });

  test('allocation posting stays separate from legacy payments', () {
    final action = SpOrganizerAllocationPostingActionResult.fromJson({
      'created': true,
      'posting': {
        'id': 22,
        'version': 2,
        'appliedSnapshotId': 19,
        'supersedesPostingId': 21,
        'inputHash': 'hash-19',
        'createdAt': '2026-07-27T12:00:00.000Z',
        'stale': false,
        'legacyPaymentsApplied': false,
        'totalSelfRub': 800,
        'totalDueRub': 1250,
        'totalPaidRub': 0,
        'balanceRub': 1250,
        'expectedProfitRub': 450,
        'participants': [
          {
            'spCustomerId': 7,
            'displayName': 'Анна',
            'isOrganizerSelf': false,
            'itemsCount': 2,
            'selfRub': 800,
            'dueRub': 1250,
            'paidRub': 0,
            'balanceRub': 1250,
            'expectedProfitRub': 450,
          },
        ],
      },
      'legacyFieldsUpdated': false,
      'participantLedgerUpdated': false,
      'newAllocationLedgerUpdated': true,
    });

    expect(action.created, isTrue);
    expect(action.posting.version, 2);
    expect(action.posting.legacyPaymentsApplied, isFalse);
    expect(action.posting.totalPaidRub, 0);
    expect(action.posting.balanceRub, 1250);
    expect(action.posting.participants.single.paidRub, 0);
    expect(action.legacyFieldsUpdated, isFalse);
    expect(action.participantLedgerUpdated, isFalse);
    expect(action.newAllocationLedgerUpdated, isTrue);
  });
}
