Map<String, dynamic> _mapValue(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : const {};

List<Map<String, dynamic>> _mapList(dynamic value) => value is List
    ? value
          .whereType<Map>()
          .map(Map<String, dynamic>.from)
          .toList(growable: false)
    : const [];

String? _stringValue(dynamic value) {
  if (value is! String) return null;
  final normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}

int _intValue(dynamic value, [int fallback = 0]) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

double _doubleValue(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.replaceAll(',', '.')) ?? 0;
  return 0;
}

bool _boolValue(dynamic value, [bool fallback = false]) =>
    value is bool ? value : fallback;

DateTime? _dateValue(dynamic value) =>
    value is String ? DateTime.tryParse(value) : null;

class SpOrganizerCalculationProfile {
  final String source;
  final int? profileId;
  final String scope;
  final String currency;
  final double? cnyRubRate;
  final double? deliveryCnyRubRate;
  final double? usdRubRate;
  final double? pricePerKg;
  final String? pricePerKgCurrency;
  final double? packingAmount;
  final String? packingCurrency;
  final double? parcelWeightKg;
  final String? insuranceMode;
  final double? insurancePercent;
  final double? insuranceFixedAmount;
  final String? insuranceFixedCurrency;
  final double? domesticDeliveryAmount;
  final String? domesticDeliveryCurrency;
  final double? additionalExpensesAmount;
  final String? additionalExpensesCurrency;
  final String? commissionMode;
  final double? commissionPercent;
  final double? commissionFixedAmount;
  final String? commissionBase;

  const SpOrganizerCalculationProfile({
    required this.source,
    this.profileId,
    required this.scope,
    required this.currency,
    this.cnyRubRate,
    this.deliveryCnyRubRate,
    this.usdRubRate,
    this.pricePerKg,
    this.pricePerKgCurrency,
    this.packingAmount,
    this.packingCurrency,
    this.parcelWeightKg,
    this.insuranceMode,
    this.insurancePercent,
    this.insuranceFixedAmount,
    this.insuranceFixedCurrency,
    this.domesticDeliveryAmount,
    this.domesticDeliveryCurrency,
    this.additionalExpensesAmount,
    this.additionalExpensesCurrency,
    this.commissionMode,
    this.commissionPercent,
    this.commissionFixedAmount,
    this.commissionBase,
  });

  bool get usesLegacyFallback => source == 'legacy';

  factory SpOrganizerCalculationProfile.fromJson(Map<String, dynamic> json) {
    final rate = _stringValue(json['cnyRubRate']);
    return SpOrganizerCalculationProfile(
      source: _stringValue(json['source']) ?? 'legacy',
      profileId: json['profileId'] == null
          ? null
          : _intValue(json['profileId']),
      scope: _stringValue(json['scope']) ?? 'client',
      currency: _stringValue(json['currency']) ?? 'CNY',
      cnyRubRate: rate == null ? null : _doubleValue(rate),
      deliveryCnyRubRate: json['deliveryCnyRubRate'] == null
          ? null
          : _doubleValue(json['deliveryCnyRubRate']),
      usdRubRate: json['usdRubRate'] == null
          ? null
          : _doubleValue(json['usdRubRate']),
      pricePerKg: json['pricePerKg'] == null
          ? null
          : _doubleValue(json['pricePerKg']),
      pricePerKgCurrency: _stringValue(json['pricePerKgCurrency']),
      packingAmount: json['packingAmount'] == null
          ? null
          : _doubleValue(json['packingAmount']),
      packingCurrency: _stringValue(json['packingCurrency']),
      parcelWeightKg: json['parcelWeightKg'] == null
          ? null
          : _doubleValue(json['parcelWeightKg']),
      insuranceMode: _stringValue(json['insuranceMode']),
      insurancePercent: json['insurancePercent'] == null
          ? null
          : _doubleValue(json['insurancePercent']),
      insuranceFixedAmount: json['insuranceFixedAmount'] == null
          ? null
          : _doubleValue(json['insuranceFixedAmount']),
      insuranceFixedCurrency: _stringValue(json['insuranceFixedCurrency']),
      domesticDeliveryAmount: json['domesticDeliveryAmount'] == null
          ? null
          : _doubleValue(json['domesticDeliveryAmount']),
      domesticDeliveryCurrency: _stringValue(json['domesticDeliveryCurrency']),
      additionalExpensesAmount: json['additionalExpensesAmount'] == null
          ? null
          : _doubleValue(json['additionalExpensesAmount']),
      additionalExpensesCurrency: _stringValue(
        json['additionalExpensesCurrency'],
      ),
      commissionMode: _stringValue(json['commissionMode']),
      commissionPercent: json['commissionPercent'] == null
          ? null
          : _doubleValue(json['commissionPercent']),
      commissionFixedAmount: json['commissionFixedAmount'] == null
          ? null
          : _doubleValue(json['commissionFixedAmount']),
      commissionBase: _stringValue(json['commissionBase']),
    );
  }
}

