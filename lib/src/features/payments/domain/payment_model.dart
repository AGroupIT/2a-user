/// Статус платежа
enum PaymentStatus {
  pending,
  success,
  underpaid,
  overpaid,
  fail,
  refunded,
  chargeback;

  static PaymentStatus fromString(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return PaymentStatus.pending;
      case 'success':
        return PaymentStatus.success;
      case 'underpaid':
        return PaymentStatus.underpaid;
      case 'overpaid':
        return PaymentStatus.overpaid;
      case 'fail':
        return PaymentStatus.fail;
      case 'refunded':
        return PaymentStatus.refunded;
      case 'chargeback':
        return PaymentStatus.chargeback;
      default:
        return PaymentStatus.pending;
    }
  }

  String get displayName {
    switch (this) {
      case PaymentStatus.pending:
        return 'Ожидает оплаты';
      case PaymentStatus.success:
        return 'Оплачен';
      case PaymentStatus.underpaid:
        return 'Недоплата';
      case PaymentStatus.overpaid:
        return 'Переплата';
      case PaymentStatus.fail:
        return 'Ошибка';
      case PaymentStatus.refunded:
        return 'Возвращён';
      case PaymentStatus.chargeback:
        return 'Чарджбэк';
    }
  }

  bool get isSuccess => this == PaymentStatus.success;
  bool get isPending => this == PaymentStatus.pending;
  bool get isFailed =>
      this == PaymentStatus.fail ||
      this == PaymentStatus.refunded ||
      this == PaymentStatus.chargeback;
}

/// Провайдер платежа
enum PaymentProvider {
  pally,
  usdtTrc20,
  manual;

  static PaymentProvider fromString(String provider) {
    switch (provider.toLowerCase()) {
      case 'pally':
        return PaymentProvider.pally;
      case 'usdt_trc20':
        return PaymentProvider.usdtTrc20;
      case 'manual':
        return PaymentProvider.manual;
      default:
        return PaymentProvider.pally;
    }
  }

  String get displayName {
    switch (this) {
      case PaymentProvider.pally:
        return 'Банковская карта / СБП';
      case PaymentProvider.usdtTrc20:
        return 'USDT TRC20';
      case PaymentProvider.manual:
        return 'Ручной';
    }
  }

  bool get isCrypto => this == PaymentProvider.usdtTrc20;
}

/// Метод оплаты
enum PaymentMethod {
  bankCard,
  sbp,
  crypto,
  other;

  static PaymentMethod? fromString(String? method) {
    if (method == null) return null;
    switch (method.toLowerCase()) {
      case 'bank_card':
        return PaymentMethod.bankCard;
      case 'sbp':
        return PaymentMethod.sbp;
      case 'crypto':
        return PaymentMethod.crypto;
      case 'other':
        return PaymentMethod.other;
      default:
        return null;
    }
  }

  String get displayName {
    switch (this) {
      case PaymentMethod.bankCard:
        return 'Банковская карта';
      case PaymentMethod.sbp:
        return 'СБП';
      case PaymentMethod.crypto:
        return 'Криптовалюта';
      case PaymentMethod.other:
        return 'Другое';
    }
  }
}

/// Модель платежа
class Payment {
  final int id;
  final int agentId;
  final int? clientId;
  final int? invoiceId;
  final String orderId;
  final String? externalId;
  final double amount;
  final double? commission;
  final double? balanceAmount;
  final String currency;
  final PaymentStatus status;
  final PaymentProvider provider;
  final PaymentMethod? method;
  final String? payerPhone;
  final String? payerEmail;
  final String? payerName;
  final String? payerComment;
  final String? accountNumber;
  final String? description;
  final String? custom;
  final int? errorCode;
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? paidAt;

  // Crypto-specific fields
  final double? cryptoAmount;
  final String? cryptoCurrency;
  final String? walletAddress;
  final String? txHash;
  final double? exchangeRate;
  final DateTime? expiresAt;

  const Payment({
    required this.id,
    required this.agentId,
    this.clientId,
    this.invoiceId,
    required this.orderId,
    this.externalId,
    required this.amount,
    this.commission,
    this.balanceAmount,
    required this.currency,
    required this.status,
    required this.provider,
    this.method,
    this.payerPhone,
    this.payerEmail,
    this.payerName,
    this.payerComment,
    this.accountNumber,
    this.description,
    this.custom,
    this.errorCode,
    this.errorMessage,
    required this.createdAt,
    required this.updatedAt,
    this.paidAt,
    // Crypto-specific
    this.cryptoAmount,
    this.cryptoCurrency,
    this.walletAddress,
    this.txHash,
    this.exchangeRate,
    this.expiresAt,
  });

