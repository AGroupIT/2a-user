import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../domain/payment_model.dart';

/// Параметры для создания платежа
class CreatePaymentParams {
  final double amount;
  final int? invoiceId;
  final String? description;
  final String? custom;

  const CreatePaymentParams({
    required this.amount,
    this.invoiceId,
    this.description,
    this.custom,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CreatePaymentParams &&
          runtimeType == other.runtimeType &&
          amount == other.amount &&
          invoiceId == other.invoiceId &&
          description == other.description &&
          custom == other.custom;

  @override
  int get hashCode =>
      amount.hashCode ^
      invoiceId.hashCode ^
      description.hashCode ^
      custom.hashCode;
}

/// Провайдер для создания платежа
final createPaymentProvider =
    FutureProvider.family<CreatePaymentResult?, CreatePaymentParams>(
        (ref, params) async {
  final apiClient = ref.read(apiClientProvider);

  try {
    final response = await apiClient.post(
      '/payments/pally/create',
      data: {
        'amount': params.amount,
        if (params.invoiceId != null) 'invoiceId': params.invoiceId,
        if (params.description != null) 'description': params.description,
        if (params.custom != null) 'custom': params.custom,
      },
    );

    if (response.statusCode == 200 && response.data != null) {
      return CreatePaymentResult.fromJson(response.data as Map<String, dynamic>);
    }
    return null;
  } on DioException catch (e) {
    debugPrint('Error creating payment: $e');
    rethrow;
  }
});

/// Параметры для получения списка платежей
class PaymentsListParams {
  final String? status;
  final int skip;
  final int take;

  const PaymentsListParams({
    this.status,
    this.skip = 0,
    this.take = 50,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PaymentsListParams &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          skip == other.skip &&
          take == other.take;

  @override
  int get hashCode => status.hashCode ^ skip.hashCode ^ take.hashCode;
}

/// Провайдер для получения списка платежей
final paymentsListProvider =
    FutureProvider.family<List<Payment>, PaymentsListParams>(
        (ref, params) async {
  final apiClient = ref.read(apiClientProvider);

  try {
    final response = await apiClient.get(
      '/payments',
      queryParameters: {
        if (params.status != null) 'status': params.status,
        'skip': params.skip,
        'take': params.take,
      },
    );

    if (response.statusCode == 200 && response.data != null) {
      final data = response.data as Map<String, dynamic>;
      final paymentsJson = data['data'] as List<dynamic>? ?? [];

      return paymentsJson
          .map((json) => Payment.fromJson(json as Map<String, dynamic>))
          .toList();
    }
    return [];
  } on DioException catch (e) {
    debugPrint('Error loading payments: $e');
    return [];
  }
});

/// Провайдер для получения платежа по ID
final paymentByIdProvider =
    FutureProvider.family<Payment?, int>((ref, paymentId) async {
  final apiClient = ref.read(apiClientProvider);

  try {
    final response = await apiClient.get('/payments/$paymentId');

    if (response.statusCode == 200 && response.data != null) {
      return Payment.fromJson(response.data as Map<String, dynamic>);
    }
    return null;
  } on DioException catch (e) {
    debugPrint('Error loading payment: $e');
    return null;
  }
});

/// Сервис для работы с платежами
class PaymentService {
  final ApiClient _apiClient;

  PaymentService(this._apiClient);

  /// Создать платёж (Pally - карта/СБП)
  Future<CreatePaymentResult?> createPayment({
    required double amount,
    int? invoiceId,
    String? description,
    String? custom,
  }) async {
    try {
      final response = await _apiClient.post(
        '/payments/pally/create',
        data: {
          'amount': amount,
          if (invoiceId != null) 'invoiceId': invoiceId,
          if (description != null) 'description': description,
          if (custom != null) 'custom': custom,
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        return CreatePaymentResult.fromJson(
            response.data as Map<String, dynamic>);
      }
      return null;
    } on DioException catch (e) {
      debugPrint('Error creating payment: $e');
      rethrow;
    }
  }

  /// Создать USDT TRC20 платёж
  Future<CreateUsdtPaymentResult?> createUsdtPayment({
    required double amount,
    int? invoiceId,
    String? description,
    String? custom,
  }) async {
    try {
      final response = await _apiClient.post(
        '/payments/usdt/create',
        data: {
          'amount': amount,
          if (invoiceId != null) 'invoiceId': invoiceId,
          if (description != null) 'description': description,
          if (custom != null) 'custom': custom,
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        return CreateUsdtPaymentResult.fromJson(
            response.data as Map<String, dynamic>);
      }
      return null;
    } on DioException catch (e) {
      debugPrint('Error creating USDT payment: $e');
      rethrow;
    }
  }

  /// Проверить статус USDT платежа
  Future<UsdtPaymentCheckResult?> checkUsdtPayment(int paymentId) async {
    try {
      final response = await _apiClient.get(
        '/payments/usdt/check',
        queryParameters: {'paymentId': paymentId},
      );

      if (response.statusCode == 200 && response.data != null) {
        return UsdtPaymentCheckResult.fromJson(
            response.data as Map<String, dynamic>);
      }
      return null;
    } on DioException catch (e) {
      debugPrint('Error checking USDT payment: $e');
      return null;
    }
  }

  /// Получить текущий курс USDT
  Future<UsdtRateInfo?> getUsdtRate({double? rubAmount}) async {
    try {
      final response = await _apiClient.get(
        '/payments/usdt/rate',
        queryParameters: rubAmount != null ? {'amount': rubAmount} : null,
      );

      if (response.statusCode == 200 && response.data != null) {
        return UsdtRateInfo.fromJson(response.data as Map<String, dynamic>);
      }
      return null;
    } on DioException catch (e) {
      debugPrint('Error getting USDT rate: $e');
      return null;
    }
  }
}

/// Провайдер для PaymentService
final paymentServiceProvider = Provider<PaymentService>((ref) {
  final apiClient = ref.read(apiClientProvider);
  return PaymentService(apiClient);
});

/// Провайдер для получения курса USDT
final usdtRateProvider =
    FutureProvider.family<UsdtRateInfo?, double?>((ref, rubAmount) async {
  final paymentService = ref.read(paymentServiceProvider);
  return paymentService.getUsdtRate(rubAmount: rubAmount);
});

/// Параметры для создания USDT платежа
class CreateUsdtPaymentParams {
  final double amount;
  final int? invoiceId;
  final String? description;
  final String? custom;

  const CreateUsdtPaymentParams({
    required this.amount,
    this.invoiceId,
    this.description,
    this.custom,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CreateUsdtPaymentParams &&
          runtimeType == other.runtimeType &&
          amount == other.amount &&
          invoiceId == other.invoiceId &&
          description == other.description &&
          custom == other.custom;

  @override
  int get hashCode =>
      amount.hashCode ^
      invoiceId.hashCode ^
      description.hashCode ^
      custom.hashCode;
}

/// Провайдер для создания USDT платежа
final createUsdtPaymentProvider =
    FutureProvider.family<CreateUsdtPaymentResult?, CreateUsdtPaymentParams>(
        (ref, params) async {
  final paymentService = ref.read(paymentServiceProvider);

  return paymentService.createUsdtPayment(
    amount: params.amount,
    invoiceId: params.invoiceId,
    description: params.description,
    custom: params.custom,
  );
});

/// Провайдер для проверки статуса USDT платежа
final checkUsdtPaymentProvider =
    FutureProvider.family<UsdtPaymentCheckResult?, int>((ref, paymentId) async {
  final paymentService = ref.read(paymentServiceProvider);
  return paymentService.checkUsdtPayment(paymentId);
});