class SpOrganizerCalculationProfileInput {
  final String scope;
  final String currency;
  final double cnyRubRate;
  final double? deliveryCnyRubRate;
  final double? usdRubRate;
  final double? pricePerKg;
  final String? pricePerKgCurrency;
  final double? packingAmount;
  final String? packingCurrency;
  final double? parcelWeightKg;
  final String insuranceMode;
  final double? insurancePercent;
  final double? insuranceFixedAmount;
  final String? insuranceFixedCurrency;
  final double? domesticDeliveryAmount;
  final String? domesticDeliveryCurrency;
  final double? additionalExpensesAmount;
  final String? additionalExpensesCurrency;
  final String commissionMode;
  final double? commissionPercent;
  final double? commissionFixedAmount;
  final String? commissionBase;

  const SpOrganizerCalculationProfileInput({
    this.scope = 'client',
    required this.currency,
    required this.cnyRubRate,
    this.deliveryCnyRubRate,
    this.usdRubRate,
    this.pricePerKg,
    this.pricePerKgCurrency,
    this.packingAmount,
    this.packingCurrency,
    this.parcelWeightKg,
    this.insuranceMode = 'none',
    this.insurancePercent,
    this.insuranceFixedAmount,
    this.insuranceFixedCurrency,
    this.domesticDeliveryAmount,
    this.domesticDeliveryCurrency,
    this.additionalExpensesAmount,
    this.additionalExpensesCurrency,
    this.commissionMode = 'hidden_margin',
    this.commissionPercent,
    this.commissionFixedAmount,
    this.commissionBase,
  });

  Map<String, dynamic> toJson({bool includeScope = true}) => {
    if (includeScope) 'scope': scope,
    'currency': currency,
    'cnyRubRate': cnyRubRate,
    'deliveryCnyRubRate': deliveryCnyRubRate,
    'usdRubRate': usdRubRate,
    'pricePerKg': pricePerKg,
    'pricePerKgCurrency': pricePerKgCurrency,
    'packingAmount': packingAmount,
    'packingCurrency': packingAmount == null
        ? null
        : packingCurrency ?? currency,
    'parcelWeightKg': scope == 'self' ? parcelWeightKg : null,
    'insuranceMode': insuranceMode,
    'insurancePercent': insuranceMode == 'percent' ? insurancePercent : null,
    'insuranceFixedAmount': insuranceMode == 'fixed'
        ? insuranceFixedAmount
        : null,
    'insuranceFixedCurrency': insuranceMode == 'fixed'
        ? insuranceFixedCurrency ?? currency
        : null,
    'domesticDeliveryAmount': domesticDeliveryAmount,
    'domesticDeliveryCurrency': domesticDeliveryAmount == null
        ? null
        : domesticDeliveryCurrency ?? currency,
    'additionalExpensesAmount': additionalExpensesAmount,
    'additionalExpensesCurrency': additionalExpensesAmount == null
        ? null
        : additionalExpensesCurrency ?? currency,
    'commissionMode': scope == 'client' ? commissionMode : null,
    'commissionPercent': scope == 'client' && commissionMode == 'percent'
        ? commissionPercent
        : null,
    'commissionFixedAmount': scope == 'client' && commissionMode == 'fixed'
        ? commissionFixedAmount
        : null,
    'commissionBase': scope == 'client' && commissionMode == 'percent'
        ? commissionBase ?? 'goods'
        : null,
  };

  String get signature => [
    scope,
    currency,
    _signatureNumber(cnyRubRate),
    _signatureNumber(deliveryCnyRubRate),
    _signatureNumber(usdRubRate),
    _signatureNumber(pricePerKg),
    pricePerKgCurrency ?? '',
    _signatureNumber(packingAmount),
    packingCurrency ?? '',
    _signatureNumber(parcelWeightKg),
    insuranceMode,
    _signatureNumber(insurancePercent),
    _signatureNumber(insuranceFixedAmount),
    insuranceFixedCurrency ?? '',
    _signatureNumber(domesticDeliveryAmount),
    domesticDeliveryCurrency ?? '',
    _signatureNumber(additionalExpensesAmount),
    additionalExpensesCurrency ?? '',
    commissionMode,
    _signatureNumber(commissionPercent),
    _signatureNumber(commissionFixedAmount),
    commissionBase ?? '',
  ].join(':');
}

