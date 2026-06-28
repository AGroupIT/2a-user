// Самовыкуп — модели данных клиента.

class SelfBuyoutAvailability {
  final bool available;
  final String? reason;
  final String? disabledReason;
  final String? requisitesSource;
  final String? rateDate;
  final double? clientCnyRubRate;
  final double? minRub;
  final double? maxRub;
  final int deliveryDeadlineDays;

  const SelfBuyoutAvailability({
    required this.available,
    this.reason,
    this.disabledReason,
    this.requisitesSource,
    this.rateDate,
    this.clientCnyRubRate,
    this.minRub,
    this.maxRub,
    this.deliveryDeadlineDays = 14,
  });

  factory SelfBuyoutAvailability.fromJson(Map<String, dynamic> json) {
    final rate = json['rate'] as Map<String, dynamic>?;
    final limits = json['limits'] as Map<String, dynamic>?;
    return SelfBuyoutAvailability(
      available: json['available'] == true,
      reason: json['reason']?.toString(),
      disabledReason: json['disabledReason']?.toString(),
      requisitesSource: json['requisitesSource']?.toString(),
      rateDate: rate?['date']?.toString(),
      clientCnyRubRate: (rate?['clientCnyRubRate'] as num?)?.toDouble(),
      minRub: (limits?['minRub'] as num?)?.toDouble(),
      maxRub: (limits?['maxRub'] as num?)?.toDouble(),
      deliveryDeadlineDays: (json['deliveryDeadlineDays'] as num?)?.toInt() ?? 14,
    );
  }

  static const unavailable = SelfBuyoutAvailability(available: false);
}

class SelfBuyoutRequest {
  final int id;
  final String requestNumber;
  final String status;
  final int clientCodeId;
  final String? clientCode;
  final double requestedCnyAmount;
  final double paymentRubAmount;
  final double clientCnyRubRate;
  final String amountEnteredIn;
  final String? transferRequisitesText;
  final bool hasTransferQr;
  final int? activePaymentId;
  final DateTime? paidAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final DateTime? yuanDeliveryDeadlineAt;
  final DateTime? createdAt;

  const SelfBuyoutRequest({
    required this.id,
    required this.requestNumber,
    required this.status,
    required this.clientCodeId,
    this.clientCode,
    required this.requestedCnyAmount,
    required this.paymentRubAmount,
    required this.clientCnyRubRate,
    required this.amountEnteredIn,
    this.transferRequisitesText,
    this.hasTransferQr = false,
    this.activePaymentId,
    this.paidAt,
    this.completedAt,
    this.cancelledAt,
    this.yuanDeliveryDeadlineAt,
    this.createdAt,
  });

  static DateTime? _date(dynamic v) =>
      v == null ? null : DateTime.tryParse(v.toString());

  factory SelfBuyoutRequest.fromJson(Map<String, dynamic> json) {
    return SelfBuyoutRequest(
      id: (json['id'] as num).toInt(),
      requestNumber: json['requestNumber']?.toString() ?? '',
      status: json['status']?.toString() ?? 'new',
      clientCodeId: (json['clientCodeId'] as num?)?.toInt() ?? 0,
      clientCode: json['clientCode']?.toString(),
      requestedCnyAmount: (json['requestedCnyAmount'] as num?)?.toDouble() ?? 0,
      paymentRubAmount: (json['paymentRubAmount'] as num?)?.toDouble() ?? 0,
      clientCnyRubRate: (json['clientCnyRubRate'] as num?)?.toDouble() ?? 0,
      amountEnteredIn: json['amountEnteredIn']?.toString() ?? 'cny',
      transferRequisitesText: json['transferRequisitesText']?.toString(),
      hasTransferQr: json['hasTransferQr'] == true,
      activePaymentId: (json['activePaymentId'] as num?)?.toInt(),
      paidAt: _date(json['paidAt']),
      completedAt: _date(json['completedAt']),
      cancelledAt: _date(json['cancelledAt']),
      yuanDeliveryDeadlineAt: _date(json['yuanDeliveryDeadlineAt']),
      createdAt: _date(json['createdAt']),
    );
  }
}

/// Результат старта QR (или детали активного платежа).
class SelfBuyoutPaymentInfo {
  final int paymentId;
  final String status;
  final double amountRub;
  final int sumKopecks;
  final String purpose;
  final String qrPayload;
  final String? receiptStatus;
  final String? receiptRejectReason;

  const SelfBuyoutPaymentInfo({
    required this.paymentId,
    required this.status,
    required this.amountRub,
    required this.sumKopecks,
    required this.purpose,
    required this.qrPayload,
    this.receiptStatus,
    this.receiptRejectReason,
  });

  factory SelfBuyoutPaymentInfo.fromStartJson(Map<String, dynamic> json) {
    return SelfBuyoutPaymentInfo(
      paymentId: (json['paymentId'] as num).toInt(),
      status: json['status']?.toString() ?? 'pending',
      amountRub: (json['amountRub'] as num?)?.toDouble() ?? 0,
      sumKopecks: (json['sumKopecks'] as num?)?.toInt() ?? 0,
      purpose: json['purpose']?.toString() ?? '',
      qrPayload: json['qrPayload']?.toString() ?? '',
    );
  }

  factory SelfBuyoutPaymentInfo.fromDetailJson(Map<String, dynamic> json) {
    final receipt = json['receipt'] as Map<String, dynamic>?;
    return SelfBuyoutPaymentInfo(
      paymentId: (json['paymentId'] as num).toInt(),
      status: json['status']?.toString() ?? 'pending',
      amountRub: (json['amountRub'] as num?)?.toDouble() ?? 0,
      sumKopecks: (json['sumKopecks'] as num?)?.toInt() ?? 0,
      purpose: json['purpose']?.toString() ?? '',
      qrPayload: json['qrPayload']?.toString() ?? '',
      receiptStatus: receipt?['status']?.toString(),
      receiptRejectReason: receipt?['rejectReason']?.toString(),
    );
  }
}
