// Самовыкуп — модели данных клиента.

class SelfBuyoutVerificationContact {
  final String fullName;
  final String phone;
  final String telegram;

  const SelfBuyoutVerificationContact({
    this.fullName = '',
    this.phone = '',
    this.telegram = '',
  });

  factory SelfBuyoutVerificationContact.fromJson(Map<String, dynamic>? json) {
    return SelfBuyoutVerificationContact(
      fullName: json?['fullName']?.toString() ?? '',
      phone: json?['phone']?.toString() ?? '',
      telegram: json?['telegram']?.toString() ?? '',
    );
  }
}

class SelfBuyoutVerification {
  final bool required;
  final String status;
  final int? verificationId;
  final int? requestVersion;
  final DateTime? submittedAt;
  final DateTime? decidedAt;
  final String? decisionSource;
  final String? rejectionReason;
  final bool canSubmit;
  final SelfBuyoutVerificationContact contact;

  const SelfBuyoutVerification({
    this.required = false,
    this.status = 'not_required',
    this.verificationId,
    this.requestVersion,
    this.submittedAt,
    this.decidedAt,
    this.decisionSource,
    this.rejectionReason,
    this.canSubmit = false,
    this.contact = const SelfBuyoutVerificationContact(),
  });

  static DateTime? _date(dynamic value) =>
      value == null ? null : DateTime.tryParse(value.toString());

  factory SelfBuyoutVerification.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const SelfBuyoutVerification();
    return SelfBuyoutVerification(
      required: json['required'] == true,
      status: json['status']?.toString() ?? 'not_required',
      verificationId: (json['verificationId'] as num?)?.toInt(),
      requestVersion: (json['requestVersion'] as num?)?.toInt(),
      submittedAt: _date(json['submittedAt']),
      decidedAt: _date(json['decidedAt']),
      decisionSource: json['decisionSource']?.toString(),
      rejectionReason: json['rejectionReason']?.toString(),
      canSubmit: json['canSubmit'] == true,
      contact: SelfBuyoutVerificationContact.fromJson(
        json['contact'] as Map<String, dynamic>?,
      ),
    );
  }

  bool get isRequired => required && status == 'required';
  bool get isPending => required && status == 'pending';
  bool get isRejected => required && status == 'rejected';
  bool get isApproved => !required || status == 'approved';
}

class SelfBuyoutAvailability {
  final bool available;
  final String? reason;
  final String? disabledReason;
  final String? requisitesSource;
  final String? rateDate;
  final double? clientCnyRubRate;
  final double? minCny;
  final double? maxCny;
  final bool firstExchangeActive;
  final bool showFirstExchangeOnboarding;
  final bool? alipayTopUpExperienced;
  final bool requiresAlipayExperienceAnswer;
  final double firstExchangeInexperiencedMaxCny;
  final int deliveryDeadlineDays;
  final bool? operatorSleeping;
  final bool operatorStatusReachable;
  final DateTime? operatorStatusUpdatedAt;
  final DateTime? operatorStatusCheckedAt;
  final SelfBuyoutVerification verification;

  const SelfBuyoutAvailability({
    required this.available,
    this.reason,
    this.disabledReason,
    this.requisitesSource,
    this.rateDate,
    this.clientCnyRubRate,
    this.minCny,
    this.maxCny,
    this.firstExchangeActive = false,
    this.showFirstExchangeOnboarding = false,
    this.alipayTopUpExperienced,
    this.requiresAlipayExperienceAnswer = false,
    this.firstExchangeInexperiencedMaxCny = 1000,
    this.deliveryDeadlineDays = 14,
    this.operatorSleeping,
    this.operatorStatusReachable = false,
    this.operatorStatusUpdatedAt,
    this.operatorStatusCheckedAt,
    this.verification = const SelfBuyoutVerification(),
  });