String _signatureNumber(double? value) =>
    value == null ? '' : value.toStringAsFixed(6);

class SpOrganizerCalculationSummary {
  final int participantsCount;
  final int itemsCount;
  final double goodsDueRub;
  final double goodsPaidRub;
  final double deliveryDueRub;
  final double deliveryPaidRub;
  final double extraDueRub;
  final double extraPaidRub;
  final double totalDueRub;
  final double paidRub;
  final double totalProfitRub;

  const SpOrganizerCalculationSummary({
    required this.participantsCount,
    required this.itemsCount,
    required this.goodsDueRub,
    required this.goodsPaidRub,
    required this.deliveryDueRub,
    required this.deliveryPaidRub,
    required this.extraDueRub,
    required this.extraPaidRub,
    required this.totalDueRub,
    required this.paidRub,
    required this.totalProfitRub,
  });

  double get balanceRub => totalDueRub - paidRub;

  factory SpOrganizerCalculationSummary.fromJson(Map<String, dynamic> json) {
    return SpOrganizerCalculationSummary(
      participantsCount: _intValue(json['customersCount']),
      itemsCount: _intValue(json['itemsCount']),
      goodsDueRub: _doubleValue(json['goodsDueRub']),
      goodsPaidRub: _doubleValue(json['goodsPaidRub']),
      deliveryDueRub: _doubleValue(json['deliveryDueRub']),
      deliveryPaidRub: _doubleValue(json['deliveryPaidRub']),
      extraDueRub: _doubleValue(json['extraDueRub']),
      extraPaidRub: _doubleValue(json['extraPaidRub']),
      totalDueRub: _doubleValue(json['totalDueRub']),
      paidRub: _doubleValue(json['paidRub']),
      totalProfitRub: _doubleValue(json['totalProfitRub']),
    );
  }
}

class SpOrganizerParticipantCalculation {
  final int spCustomerId;
  final String displayName;
  final bool isOrganizerSelf;
  final int itemsCount;
  final double totalDueRub;
  final double paidRub;
  final double balanceRub;

  const SpOrganizerParticipantCalculation({
    required this.spCustomerId,
    required this.displayName,
    required this.isOrganizerSelf,
    required this.itemsCount,
    required this.totalDueRub,
    required this.paidRub,
    required this.balanceRub,
  });

  factory SpOrganizerParticipantCalculation.fromJson(
    Map<String, dynamic> json,
  ) {
    return SpOrganizerParticipantCalculation(
      spCustomerId: _intValue(json['spCustomerId']),
      displayName:
          _stringValue(json['displayName']) ??
          'Участник #${_intValue(json['spCustomerId'])}',
      isOrganizerSelf: _boolValue(json['isOrganizerSelf']),
      itemsCount: _intValue(json['itemsCount']),
      totalDueRub: _doubleValue(json['totalDueRub']),
      paidRub: _doubleValue(json['paidRub']),
      balanceRub: _doubleValue(json['balanceRub']),
    );
  }
}

class SpOrganizerTo2AObligation {
  final bool available;
  final bool linked;
  final double? amountRub;
  final String? reason;
  final String financialScope;
  final bool affectsParticipantDebt;
  final bool affectsLegacyProfit;
  final bool mayContainOverlaps;
  final bool stale;
  final SpOrganizerTo2ABreakdown breakdown;
  final SpOrganizerCalculationSnapshotSummary? actualizedSnapshot;

  const SpOrganizerTo2AObligation({
    required this.available,
    required this.linked,
    this.amountRub,
    this.reason,
    this.financialScope = 'explicit_linked_2a_obligations',
    this.affectsParticipantDebt = false,
    this.affectsLegacyProfit = false,
    this.mayContainOverlaps = false,
    this.stale = false,
    this.breakdown = const SpOrganizerTo2ABreakdown(),
    this.actualizedSnapshot,
  });

  factory SpOrganizerTo2AObligation.fromJson(Map<String, dynamic> json) {
    return SpOrganizerTo2AObligation(
      available: _boolValue(json['available']),
      linked: _boolValue(json['linked']),
      amountRub: json['amountRub'] == null
          ? null
          : _doubleValue(json['amountRub']),
      reason: _stringValue(json['reason']),
      financialScope:
          _stringValue(json['financialScope']) ??
          'explicit_linked_2a_obligations',
      affectsParticipantDebt: _boolValue(json['affectsParticipantDebt']),
      affectsLegacyProfit: _boolValue(json['affectsLegacyProfit']),
      mayContainOverlaps: _boolValue(json['mayContainOverlaps']),
      stale: _boolValue(json['stale']),
      breakdown: SpOrganizerTo2ABreakdown.fromJson(
        _mapValue(json['breakdown']),
      ),
      actualizedSnapshot: json['actualizedSnapshot'] is Map
          ? SpOrganizerCalculationSnapshotSummary.fromJson(
              _mapValue(json['actualizedSnapshot']),
            )
          : null,
    );
  }
}

