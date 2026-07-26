import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';

/// Текущий режим операторов, которые обрабатывают оплату в рублях.
///
/// При недоступности внешнего сервиса используем fail-open: считаем, что
/// операторы работают, чтобы временный сетевой сбой не блокировал оплату.
class PaymentOperatorStatus {
  final bool sleeping;
  final bool reachable;
  final DateTime? updatedAt;
  final DateTime? checkedAt;

  const PaymentOperatorStatus({
    required this.sleeping,
    required this.reachable,
    this.updatedAt,
    this.checkedAt,
  });

  static const workingFallback = PaymentOperatorStatus(
    sleeping: false,
    reachable: false,
  );

  bool get working => !sleeping;

  factory PaymentOperatorStatus.fromJson(Map<String, dynamic> json) {
    final nested = json['operatorStatus'];
    final source = nested is Map ? Map<String, dynamic>.from(nested) : json;
    return PaymentOperatorStatus(
      sleeping: source['sleeping'] == true,
      reachable: source['reachable'] == true,
      updatedAt: DateTime.tryParse(source['updatedAt']?.toString() ?? ''),
      checkedAt: DateTime.tryParse(source['checkedAt']?.toString() ?? ''),
    );
  }
}

class PaymentOperatorStatusService {
  final ApiClient _apiClient;

  PaymentOperatorStatusService(this._apiClient);

  Future<PaymentOperatorStatus> getStatus() async {
    try {
      final response = await _apiClient.get('/client/payments/operator-status');
      if (response.statusCode == 200 && response.data is Map) {
        return PaymentOperatorStatus.fromJson(
          Map<String, dynamic>.from(response.data as Map),
        );
      }
    } on DioException catch (error) {
      debugPrint('getPaymentOperatorStatus error: $error');
    } catch (error) {
      debugPrint('getPaymentOperatorStatus parse error: $error');
    }
    return PaymentOperatorStatus.workingFallback;
  }
}

final paymentOperatorStatusServiceProvider =
    Provider<PaymentOperatorStatusService>((ref) {
      return PaymentOperatorStatusService(ref.read(apiClientProvider));
    });

/// Общий источник статуса для Самовыкупа, Счетов и Гаража.
///
/// Пока хотя бы один платежный экран открыт, статус обновляется раз в минуту.
final paymentOperatorStatusProvider =
    StreamProvider.autoDispose<PaymentOperatorStatus>((ref) {
      final controller = StreamController<PaymentOperatorStatus>();
      Timer? timer;
      var requestInFlight = false;

      Future<void> load() async {
        if (requestInFlight || controller.isClosed) return;
        requestInFlight = true;
        final status = await ref
            .read(paymentOperatorStatusServiceProvider)
            .getStatus();
        requestInFlight = false;
        if (!controller.isClosed) {
          controller.add(status);
        }
      }

      Future<void>.microtask(load);
      timer = Timer.periodic(const Duration(minutes: 1), (_) => load());
      ref.onDispose(() {
        timer?.cancel();
        unawaited(controller.close());
      });
      return controller.stream;
    });

PaymentOperatorStatus paymentOperatorStatusOrWorking(
  AsyncValue<PaymentOperatorStatus> value,
) {
  return value.asData?.value ?? PaymentOperatorStatus.workingFallback;
}