  factory SelfBuyoutAvailability.fromJson(Map<String, dynamic> json) {
    final rate = json['rate'] as Map<String, dynamic>?;
    final limits = json['limits'] as Map<String, dynamic>?;
    final firstExchange = json['firstExchange'] as Map<String, dynamic>?;
    final operatorStatus = json['operatorStatus'] as Map<String, dynamic>?;
    final cnyRubRate = (rate?['clientCnyRubRate'] as num?)?.toDouble();
    final explicitMinCny = (limits?['minCny'] as num?)?.toDouble();
    final legacyMinRub = (limits?['minRub'] as num?)?.toDouble();
    return SelfBuyoutAvailability(
      available: json['available'] == true,
      reason: json['reason']?.toString(),
      disabledReason: json['disabledReason']?.toString(),
      requisitesSource: json['requisitesSource']?.toString(),
      rateDate: rate?['date']?.toString(),
      clientCnyRubRate: cnyRubRate,
      minCny:
          explicitMinCny ??
          (legacyMinRub != null && cnyRubRate != null && cnyRubRate > 0
              ? legacyMinRub / cnyRubRate
              : null),
      maxCny: (limits?['maxCny'] as num?)?.toDouble(),
      firstExchangeActive: firstExchange?['active'] == true,
      showFirstExchangeOnboarding: firstExchange?['showOnboarding'] == true,
      alipayTopUpExperienced: firstExchange?['alipayTopUpExperienced'] as bool?,
      requiresAlipayExperienceAnswer:
          firstExchange?['requiresAlipayExperienceAnswer'] == true,
      firstExchangeInexperiencedMaxCny:
          (firstExchange?['inexperiencedMaxCny'] as num?)?.toDouble() ?? 1000,
      deliveryDeadlineDays:
          (json['deliveryDeadlineDays'] as num?)?.toInt() ?? 14,
      operatorSleeping: operatorStatus?['sleeping'] as bool?,
      operatorStatusReachable: operatorStatus?['reachable'] == true,
      operatorStatusUpdatedAt: DateTime.tryParse(
        operatorStatus?['updatedAt']?.toString() ?? '',
      ),
      operatorStatusCheckedAt: DateTime.tryParse(
        operatorStatus?['checkedAt']?.toString() ?? '',
      ),
      verification: SelfBuyoutVerification.fromJson(
        json['verification'] as Map<String, dynamic>?,
      ),
    );
  }

  bool get operatorWorking => operatorSleeping != true;

  bool isBelowMinimum(double cnyAmount) =>
      minCny != null && minCny! > 0 && cnyAmount < minCny!;

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

class SelfBuyoutTransferProof {
  final int id;
  final String fileName;
  final String mimeType;
  final int size;
  final String? externalId;
  final String? comment;
  final DateTime? createdAt;
  final String fileUrl;

  const SelfBuyoutTransferProof({
    required this.id,
    required this.fileName,
    required this.mimeType,
    required this.size,
    this.externalId,
    this.comment,
    this.createdAt,
    required this.fileUrl,
  });

  factory SelfBuyoutTransferProof.fromJson(Map<String, dynamic> json) {
    return SelfBuyoutTransferProof(
      id: (json['id'] as num).toInt(),
      fileName: json['fileName']?.toString() ?? 'transfer-proof',
      mimeType: json['mimeType']?.toString() ?? 'application/octet-stream',
      size: (json['size'] as num?)?.toInt() ?? 0,
      externalId: json['externalId']?.toString(),
      comment: json['comment']?.toString(),
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.tryParse(json['createdAt'].toString()),
      fileUrl: json['fileUrl']?.toString() ?? '',
    );
  }
}

class SelfBuyoutCancellation {
  final String source;
  final String reason;
  final String? reasonCode;
  final bool canCorrectRequisites;

  const SelfBuyoutCancellation({
    required this.source,
    required this.reason,
    this.reasonCode,
    this.canCorrectRequisites = false,
  });

  factory SelfBuyoutCancellation.fromJson(Map<String, dynamic> json) {
    return SelfBuyoutCancellation(
      source: json['source']?.toString() ?? 'unknown',
      reason: json['reason']?.toString() ?? '',
      reasonCode: json['reasonCode']?.toString(),
      canCorrectRequisites: json['canCorrectRequisites'] == true,
    );
  }
}

class SelfBuyoutDetail {
  final SelfBuyoutRequest request;
  final SelfBuyoutPaymentInfo? payment;
  final List<SelfBuyoutTransferProof> transferProofs;
  final SelfBuyoutCancellation? cancellation;

  const SelfBuyoutDetail({
    required this.request,
    this.payment,
    this.transferProofs = const [],
    this.cancellation,
  });

  factory SelfBuyoutDetail.fromJson(Map<String, dynamic> json) {
    final paymentJson = json['payment'];
    final cancellationJson = json['cancellation'];
    return SelfBuyoutDetail(
      request: SelfBuyoutRequest.fromJson(
        json['request'] as Map<String, dynamic>,
      ),
      payment: paymentJson is Map<String, dynamic>
          ? SelfBuyoutPaymentInfo.fromDetailJson(paymentJson)
          : null,
      transferProofs:
          (json['transferProofs'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .map(SelfBuyoutTransferProof.fromJson)
              .toList() ??
          const [],
      cancellation: cancellationJson is Map<String, dynamic>
          ? SelfBuyoutCancellation.fromJson(cancellationJson)
          : null,
    );
  }
}