class SpOrganizerTo2ABreakdown {
  final double selfBuyoutRub;
  final double garageRub;
  final double invoicesRub;

  const SpOrganizerTo2ABreakdown({
    this.selfBuyoutRub = 0,
    this.garageRub = 0,
    this.invoicesRub = 0,
  });

  factory SpOrganizerTo2ABreakdown.fromJson(Map<String, dynamic> json) {
    return SpOrganizerTo2ABreakdown(
      selfBuyoutRub: _doubleValue(json['selfBuyoutRub']),
      garageRub: _doubleValue(json['garageRub']),
      invoicesRub: _doubleValue(json['invoicesRub']),
    );
  }
}

class SpOrganizerCalculationSnapshotSummary {
  final int id;
  final int version;
  final String mode;
  final String inputHash;
  final DateTime? createdAt;

  const SpOrganizerCalculationSnapshotSummary({
    required this.id,
    required this.version,
    required this.mode,
    required this.inputHash,
    this.createdAt,
  });

  factory SpOrganizerCalculationSnapshotSummary.fromJson(
    Map<String, dynamic> json,
  ) {
    return SpOrganizerCalculationSnapshotSummary(
      id: _intValue(json['id']),
      version: _intValue(json['version']),
      mode: _stringValue(json['mode']) ?? 'preview',
      inputHash: _stringValue(json['inputHash']) ?? '',
      createdAt: _dateValue(json['createdAt']),
    );
  }
}

class SpOrganizerReferenceCalculationScope {
  final String scope;
  final bool complete;
  final double goodsRub;
  final double weightKg;
  final double internationalDeliveryRub;
  final double packingRub;
  final double insuranceRub;
  final double domesticDeliveryRub;
  final double additionalExpensesRub;
  final double commissionRub;
  final double totalRub;
  final List<String> missingRequirements;

  const SpOrganizerReferenceCalculationScope({
    required this.scope,
    required this.complete,
    required this.goodsRub,
    required this.weightKg,
    required this.internationalDeliveryRub,
    required this.packingRub,
    required this.insuranceRub,
    required this.domesticDeliveryRub,
    required this.additionalExpensesRub,
    required this.commissionRub,
    required this.totalRub,
    this.missingRequirements = const [],
  });

  factory SpOrganizerReferenceCalculationScope.fromJson(
    Map<String, dynamic> json,
  ) {
    return SpOrganizerReferenceCalculationScope(
      scope: _stringValue(json['scope']) ?? 'client',
      complete: _boolValue(json['complete']),
      goodsRub: _doubleValue(json['goodsRub']),
      weightKg: _doubleValue(json['weightKg']),
      internationalDeliveryRub: _doubleValue(json['internationalDeliveryRub']),
      packingRub: _doubleValue(json['packingRub']),
      insuranceRub: _doubleValue(json['insuranceRub']),
      domesticDeliveryRub: _doubleValue(json['domesticDeliveryRub']),
      additionalExpensesRub: _doubleValue(json['additionalExpensesRub']),
      commissionRub: _doubleValue(json['commissionRub']),
      totalRub: _doubleValue(json['totalRub']),
      missingRequirements: json['missingRequirements'] is List
          ? (json['missingRequirements'] as List).whereType<String>().toList(
              growable: false,
            )
          : const [],
    );
  }
}

class SpOrganizerReferenceParticipantScope {
  final double goodsRub;
  final double internationalDeliveryRub;
  final double packingRub;
  final double insuranceRub;
  final double domesticDeliveryRub;
  final double additionalExpensesRub;
  final double commissionRub;
  final double totalRub;

  const SpOrganizerReferenceParticipantScope({
    required this.goodsRub,
    required this.internationalDeliveryRub,
    required this.packingRub,
    required this.insuranceRub,
    required this.domesticDeliveryRub,
    required this.additionalExpensesRub,
    required this.commissionRub,
    required this.totalRub,
  });

