import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twoalogisticcabineuser/src/core/network/api_client.dart';
import 'package:twoalogisticcabineuser/src/features/sp_finance/data/sp_organizer_customer_models.dart';
import 'package:twoalogisticcabineuser/src/features/sp_finance/data/sp_organizer_models.dart';
import 'package:twoalogisticcabineuser/src/features/sp_finance/data/sp_organizer_provider.dart';
import 'package:twoalogisticcabineuser/src/features/sp_finance/data/sp_organizer_repository.dart';

void main() {
  test('customer search ignores a stale response that finishes last', () async {
    final repository = _DeferredOrganizerRepository();
    final container = ProviderContainer(
      overrides: [spOrganizerRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    final controller = container.read(
      spOrganizerCustomersControllerProvider.notifier,
    );

    final oldSearch = controller.search('old');
    final newSearch = controller.search('new');
    repository.completeCustomer('new', id: 2, name: 'Новый клиент');
    await newSearch;
    repository.completeCustomer('old', id: 1, name: 'Старый клиент');
    await oldSearch;

    final state = container.read(spOrganizerCustomersControllerProvider);
    expect(state.query, 'new');
    expect(state.customers.single.id, 2);
    expect(state.error, isNull);
  });

  test(
    'product search ignores stale success and supports retry after error',
    () async {
      final repository = _DeferredOrganizerRepository();
      final container = ProviderContainer(
        overrides: [
          spOrganizerRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(
        spOrganizerProductsControllerProvider.notifier,
      );

      final initial = controller.search('initial');
      repository.completeProduct('initial', id: 1, title: 'Исходный товар');
      await initial;

      final staleSearch = controller.search('stale');
      final failedSearch = controller.search('offline');
      repository.failProduct('offline', StateError('network unavailable'));
      await failedSearch;
      repository.completeProduct('stale', id: 2, title: 'Устаревший товар');
      await staleSearch;

      var state = container.read(spOrganizerProductsControllerProvider);
      expect(state.query, 'offline');
      expect(state.products.single.id, 1);
      expect(state.error, contains('network unavailable'));

      final retry = controller.search('offline');
      repository.completeProduct('offline', id: 3, title: 'После retry');
      await retry;
      state = container.read(spOrganizerProductsControllerProvider);
      expect(state.query, 'offline');
      expect(state.products.single.id, 3);
      expect(state.error, isNull);
    },
  );

  test('identical concurrent loads share one repository request', () async {
    final repository = _DeferredOrganizerRepository();
    final container = ProviderContainer(
      overrides: [spOrganizerRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    final controller = container.read(
      spOrganizerProductsControllerProvider.notifier,
    );

    final first = controller.search('same');
    final second = controller.search('same');
    expect(repository.productRequestCount('same'), 1);
    repository.completeProduct('same', id: 4, title: 'Один запрос');
    await Future.wait([first, second]);

    expect(repository.productRequestCount('same'), 1);
  });
}

class _DeferredOrganizerRepository extends SpOrganizerRepository {
  _DeferredOrganizerRepository() : super(ApiClient());

  final _customerRequests =
      <String, List<Completer<SpOrganizerCustomerPage>>>{};
  final _productRequests = <String, List<Completer<SpOrganizerProductPage>>>{};

  @override
  Future<SpOrganizerCustomerPage> getCustomersDirectory({
    String? query,
    String scope = 'active',
    int page = 1,
    int limit = 30,
    String sortBy = 'fullName',
    String sortDirection = 'asc',
  }) {
    final completer = Completer<SpOrganizerCustomerPage>();
    _customerRequests.putIfAbsent(query ?? '', () => []).add(completer);
    return completer.future;
  }

  @override
  Future<SpOrganizerProductPage> getProducts({
    String? query,
    int page = 1,
    int limit = 40,
    bool includeArchived = false,
    String sortBy = 'title',
    String sortDirection = 'asc',
  }) {
    final completer = Completer<SpOrganizerProductPage>();
    _productRequests.putIfAbsent(query ?? '', () => []).add(completer);
    return completer.future;
  }

  void completeCustomer(String query, {required int id, required String name}) {
    _take(_customerRequests, query).complete(
      SpOrganizerCustomerPage(
        items: [SpOrganizerCustomer(id: id, fullName: name)],
        total: 1,
        totalPages: 1,
      ),
    );
  }

  void completeProduct(String query, {required int id, required String title}) {
    _take(_productRequests, query).complete(
      SpOrganizerProductPage(
        items: [SpOrganizerProduct(id: id, title: title)],
        total: 1,
        totalPages: 1,
      ),
    );
  }

  void failProduct(String query, Object error) {
    _take(_productRequests, query).completeError(error);
  }

  int productRequestCount(String query) => _productRequests[query]?.length ?? 0;

  Completer<T> _take<T>(Map<String, List<Completer<T>>> requests, String key) {
    final pending = requests[key]?.where((item) => !item.isCompleted).toList();
    if (pending == null || pending.isEmpty) {
      throw StateError('No pending request for $key');
    }
    return pending.first;
  }
}
