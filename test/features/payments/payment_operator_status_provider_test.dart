import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twoalogisticcabineuser/src/core/network/api_client.dart';
import 'package:twoalogisticcabineuser/src/features/payments/data/payment_operator_status.dart';

void main() {
  test(
    'keeps first load alive when the last listener closes immediately',
    () async {
      final service = _PendingPaymentOperatorStatusService();
      final container = ProviderContainer(
        overrides: [
          paymentOperatorStatusServiceProvider.overrideWithValue(service),
        ],
      );

      final subscription = container.listen(
        paymentOperatorStatusProvider,
        (_, _) {},
        fireImmediately: true,
      );

      subscription.close();
      await container.pump();

      expect(service.calls, 1);
      expect(container.exists(paymentOperatorStatusProvider), isTrue);

      service.pending.complete(PaymentOperatorStatus.workingFallback);
      await container.pump();
      await container.pump();

      container.dispose();
    },
  );
}

class _PendingPaymentOperatorStatusService
    extends PaymentOperatorStatusService {
  _PendingPaymentOperatorStatusService() : super(ApiClient());

  int calls = 0;
  final Completer<PaymentOperatorStatus> pending = Completer();

  @override
  Future<PaymentOperatorStatus> getStatus() {
    calls++;
    return pending.future;
  }
}