  factory Payment.fromJson(Map<String, dynamic> json) {
    return Payment(
      id: json['id'] as int,
      agentId: json['agentId'] as int,
      clientId: json['clientId'] as int?,
      invoiceId: json['invoiceId'] as int?,
      orderId: json['orderId'] as String,
      externalId: json['externalId'] as String?,
      amount: (json['amount'] as num).toDouble(),
      commission: json['commission'] != null
          ? (json['commission'] as num).toDouble()
          : null,
      balanceAmount: json['balanceAmount'] != null
          ? (json['balanceAmount'] as num).toDouble()
          : null,
      currency: json['currency'] as String? ?? 'RUB',
      status: PaymentStatus.fromString(json['status'] as String? ?? 'pending'),
      provider:
          PaymentProvider.fromString(json['provider'] as String? ?? 'pally'),
      method: PaymentMethod.fromString(json['method'] as String?),
      payerPhone: json['payerPhone'] as String?,
      payerEmail: json['payerEmail'] as String?,
      payerName: json['payerName'] as String?,
      payerComment: json['payerComment'] as String?,
      accountNumber: json['accountNumber'] as String?,
      description: json['description'] as String?,
      custom: json['custom'] as String?,
      errorCode: json['errorCode'] as int?,
      errorMessage: json['errorMessage'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      paidAt: json['paidAt'] != null
          ? DateTime.parse(json['paidAt'] as String)
          : null,
      // Crypto-specific
      cryptoAmount: json['cryptoAmount'] != null
          ? (json['cryptoAmount'] as num).toDouble()
          : null,
      cryptoCurrency: json['cryptoCurrency'] as String?,
      walletAddress: json['walletAddress'] as String?,
      txHash: json['txHash'] as String?,
      exchangeRate: json['exchangeRate'] != null
          ? (json['exchangeRate'] as num).toDouble()
          : null,
      expiresAt: json['expiresAt'] != null
          ? DateTime.parse(json['expiresAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'agentId': agentId,
      'clientId': clientId,
      'invoiceId': invoiceId,
      'orderId': orderId,
      'externalId': externalId,
      'amount': amount,
      'commission': commission,
      'balanceAmount': balanceAmount,
      'currency': currency,
      'status': status.name,
      'provider': provider.name,
      'method': method?.name,
      'payerPhone': payerPhone,
      'payerEmail': payerEmail,
      'payerName': payerName,
      'payerComment': payerComment,
      'accountNumber': accountNumber,
      'description': description,
      'custom': custom,
      'errorCode': errorCode,
      'errorMessage': errorMessage,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'paidAt': paidAt?.toIso8601String(),
      // Crypto-specific
      'cryptoAmount': cryptoAmount,
      'cryptoCurrency': cryptoCurrency,
      'walletAddress': walletAddress,
      'txHash': txHash,
      'exchangeRate': exchangeRate,
      'expiresAt': expiresAt?.toIso8601String(),
    };
  }

  /// Форматированная сумма
  String get formattedAmount => '${amount.toStringAsFixed(2)} $currency';

  /// Форматированная крипто-сумма
  String? get formattedCryptoAmount {
    if (cryptoAmount == null) return null;
    return '${cryptoAmount!.toStringAsFixed(4)} ${cryptoCurrency ?? 'USDT'}';
  }

  /// Проверка истечения срока платежа
  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  /// Оставшееся время до истечения (в минутах)
  int? get remainingMinutes {
    if (expiresAt == null) return null;
    final diff = expiresAt!.difference(DateTime.now());
    if (diff.isNegative) return 0;
    return diff.inMinutes;
  }
}

/// Результат создания платежа (Pally)
class CreatePaymentResult {
  final int paymentId;
  final String orderId;
  final String paymentUrl;
  final String billId;

  const CreatePaymentResult({
    required this.paymentId,
    required this.orderId,
    required this.paymentUrl,
    required this.billId,
  });

  factory CreatePaymentResult.fromJson(Map<String, dynamic> json) {
    return CreatePaymentResult(
      paymentId: json['paymentId'] as int,
      orderId: json['orderId'] as String,
      paymentUrl: json['paymentUrl'] as String,
      billId: json['billId'] as String,
    );
  }
}

/// Результат создания USDT платежа
class CreateUsdtPaymentResult {
  final int paymentId;
  final String orderId;
  final String walletAddress;
  final double rubAmount;
  final double usdtAmount;
  final String formattedUsdtAmount;
  final double cbrRate;
  final double effectiveRate;
  final double markupPercent;
  final DateTime expiresAt;
  final int expiresInMinutes;
  final String network;
  final String currency;
  final String instructionRu;
  final String instructionEn;

  const CreateUsdtPaymentResult({
    required this.paymentId,
    required this.orderId,
    required this.walletAddress,
    required this.rubAmount,
    required this.usdtAmount,
    required this.formattedUsdtAmount,
    required this.cbrRate,
    required this.effectiveRate,
    required this.markupPercent,
    required this.expiresAt,
    required this.expiresInMinutes,
    required this.network,
    required this.currency,
    required this.instructionRu,
    required this.instructionEn,
  });

  factory CreateUsdtPaymentResult.fromJson(Map<String, dynamic> json) {
    final amount = json['amount'] as Map<String, dynamic>;
    final exchangeRate = json['exchangeRate'] as Map<String, dynamic>;
    final instructions = json['instructions'] as Map<String, dynamic>;

    return CreateUsdtPaymentResult(
      paymentId: json['paymentId'] as int,
      orderId: json['orderId'] as String,
      walletAddress: json['walletAddress'] as String,
      rubAmount: (amount['rub'] as num).toDouble(),
      usdtAmount: (amount['usdt'] as num).toDouble(),
      formattedUsdtAmount: amount['formatted'] as String,
      cbrRate: (exchangeRate['cbrRate'] as num).toDouble(),
      effectiveRate: (exchangeRate['effectiveRate'] as num).toDouble(),
      markupPercent: (exchangeRate['markupPercent'] as num).toDouble(),
      expiresAt: DateTime.parse(json['expiresAt'] as String),
      expiresInMinutes: json['expiresInMinutes'] as int,
      network: json['network'] as String,
      currency: json['currency'] as String,
      instructionRu: instructions['ru'] as String,
      instructionEn: instructions['en'] as String,
    );
  }

  /// Оставшееся время до истечения (в минутах)
  int get remainingMinutes {
    final diff = expiresAt.difference(DateTime.now());
    if (diff.isNegative) return 0;
    return diff.inMinutes;
  }

  /// Проверка истечения срока платежа
  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

/// Результат проверки статуса USDT платежа
class UsdtPaymentCheckResult {
  final int paymentId;
  final String status;
  final String? txHash;
  final double? rubAmount;
  final double? usdtAmount;
  final DateTime? paidAt;
  final String? walletAddress;
  final double? expectedAmount;
  final DateTime? expiresAt;
  final int? remainingMinutes;
  final String message;

  const UsdtPaymentCheckResult({
    required this.paymentId,
    required this.status,
    this.txHash,
    this.rubAmount,
    this.usdtAmount,
    this.paidAt,
    this.walletAddress,
    this.expectedAmount,
    this.expiresAt,
    this.remainingMinutes,
    required this.message,
  });

  factory UsdtPaymentCheckResult.fromJson(Map<String, dynamic> json) {
    final amount = json['amount'] as Map<String, dynamic>?;

    return UsdtPaymentCheckResult(
      paymentId: json['paymentId'] as int,
      status: json['status'] as String,
      txHash: json['txHash'] as String?,
      rubAmount: amount != null ? (amount['rub'] as num?)?.toDouble() : null,
      usdtAmount: amount != null ? (amount['usdt'] as num?)?.toDouble() : null,
      paidAt: json['paidAt'] != null
          ? DateTime.parse(json['paidAt'] as String)
          : null,
      walletAddress: json['walletAddress'] as String?,
      expectedAmount: json['expectedAmount'] != null
          ? (json['expectedAmount'] as num).toDouble()
          : null,
      expiresAt: json['expiresAt'] != null
          ? DateTime.parse(json['expiresAt'] as String)
          : null,
      remainingMinutes: json['remainingMinutes'] as int?,
      message: json['message'] as String,
    );
  }

  bool get isSuccess => status == 'success';
  bool get isPending => status == 'pending';
  bool get isConfirming => status == 'confirming';
  bool get isExpired => status == 'expired';
  bool get isFailed => status == 'fail' || status == 'expired';
}

/// Информация о курсе USDT
class UsdtRateInfo {
  final double cbrRate;
  final double effectiveRate;
  final double markupPercent;
  final String formattedRate;
  final String walletAddress;
  final double minAmountUsdt;
  final double? convertedUsdt;
  final double? originalRub;

  const UsdtRateInfo({
    required this.cbrRate,
    required this.effectiveRate,
    required this.markupPercent,
    required this.formattedRate,
    required this.walletAddress,
    required this.minAmountUsdt,
    this.convertedUsdt,
    this.originalRub,
  });

  factory UsdtRateInfo.fromJson(Map<String, dynamic> json) {
    final conversion = json['conversion'] as Map<String, dynamic>?;

    return UsdtRateInfo(
      cbrRate: (json['cbrRate'] as num).toDouble(),
      effectiveRate: (json['effectiveRate'] as num).toDouble(),
      markupPercent: (json['markupPercent'] as num).toDouble(),
      formattedRate: json['formattedRate'] as String,
      walletAddress: json['walletAddress'] as String,
      minAmountUsdt: (json['minAmountUsdt'] as num).toDouble(),
      convertedUsdt: conversion != null
          ? (conversion['usdtAmount'] as num?)?.toDouble()
          : null,
      originalRub: conversion != null
          ? (conversion['rubAmount'] as num?)?.toDouble()
          : null,
    );
  }
}
