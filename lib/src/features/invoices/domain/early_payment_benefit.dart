typedef EarlyPaymentUtcNow = DateTime Function();

DateTime _systemUtcNow() => DateTime.now().toUtc();

enum EarlyPaymentBenefitType {
  priceLock('price_lock'),
  freeInsurance('free_insurance'),
  bonusKg('bonus_kg');

  const EarlyPaymentBenefitType(this.serverValue);

  final String serverValue;

  static EarlyPaymentBenefitType? tryParse(dynamic value) {
    final normalized = value?.toString().trim().toLowerCase();
    return switch (normalized) {
      'price_lock' || 'price-lock' || 'pricefix' => priceLock,
      'free_insurance' || 'free-insurance' || 'insurance' => freeInsurance,
      'bonus_kg' || 'bonus-kg' || 'bonuskg' => bonusKg,
      _ => null,
    };
  }
}

enum EarlyPaymentBenefitState {
  available,
  selected,
  selectionRequired,
  applied,
  expired,
  cancelled,
  reversed,
  unknown;

  static EarlyPaymentBenefitState parse(dynamic value) {
    final normalized = value?.toString().trim().toLowerCase();
    return switch (normalized) {
      'available' => available,
      'selected' => selected,
      'selection_required' || 'selection-required' => selectionRequired,
      'applied' => applied,
      'expired' => expired,
      'cancelled' || 'canceled' => cancelled,
      'reversed' => reversed,
      _ => unknown,
    };
  }
}

class EarlyPaymentBenefitProjectedValue {
  final double? unitRate;
  final String? unit;
  final double? insuredValueUsd;
  final double? waivedInsuranceUsd;
  final double? bonusKg;

  const EarlyPaymentBenefitProjectedValue({
    this.unitRate,
    this.unit,
    this.insuredValueUsd,
    this.waivedInsuranceUsd,
    this.bonusKg,
  });

  factory EarlyPaymentBenefitProjectedValue.fromJson(
    Map<String, dynamic> json,
  ) {
    return EarlyPaymentBenefitProjectedValue(
      unitRate: _optionalDouble(json['unitRate']),
      unit: json['unit']?.toString(),
      insuredValueUsd: _optionalDouble(json['insuredValueUsd']),
      waivedInsuranceUsd: _optionalDouble(json['waivedInsuranceUsd']),
      bonusKg: _optionalDouble(json['bonusKg']),
    );
  }
}

class EarlyPaymentBenefitOption {
  final EarlyPaymentBenefitType type;
  final bool enabled;
  final bool available;
  final String? unavailableReason;
  final EarlyPaymentBenefitProjectedValue projectedValue;

  const EarlyPaymentBenefitOption({
    required this.type,
    required this.enabled,
    required this.available,
    this.unavailableReason,
    this.projectedValue = const EarlyPaymentBenefitProjectedValue(),
  });

  factory EarlyPaymentBenefitOption.fromJson(Map<String, dynamic> json) {
    final type = EarlyPaymentBenefitType.tryParse(json['type']);
    if (type == null) {
      throw const FormatException('Unknown early-payment benefit type');
    }
    final projectedValue = _map(json['projectedValue']);
    return EarlyPaymentBenefitOption(
      type: type,
      enabled: json['enabled'] == true,
      available: json['available'] == true,
      unavailableReason: json['unavailableReason']?.toString(),
      projectedValue: projectedValue == null
          ? const EarlyPaymentBenefitProjectedValue()
          : EarlyPaymentBenefitProjectedValue.fromJson(projectedValue),
    );
  }
}

class EarlyPaymentBenefit {
  final EarlyPaymentBenefitState state;
  final DateTime? offeredAt;
  final DateTime? expiresAt;
  final DateTime? serverTime;
  final DateTime receivedAt;
  final bool hasTimelyEvidence;
  final bool selectionRequired;
  final EarlyPaymentBenefitType? selectedType;
  final DateTime? selectedAt;
  final DateTime? qualifiedAt;
  final DateTime? appliedAt;
  final DateTime? reversedAt;
  final List<EarlyPaymentBenefitOption> options;
  final EarlyPaymentUtcNow _now;

  EarlyPaymentBenefit({
    required this.state,
    this.offeredAt,
    this.expiresAt,
    this.serverTime,
    DateTime? receivedAt,
    this.hasTimelyEvidence = false,
    this.selectionRequired = false,
    this.selectedType,
    this.selectedAt,
    this.qualifiedAt,
    this.appliedAt,
    this.reversedAt,
    this.options = const [],
    EarlyPaymentUtcNow? now,
  }) : _now = now ?? _systemUtcNow,
       receivedAt = receivedAt ?? (now ?? _systemUtcNow)().toUtc();

  factory EarlyPaymentBenefit.fromJson(
    Map<String, dynamic> json, {
    EarlyPaymentUtcNow? now,
  }) {
    final rawOptions = json['options'];
    final options = rawOptions is List
        ? rawOptions
              .whereType<Map>()
              .map((value) => Map<String, dynamic>.from(value))
              .map((value) {
                try {
                  return EarlyPaymentBenefitOption.fromJson(value);
                } on FormatException {
                  return null;
                }
              })
              .whereType<EarlyPaymentBenefitOption>()
              .toList(growable: false)
        : const <EarlyPaymentBenefitOption>[];

    return EarlyPaymentBenefit(
      state: EarlyPaymentBenefitState.parse(json['state']),
      offeredAt: _date(json['offeredAt']),
      expiresAt: _date(json['expiresAt']),
      serverTime: _date(json['serverTime']),
      hasTimelyEvidence: json['hasTimelyEvidence'] == true,
      selectionRequired: json['selectionRequired'] == true,
      selectedType: EarlyPaymentBenefitType.tryParse(
        json['selectedType'] ?? json['benefitType'],
      ),
      selectedAt: _date(json['selectedAt']),
      qualifiedAt: _date(json['qualifiedAt']),
      appliedAt: _date(json['appliedAt']),
      reversedAt: _date(json['reversedAt']),
      options: options,
      now: now,
    );
  }

  DateTime get _effectiveNow => serverTime == null
      ? _now().toUtc()
      : serverTime!.toUtc().add(_now().toUtc().difference(receivedAt));

  bool get isSelectionWindowOpen {
    final deadline = expiresAt;
    if (deadline == null) return true;
    return !_effectiveNow.isAfter(deadline.toUtc());
  }

  Duration get timeUntilSelectionCloses {
    final deadline = expiresAt;
    if (deadline == null) return const Duration(days: 3650);
    final remaining = deadline.toUtc().difference(_effectiveNow);
    return remaining.isNegative ? Duration.zero : remaining;
  }

  bool get requiresSelectionBeforePayment =>
      isSelectionWindowOpen &&
      selectedType == null &&
      (selectionRequired ||
          state == EarlyPaymentBenefitState.available ||
          state == EarlyPaymentBenefitState.selectionRequired);

  bool get canSelect =>
      requiresSelectionBeforePayment && selectableOptions.isNotEmpty;

  List<EarlyPaymentBenefitOption> get selectableOptions => options
      .where((option) => option.enabled && option.available)
      .toList(growable: false);

  EarlyPaymentBenefitOption? get selectedOption {
    final selected = selectedType;
    if (selected == null) return null;
    for (final option in options) {
      if (option.type == selected) return option;
    }
    return null;
  }
}

Map<String, dynamic>? _map(dynamic value) {
  if (value is! Map) return null;
  return Map<String, dynamic>.from(value);
}

DateTime? _date(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}

double? _optionalDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}