  factory SpOrganizerReferenceParticipantScope.fromJson(
    Map<String, dynamic> json,
  ) {
    return SpOrganizerReferenceParticipantScope(
      goodsRub: _doubleValue(json['goodsRub']),
      internationalDeliveryRub: _doubleValue(json['internationalDeliveryRub']),
      packingRub: _doubleValue(json['packingRub']),
      insuranceRub: _doubleValue(json['insuranceRub']),
      domesticDeliveryRub: _doubleValue(json['domesticDeliveryRub']),
      additionalExpensesRub: _doubleValue(json['additionalExpensesRub']),
      commissionRub: _doubleValue(json['commissionRub']),
      totalRub: _doubleValue(json['totalRub']),
    );
  }
}

class SpOrganizerReferenceParticipantAllocation {
  final int spCustomerId;
  final String displayName;
  final bool isOrganizerSelf;
  final int itemsCount;
  final SpOrganizerReferenceParticipantScope self;
  final SpOrganizerReferenceParticipantScope client;
  final double expectedProfitRub;

  const SpOrganizerReferenceParticipantAllocation({
    required this.spCustomerId,
    required this.displayName,
    required this.isOrganizerSelf,
    required this.itemsCount,
    required this.self,
    required this.client,
    required this.expectedProfitRub,
  });

  factory SpOrganizerReferenceParticipantAllocation.fromJson(
    Map<String, dynamic> json,
  ) {
    return SpOrganizerReferenceParticipantAllocation(
      spCustomerId: _intValue(json['spCustomerId']),
      displayName:
          _stringValue(json['displayName']) ??
          'Участник #${_intValue(json['spCustomerId'])}',
      isOrganizerSelf: _boolValue(json['isOrganizerSelf']),
      itemsCount: _intValue(json['itemsCount']),
      self: SpOrganizerReferenceParticipantScope.fromJson(
        _mapValue(json['self']),
      ),
      client: SpOrganizerReferenceParticipantScope.fromJson(
        _mapValue(json['client']),
      ),
      expectedProfitRub: _doubleValue(json['expectedProfitRub']),
    );
  }
}

class SpOrganizerReferenceAllocation {
  final String method;
  final String rounding;
  final bool persisted;
  final bool applied;
  final bool ledgerPosted;
  final bool complete;
  final bool totalsMatch;
  final double allocatedSelfRub;
  final double allocatedClientRub;
  final List<SpOrganizerReferenceParticipantAllocation> participants;

  const SpOrganizerReferenceAllocation({
    required this.method,
    required this.rounding,
    required this.persisted,
    required this.applied,
    this.ledgerPosted = false,
    required this.complete,
    required this.totalsMatch,
    required this.allocatedSelfRub,
    required this.allocatedClientRub,
    this.participants = const [],
  });

  factory SpOrganizerReferenceAllocation.fromJson(Map<String, dynamic> json) {
    return SpOrganizerReferenceAllocation(
      method: _stringValue(json['method']) ?? 'owned_goods_and_weight',
      rounding:
          _stringValue(json['rounding']) ??
          'largest_remainder_by_sp_customer_id',
      persisted: _boolValue(json['persisted']),
      applied: _boolValue(json['applied']),
      ledgerPosted: _boolValue(json['ledgerPosted']),
      complete: _boolValue(json['complete']),
      totalsMatch: _boolValue(json['totalsMatch']),
      allocatedSelfRub: _doubleValue(json['allocatedSelfRub']),
      allocatedClientRub: _doubleValue(json['allocatedClientRub']),
      participants: _mapList(json['participants'])
          .map(SpOrganizerReferenceParticipantAllocation.fromJson)
          .toList(growable: false),
    );
  }
}

class SpOrganizerReferenceCalculationPreview {
  final int contractVersion;
  final String mode;
  final bool persisted;
  final bool allocationApplied;
  final bool complete;
  final SpOrganizerReferenceCalculationScope self;
  final SpOrganizerReferenceCalculationScope client;
  final double expectedProfitRub;
  final SpOrganizerReferenceAllocation? allocation;

  const SpOrganizerReferenceCalculationPreview({
    required this.contractVersion,
    required this.mode,
    required this.persisted,
    required this.allocationApplied,
    required this.complete,
    required this.self,
    required this.client,
    required this.expectedProfitRub,
    this.allocation,
  });

  factory SpOrganizerReferenceCalculationPreview.fromJson(
    Map<String, dynamic> json,
  ) {
    return SpOrganizerReferenceCalculationPreview(
      contractVersion: _intValue(json['contractVersion'], 1),
      mode: _stringValue(json['mode']) ?? 'read_only',
      persisted: _boolValue(json['persisted']),
      allocationApplied: _boolValue(json['allocationApplied']),
      complete: _boolValue(json['complete']),
      self: SpOrganizerReferenceCalculationScope.fromJson(
        _mapValue(json['self']),
      ),
      client: SpOrganizerReferenceCalculationScope.fromJson(
        _mapValue(json['client']),
      ),
      expectedProfitRub: _doubleValue(json['expectedProfitRub']),
      allocation: json['allocation'] is Map
          ? SpOrganizerReferenceAllocation.fromJson(
              _mapValue(json['allocation']),
            )
          : null,
    );
  }
}

