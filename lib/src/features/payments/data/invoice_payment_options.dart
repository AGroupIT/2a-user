import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';

class InvoicePaymentMethodOption {
  const InvoicePaymentMethodOption({
    required this.code,
    required this.currency,
    required this.available,
    this.unavailableReason,
  });
  final String code;
  final String currency;
  final bool available;
  final String? unavailableReason;

  factory InvoicePaymentMethodOption.fromJson(Map<String, dynamic> json) =>
      InvoicePaymentMethodOption(
        code: json['code'] as String,
        currency: json['currency'] as String? ?? '',
        available: json['available'] == true,
        unavailableReason: json['unavailableReason'] as String?,
      );
}

class InvoicePaymentSelection {
  const InvoicePaymentSelection({
    required this.method,
    this.paymentId,
    this.currency = '',
    this.amount = 0,
    this.qrImageUrl,
    this.walletAddress,
    this.network,
    this.canChange = false,
  });
  final String method;
  final int? paymentId;
  final String currency;
  final double amount;
  final String? qrImageUrl;
  final String? walletAddress;
  final String? network;
  final bool canChange;

  factory InvoicePaymentSelection.fromJson(Map<String, dynamic> json) {
    final method = json['method'] as String;
    final amount = double.tryParse(json['amount']?.toString() ?? '') ?? 0;
    final selection = InvoicePaymentSelection(
      method: method,
      paymentId: int.tryParse(json['paymentId']?.toString() ?? ''),
      currency: json['currency'] as String? ?? '',
      amount: amount,
      qrImageUrl: json['qrImageUrl'] as String?,
      walletAddress: json['walletAddress'] as String?,
      network: json['network'] as String?,
      canChange: json['canChange'] == true,
    );
    if ((method == 'usdt_trc20' || method == 'alipay') &&
        (selection.paymentId == null ||
            selection.currency != (method == 'alipay' ? 'CNY' : 'USDT') ||
            !amount.isFinite ||
            amount <= 0 ||
            selection.qrImageUrl?.isNotEmpty != true ||
            (method == 'usdt_trc20' &&
                selection.walletAddress?.isNotEmpty != true))) {
      throw const FormatException('Incomplete invoice payment details');
    }
    return selection;
  }
}

class InvoicePaymentOptions {
  const InvoicePaymentOptions({
    required this.methods,
    required this.canChange,
    this.activeMethod,
    this.lockedReason,
    this.activePayment,
  });
  final List<InvoicePaymentMethodOption> methods;
  final bool canChange;
  final String? activeMethod;
  final String? lockedReason;
  final InvoicePaymentSelection? activePayment;

  factory InvoicePaymentOptions.fromJson(Map<String, dynamic> json) =>
      InvoicePaymentOptions(
        methods: (json['methods'] as List? ?? const [])
            .map(
              (value) => InvoicePaymentMethodOption.fromJson(
                Map<String, dynamic>.from(value as Map),
              ),
            )
            .toList(growable: false),
        canChange: json['canChange'] == true,
        activeMethod: json['activeMethod'] as String?,
        lockedReason: json['lockedReason'] as String?,
        activePayment: json['activePayment'] is Map
            ? InvoicePaymentSelection.fromJson(
                Map<String, dynamic>.from(json['activePayment'] as Map),
              )
            : null,
      );
}

class InvoicePaymentOptionsService {
  InvoicePaymentOptionsService(this.api);
  final ApiClient api;

  Map<String, dynamic> _data(dynamic payload) {
    final map = Map<String, dynamic>.from(payload as Map);
    return map['data'] is Map
        ? Map<String, dynamic>.from(map['data'] as Map)
        : map;
  }

  Future<InvoicePaymentOptions> fetch(String invoiceId) async {
    final response = await api.get(
      '/client/invoices/$invoiceId/payment-options',
    );
    return InvoicePaymentOptions.fromJson(_data(response.data));
  }

  Future<InvoicePaymentSelection> select(
    String invoiceId,
    String method,
  ) async {
    final response = await api.post(
      '/client/invoices/$invoiceId/payment-method',
      data: {'method': method},
    );
    return InvoicePaymentSelection.fromJson(_data(response.data));
  }
}

final invoicePaymentOptionsServiceProvider =
    Provider<InvoicePaymentOptionsService>(
      (ref) => InvoicePaymentOptionsService(ref.read(apiClientProvider)),
    );
