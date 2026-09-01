enum ClientPaymentState {
  unpaid,
  awaitingReview,
  partial,
  paid,
  overpaid,
  refunded,
  unknown,
}

class ClientPaymentSummary {
  final RubAmount requiredRub;
  final RubAmount creditedRub;
  final RubAmount remainingRub;
  final RubAmount overpaidRub;
  final RubAmount waivedShortfallRub;
  final String? closureKind;
  final bool shortfallAccepted;
  final ClientPaymentState state;
  final String rawState;
  final DateTime? valuationAt;
  final DateTime? lockedAt;
  final int? currencyRateId;
  final String? ratePolicy;

  const ClientPaymentSummary({
    required this.requiredRub,
    required this.creditedRub,
    required this.remainingRub,
    required this.overpaidRub,
    required this.waivedShortfallRub,
    required this.shortfallAccepted,
    required this.state,
    required this.rawState,
    this.valuationAt,
    this.lockedAt,
    this.currencyRateId,
    this.ratePolicy,
    this.closureKind,
  });

  bool get hasRemaining => remainingRub.kopecks > 0;
  bool get isPartial => state == ClientPaymentState.partial && hasRemaining;
  bool get hasAcceptedShortfall =>
      shortfallAccepted && waivedShortfallRub.kopecks > 0;
  bool get isUnknown => state == ClientPaymentState.unknown;
  bool get isFullyCovered =>
      !hasRemaining &&
      (state == ClientPaymentState.paid ||
          state == ClientPaymentState.overpaid ||
          state == ClientPaymentState.refunded);

  static ClientPaymentSummary? tryParse(dynamic value) {
    if (value is! Map) return null;
    final json = Map<String, dynamic>.from(value);
    final requiredRub = RubAmount.tryParse(json['requiredRub']);
    final creditedRub = RubAmount.tryParse(json['creditedRub']);
    final remainingRub = RubAmount.tryParse(json['remainingRub']);
    final overpaidRub = RubAmount.tryParse(json['overpaidRub']);
    final waivedShortfallRub =
        RubAmount.tryParse(json['waivedShortfallRub']) ?? RubAmount.zero;
    if (requiredRub == null ||
        creditedRub == null ||
        remainingRub == null ||
        overpaidRub == null) {
      return null;
    }
    final rawState = json['state']?.toString().trim().toLowerCase() ?? '';
    return ClientPaymentSummary(
      requiredRub: requiredRub,
      creditedRub: creditedRub,
      remainingRub: remainingRub,
      overpaidRub: overpaidRub,
      waivedShortfallRub: waivedShortfallRub,
      shortfallAccepted:
          json['shortfallAccepted'] == true &&
          (json['closureKind'] == null ||
              json['closureKind']?.toString() == 'shortfall_accepted'),
      state: switch (rawState) {
        'unpaid' => ClientPaymentState.unpaid,
        'awaiting_review' => ClientPaymentState.awaitingReview,
        'partial' => ClientPaymentState.partial,
        'paid' => ClientPaymentState.paid,
        'overpaid' => ClientPaymentState.overpaid,
        'refunded' => ClientPaymentState.refunded,
        _ => ClientPaymentState.unknown,
      },
      rawState: rawState,
      valuationAt: DateTime.tryParse(json['valuationAt']?.toString() ?? ''),
      lockedAt: DateTime.tryParse(json['lockedAt']?.toString() ?? ''),
      currencyRateId: _int(json['currencyRateId']),
      ratePolicy: json['ratePolicy']?.toString(),
      closureKind: json['closureKind']?.toString(),
    );
  }
}

class ClientActiveTopUp {
  final int paymentId;
  final RubAmount amountRub;
  final String currency;
  final String status;
  final String provider;
  final String? method;

  const ClientActiveTopUp({
    required this.paymentId,
    required this.amountRub,
    required this.currency,
    required this.status,
    required this.provider,
    this.method,
  });

  bool get isPayableBankQr =>
      paymentId > 0 &&
      amountRub.kopecks > 0 &&
      currency.toUpperCase() == 'RUB' &&
      status == 'pending' &&
      provider == 'bank_qr' &&
      (method == null || method == 'bank_qr');

  static ClientActiveTopUp? tryParse(dynamic value) {
    if (value is! Map) return null;
    final json = Map<String, dynamic>.from(value);
    final paymentId = _int(json['paymentId']);
    final amountRub = RubAmount.tryParse(json['amountRub']);
    if (paymentId == null || paymentId <= 0 || amountRub == null) return null;
    return ClientActiveTopUp(
      paymentId: paymentId,
      amountRub: amountRub,
      currency: json['currency']?.toString() ?? '',
      status: json['status']?.toString().toLowerCase() ?? '',
      provider: json['provider']?.toString().toLowerCase() ?? '',
      method: json['method']?.toString().toLowerCase(),
    );
  }
}

class RubAmount {
  final int kopecks;

  const RubAmount._(this.kopecks);

  static const zero = RubAmount._(0);

  String get decimal {
    final rubles = kopecks ~/ 100;
    final cents = (kopecks % 100).toString().padLeft(2, '0');
    return '$rubles.$cents';
  }

  String get display => '$decimal ₽';

  static RubAmount? tryParse(dynamic value) {
    if (value == null) return null;
    final normalized = value.toString().trim().replaceAll(',', '.');
    final match = RegExp(r'^(\d+)(?:\.(\d{1,2}))?$').firstMatch(normalized);
    if (match == null) return null;
    final rubles = int.tryParse(match.group(1)!);
    if (rubles == null) return null;
    final fraction = (match.group(2) ?? '').padRight(2, '0');
    final kopecks = int.tryParse(fraction.isEmpty ? '0' : fraction);
    if (kopecks == null) return null;
    return RubAmount._(rubles * 100 + kopecks);
  }
}

int? _int(dynamic value) {
  if (value is int) return value;
  if (value is num && value.isFinite && value == value.roundToDouble()) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '');
}