class SpOrganizerPostedAllocationParticipant {
  final int spCustomerId;
  final String displayName;
  final bool isOrganizerSelf;
  final int itemsCount;
  final double selfRub;
  final double dueRub;
  final double paidRub;
  final double balanceRub;
  final double expectedProfitRub;

  const SpOrganizerPostedAllocationParticipant({
    required this.spCustomerId,
    required this.displayName,
    required this.isOrganizerSelf,
    required this.itemsCount,
    required this.selfRub,
    required this.dueRub,
    required this.paidRub,
    required this.balanceRub,
    required this.expectedProfitRub,
  });

  factory SpOrganizerPostedAllocationParticipant.fromJson(
    Map<String, dynamic> json,
  ) {
    return SpOrganizerPostedAllocationParticipant(
      spCustomerId: _intValue(json['spCustomerId']),
      displayName:
          _stringValue(json['displayName']) ??
          'Участник #${_intValue(json['spCustomerId'])}',
      isOrganizerSelf: _boolValue(json['isOrganizerSelf']),
      itemsCount: _intValue(json['itemsCount']),
      selfRub: _doubleValue(json['selfRub']),
      dueRub: _doubleValue(json['dueRub']),
      paidRub: _doubleValue(json['paidRub']),
      balanceRub: _doubleValue(json['balanceRub']),
      expectedProfitRub: _doubleValue(json['expectedProfitRub']),
    );
  }
}

class SpOrganizerPostedAllocation {
  final int id;
  final int version;
  final int appliedSnapshotId;
  final int? supersedesPostingId;
  final String inputHash;
  final DateTime? createdAt;
  final bool stale;
  final bool legacyPaymentsApplied;
  final double totalSelfRub;
  final double totalDueRub;
  final double totalPaidRub;
  final double balanceRub;
  final double expectedProfitRub;
  final List<SpOrganizerPostedAllocationParticipant> participants;

  const SpOrganizerPostedAllocation({
    required this.id,
    required this.version,
    required this.appliedSnapshotId,
    this.supersedesPostingId,
    required this.inputHash,
    this.createdAt,
    required this.stale,
    required this.legacyPaymentsApplied,
    required this.totalSelfRub,
    required this.totalDueRub,
    required this.totalPaidRub,
    required this.balanceRub,
    required this.expectedProfitRub,
    this.participants = const [],
  });

  factory SpOrganizerPostedAllocation.fromJson(Map<String, dynamic> json) {
    return SpOrganizerPostedAllocation(
      id: _intValue(json['id']),
      version: _intValue(json['version']),
      appliedSnapshotId: _intValue(json['appliedSnapshotId']),
      supersedesPostingId: json['supersedesPostingId'] == null
          ? null
          : _intValue(json['supersedesPostingId']),
      inputHash: _stringValue(json['inputHash']) ?? '',
      createdAt: DateTime.tryParse(_stringValue(json['createdAt']) ?? ''),
      stale: _boolValue(json['stale']),
      legacyPaymentsApplied: _boolValue(json['legacyPaymentsApplied']),
      totalSelfRub: _doubleValue(json['totalSelfRub']),
      totalDueRub: _doubleValue(json['totalDueRub']),
      totalPaidRub: _doubleValue(json['totalPaidRub']),
      balanceRub: _doubleValue(json['balanceRub']),
      expectedProfitRub: _doubleValue(json['expectedProfitRub']),
      participants: _mapList(json['participants'])
          .map(SpOrganizerPostedAllocationParticipant.fromJson)
          .toList(growable: false),
    );
  }
}

