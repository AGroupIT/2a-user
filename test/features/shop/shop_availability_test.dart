import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twoalogisticcabineuser/src/core/network/api_client.dart';
import 'package:twoalogisticcabineuser/src/features/clients/application/client_codes_controller.dart';
import 'package:twoalogisticcabineuser/src/features/shop/data/shop_availability_provider.dart';

void main() {
  test('1688 catalog is available only when API grants the capability', () {
    final availability = MarketplaceAvailability.fromJson({
      'available': true,
      'reason': null,
      'platforms': [
        {
          'code': '1688',
          'nameRu': '1688',
          'nameZh': '1688',
          'available': true,
          'reason': null,
          'capabilities': {
            'catalog': true,
            'purchaseList': true,
            'orderHistory': true,
          },
        },
      ],
    });

    expect(availability.canBrowse('1688'), isTrue);
    expect(availability.canUsePurchaseList('1688'), isTrue);
    expect(availability.canBrowse('taobao'), isFalse);
  });

  test('top-level denial wins even if a platform payload says available', () {
    final availability = MarketplaceAvailability.fromJson({
      'available': false,
      'reason': 'agent_marketplaces_disabled',
      'platforms': [
        {
          'code': '1688',
          'available': true,
          'capabilities': {'catalog': true, 'purchaseList': true},
        },
      ],
    });

    expect(availability.canBrowse('1688'), isFalse);
    expect(availability.canUsePurchaseList('1688'), isFalse);
  });

  test('JD may expose catalog while purchase workflow remains disabled', () {
    final availability = MarketplaceAvailability.fromJson({
      'available': true,
      'platforms': [
        {
          'code': 'jd',
          'nameRu': 'JD',
          'nameZh': '京东',
          'available': true,
          'capabilities': {
            'catalog': true,
            'purchaseList': false,
            'orderHistory': false,
          },
        },
      ],
    });

    expect(availability.hasBrowsablePlatform, isTrue);
    expect(availability.browsablePlatformCodes, ['jd']);
    expect(availability.canBrowse('jd'), isTrue);
    expect(availability.canUsePurchaseList('jd'), isFalse);
    expect(availability.platform('jd')?.capabilities.orderHistory, isFalse);
  });

  test('availability request fails closed on a network error', () async {
    final result = await ShopAvailabilityService(
      _FailingApiClient(),
    ).getAvailability();

    expect(result.available, isFalse);
    expect(result.reason, 'availability_unavailable');
    expect(result.canBrowse('1688'), isFalse);
  });

  test(
    'disposing during the request does not register a refresh on a dead ref',
    () async {
      final service = _DeferredShopAvailabilityService();
      final container = ProviderContainer(
        overrides: [
          activeClientCodeProvider.overrideWithValue('A-001'),
          shopAvailabilityServiceProvider.overrideWithValue(service),
          shopAvailabilityRefreshIntervalProvider.overrideWithValue(
            Duration.zero,
          ),
        ],
      );
      addTearDown(container.dispose);

      final subscription = container.listen(
        shopAvailabilityProvider,
        (_, _) {},
        fireImmediately: true,
      );
      await service.started.future;

      subscription.close();
      await container.pump();
      service.complete(MarketplaceAvailability.unavailable);
      await Future<void>.delayed(Duration.zero);
      await container.pump();

      expect(service.requestCount, 1);
    },
  );
}

class _FailingApiClient extends ApiClient {
  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    throw DioException(
      requestOptions: RequestOptions(path: path),
      type: DioExceptionType.connectionError,
    );
  }
}

class _DeferredShopAvailabilityService extends ShopAvailabilityService {
  _DeferredShopAvailabilityService() : super(_FailingApiClient());

  final started = Completer<void>();
  final _result = Completer<MarketplaceAvailability>();
  int requestCount = 0;

  @override
  Future<MarketplaceAvailability> getAvailability() {
    requestCount++;
    if (!started.isCompleted) started.complete();
    return _result.future;
  }

  void complete(MarketplaceAvailability value) {
    _result.complete(value);
  }
}
