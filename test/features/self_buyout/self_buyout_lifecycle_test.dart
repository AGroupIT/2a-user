import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twoalogisticcabineuser/src/core/network/api_client.dart';
import 'package:twoalogisticcabineuser/src/features/payments/data/payment_operator_status.dart';
import 'package:twoalogisticcabineuser/src/features/self_buyout/data/self_buyout_models.dart';
import 'package:twoalogisticcabineuser/src/features/self_buyout/data/self_buyout_service.dart';
import 'package:twoalogisticcabineuser/src/features/self_buyout/presentation/self_buyout_screen.dart';

const _request = SelfBuyoutRequest(
  id: 293,
  requestNumber: 'SB-LIFECYCLE-293',
  status: 'awaiting_payment',
  clientCodeId: 20,
  requestedCnyAmount: 100,
  paymentRubAmount: 1200,
  clientCnyRubRate: 12,
  amountEnteredIn: 'cny',
);

void main() {
  testWidgets('closing QR after host route removal does not use disposed ref', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    final observer = _PageRouteObserver();
    final service = _LifecycleSelfBuyoutService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          selfBuyoutServiceProvider.overrideWithValue(service),
          paymentOperatorStatusProvider.overrideWith(
            (ref) => Stream.value(PaymentOperatorStatus.workingFallback),
          ),
        ],
        child: MaterialApp(
          navigatorKey: navigatorKey,
          navigatorObservers: [observer],
          home: const Scaffold(body: SelfBuyoutScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(_request.requestNumber).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Продолжить оплату'));
    await tester.pumpAndSettle();

    expect(service.startCalls, 1);
    final hostRoute = observer.pageRoutes.single;
    navigatorKey.currentState!.removeRoute(hostRoute);
    await tester.pump();
    navigatorKey.currentState!.pop(true);
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}

class _PageRouteObserver extends NavigatorObserver {
  final List<Route<dynamic>> pageRoutes = [];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PageRoute<dynamic>) pageRoutes.add(route);
  }
}

class _LifecycleSelfBuyoutService extends SelfBuyoutService {
  _LifecycleSelfBuyoutService() : super(ApiClient());

  int startCalls = 0;

  @override
  Future<SelfBuyoutAvailability> getAvailability() async =>
      SelfBuyoutAvailability.unavailable;

  @override
  Future<List<SelfBuyoutRequest>> getRequests() async => const [_request];

  @override
  Future<SelfBuyoutDetail> getDetail(int requestId) async =>
      const SelfBuyoutDetail(request: _request);

  @override
  Future<SelfBuyoutPaymentInfo?> startBankQr(int requestId) async {
    startCalls++;
    return const SelfBuyoutPaymentInfo(
      paymentId: 9,
      status: 'pending',
      amountRub: 1200,
      sumKopecks: 120000,
      purpose: 'Самовыкуп',
      qrPayload: 'ST00012|Name=Test|Sum=120000|Purpose=SelfBuyout',
    );
  }
}