class SpOrganizerCalculationPreview {
  final int contractVersion;
  final String engine;
  final String mode;
  final bool persisted;
  final String inputHash;
  final SpOrganizerCalculationProfile effectiveProfile;
  final SpOrganizerCalculationProfile? effectiveSelfProfile;
  final SpOrganizerCalculationProfile? effectiveClientProfile;
  final SpOrganizerReferenceCalculationPreview? referencePreview;
  final SpOrganizerPostedAllocation? postedAllocation;
  final SpOrganizerCalculationSummary summary;
  final List<SpOrganizerParticipantCalculation> participants;
  final double unallocatedExpensesRub;
  final double unassignedPaidRub;
  final SpOrganizerTo2AObligation organizerTo2A;
  final bool matchesLegacy;
  final double totalDueDeltaRub;
  final double paidDeltaRub;
  final double profitDeltaRub;
  final SpOrganizerCalculationSnapshotSummary? latestSnapshot;
  final SpOrganizerCalculationSnapshotSummary? latestAppliedSnapshot;
  final SpOrganizerCalculationSnapshotSummary? currentAppliedSnapshot;
  final SpOrganizerCalculationSnapshotSummary? latestActualizedSnapshot;
  final bool canApplyCalculation;
  final bool calculationAlreadyApplied;
  final List<String> applyBlockingWarnings;
  final bool canPostAllocation;
  final bool allocationAlreadyPosted;
  final bool postingRequiresApply;
  final bool canActualizeCalculation;
  final bool actualizationNeedsRefresh;
  final List<String> warnings;

  const SpOrganizerCalculationPreview({
    required this.contractVersion,
    required this.engine,
    required this.mode,
    required this.persisted,
    required this.inputHash,
    required this.effectiveProfile,
    this.effectiveSelfProfile,
    this.effectiveClientProfile,
    this.referencePreview,
    this.postedAllocation,
    required this.summary,
    required this.participants,
    required this.unallocatedExpensesRub,
    required this.unassignedPaidRub,
    required this.organizerTo2A,
    required this.matchesLegacy,
    this.totalDueDeltaRub = 0,
    this.paidDeltaRub = 0,
    this.profitDeltaRub = 0,
    this.latestSnapshot,
    this.latestAppliedSnapshot,
    this.currentAppliedSnapshot,
    this.latestActualizedSnapshot,
    this.canApplyCalculation = false,
    this.calculationAlreadyApplied = false,
    this.applyBlockingWarnings = const [],
    this.canPostAllocation = false,
    this.allocationAlreadyPosted = false,
    this.postingRequiresApply = true,
    this.canActualizeCalculation = false,
    this.actualizationNeedsRefresh = false,
    required this.warnings,
  });

  factory SpOrganizerCalculationPreview.fromJson(Map<String, dynamic> json) {
    final allocation = _mapValue(json['allocation']);
    final comparison = _mapValue(json['shadowComparison']);
    final applyState = _mapValue(json['applyState']);
    final postingState = _mapValue(json['postingState']);
    final actualizeState = _mapValue(json['actualizeState']);
    final effectiveProfiles = _mapValue(json['effectiveProfiles']);
    final legacyEffectiveProfile = SpOrganizerCalculationProfile.fromJson(
      _mapValue(json['effectiveProfile']),
    );
    return SpOrganizerCalculationPreview(
      contractVersion: _intValue(json['contractVersion'], 1),
      engine: _stringValue(json['engine']) ?? 'legacy_v1_shadow',
      mode: _stringValue(json['mode']) ?? 'preview',
      persisted: _boolValue(json['persisted']),
      inputHash: _stringValue(json['inputHash']) ?? '',
      effectiveProfile: legacyEffectiveProfile,
      effectiveSelfProfile: effectiveProfiles['self'] is Map
          ? SpOrganizerCalculationProfile.fromJson(
              _mapValue(effectiveProfiles['self']),
            )
          : null,
      effectiveClientProfile: effectiveProfiles['client'] is Map
          ? SpOrganizerCalculationProfile.fromJson(
              _mapValue(effectiveProfiles['client']),
            )
          : legacyEffectiveProfile,
      referencePreview: json['referencePreview'] is Map
          ? SpOrganizerReferenceCalculationPreview.fromJson(
              _mapValue(json['referencePreview']),
            )
          : null,
      postedAllocation: json['postedAllocation'] is Map
          ? SpOrganizerPostedAllocation.fromJson(
              _mapValue(json['postedAllocation']),
            )
          : null,
      summary: SpOrganizerCalculationSummary.fromJson(
        _mapValue(json['summary']),
      ),
      participants: _mapList(
        json['participants'],
      ).map(SpOrganizerParticipantCalculation.fromJson).toList(growable: false),
      unallocatedExpensesRub: _doubleValue(
        allocation['unallocatedExpensesRub'],
      ),
      unassignedPaidRub: _doubleValue(allocation['unassignedPaidRub']),
      organizerTo2A: SpOrganizerTo2AObligation.fromJson(
        _mapValue(json['organizerTo2A']),
      ),
      matchesLegacy: _boolValue(comparison['matchesLegacy']),
      totalDueDeltaRub: _doubleValue(comparison['totalDueDeltaRub']),
      paidDeltaRub: _doubleValue(comparison['paidDeltaRub']),
      profitDeltaRub: _doubleValue(comparison['profitDeltaRub']),
      latestSnapshot: json['latestSnapshot'] is Map
          ? SpOrganizerCalculationSnapshotSummary.fromJson(
              _mapValue(json['latestSnapshot']),
            )
          : null,
      latestAppliedSnapshot: json['latestAppliedSnapshot'] is Map
          ? SpOrganizerCalculationSnapshotSummary.fromJson(
              _mapValue(json['latestAppliedSnapshot']),
            )
          : null,
      currentAppliedSnapshot: json['currentAppliedSnapshot'] is Map
          ? SpOrganizerCalculationSnapshotSummary.fromJson(
              _mapValue(json['currentAppliedSnapshot']),
            )
          : null,
      latestActualizedSnapshot: json['latestActualizedSnapshot'] is Map
          ? SpOrganizerCalculationSnapshotSummary.fromJson(
              _mapValue(json['latestActualizedSnapshot']),
            )
          : null,
      canApplyCalculation: _boolValue(applyState['canApply']),
      calculationAlreadyApplied: _boolValue(applyState['alreadyApplied']),
      applyBlockingWarnings: applyState['blockingWarnings'] is List
          ? (applyState['blockingWarnings'] as List).whereType<String>().toList(
              growable: false,
            )
          : const [],
      canPostAllocation: _boolValue(postingState['canPost']),
      allocationAlreadyPosted: _boolValue(postingState['alreadyPosted']),
      postingRequiresApply: postingState.containsKey('requiresApply')
          ? _boolValue(postingState['requiresApply'])
          : true,
      canActualizeCalculation: _boolValue(actualizeState['canActualize']),
      actualizationNeedsRefresh: _boolValue(actualizeState['needsRefresh']),
      warnings: json['warnings'] is List
          ? (json['warnings'] as List).whereType<String>().toList(
              growable: false,
            )
          : const [],
    );
  }
}

class SpOrganizerAllocationPostingActionResult {
  final bool created;
  final SpOrganizerPostedAllocation posting;
  final bool legacyFieldsUpdated;
  final bool participantLedgerUpdated;
  final bool newAllocationLedgerUpdated;

  const SpOrganizerAllocationPostingActionResult({
    required this.created,
    required this.posting,
    this.legacyFieldsUpdated = false,
    this.participantLedgerUpdated = false,
    this.newAllocationLedgerUpdated = false,
  });

  factory SpOrganizerAllocationPostingActionResult.fromJson(
    Map<String, dynamic> json,
  ) {
    return SpOrganizerAllocationPostingActionResult(
      created: _boolValue(json['created']),
      posting: SpOrganizerPostedAllocation.fromJson(_mapValue(json['posting'])),
      legacyFieldsUpdated: _boolValue(json['legacyFieldsUpdated']),
      participantLedgerUpdated: _boolValue(json['participantLedgerUpdated']),
      newAllocationLedgerUpdated: _boolValue(
        json['newAllocationLedgerUpdated'],
      ),
    );
  }
}

class SpOrganizerCalculationActionResult {
  final bool created;
  final SpOrganizerCalculationSnapshotSummary snapshot;
  final bool legacyFieldsUpdated;
  final bool participantLedgerUpdated;
  final bool referenceAllocationPersisted;
  final SpOrganizerTo2AObligation? organizerTo2A;
  final List<String> warnings;

  const SpOrganizerCalculationActionResult({
    required this.created,
    required this.snapshot,
    this.legacyFieldsUpdated = false,
    this.participantLedgerUpdated = false,
    this.referenceAllocationPersisted = false,
    this.organizerTo2A,
    this.warnings = const [],
  });

  factory SpOrganizerCalculationActionResult.fromJson(
    Map<String, dynamic> json,
  ) {
    return SpOrganizerCalculationActionResult(
      created: _boolValue(json['created']),
      snapshot: SpOrganizerCalculationSnapshotSummary.fromJson(
        _mapValue(json['snapshot']),
      ),
      legacyFieldsUpdated: _boolValue(json['legacyFieldsUpdated']),
      participantLedgerUpdated: _boolValue(json['participantLedgerUpdated']),
      referenceAllocationPersisted: _boolValue(
        json['referenceAllocationPersisted'],
      ),
      organizerTo2A: json['organizerTo2A'] is Map
          ? SpOrganizerTo2AObligation.fromJson(_mapValue(json['organizerTo2A']))
          : null,
      warnings: json['warnings'] is List
          ? (json['warnings'] as List).whereType<String>().toList(
              growable: false,
            )
          : const [],
    );
  }
}
