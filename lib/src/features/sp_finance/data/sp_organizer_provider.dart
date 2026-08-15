import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/services/demo_mode_provider.dart';
import 'sp_organizer_analytics_models.dart';
import 'sp_organizer_calculation_models.dart';
import 'sp_organizer_customer_models.dart';
import 'sp_organizer_fulfillment_models.dart';
import 'sp_organizer_models.dart';
import 'sp_organizer_repository.dart';

final spOrganizerRepositoryProvider = Provider<SpOrganizerRepository>((ref) {
  return SpOrganizerRepository(ref.watch(apiClientProvider));
});

final spOrganizerCapabilitiesProvider = FutureProvider<SpOrganizerCapabilities>(
  (ref) async {
    if (ref.watch(demoModeProvider)) {
      return SpOrganizerCapabilities.unavailable;
    }
    return ref.watch(spOrganizerRepositoryProvider).getCapabilities();
  },
);

final spOrganizerAnalyticsProvider = FutureProvider.autoDispose
    .family<SpOrganizerAnalytics, SpOrganizerAnalyticsFilter>((
      ref,
      filter,
    ) async {
      return ref.watch(spOrganizerRepositoryProvider).getAnalytics(filter);
    });

final spOrganizerProductDetailProvider = FutureProvider.autoDispose
    .family<SpOrganizerProductDetail, SpOrganizerProductDetailQuery>((
      ref,
      query,
    ) async {
      if (ref.watch(demoModeProvider)) {
        throw StateError('SP organizer is unavailable in demo mode');
      }
      return ref.watch(spOrganizerRepositoryProvider).getProductDetail(query);
    });

class SpOrganizerCustomersState {
  final List<SpOrganizerCustomer> customers;
  final int total;
  final int page;
  final int totalPages;
  final int limit;
  final String query;
  final String scope;
  final String sortBy;
  final String sortDirection;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;

  const SpOrganizerCustomersState({
    this.customers = const [],
    this.total = 0,
    this.page = 1,
    this.totalPages = 0,
    this.limit = 30,
    this.query = '',
    this.scope = 'active',
    this.sortBy = 'fullName',
    this.sortDirection = 'asc',
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
  });

  bool get hasMore => page < totalPages;

  SpOrganizerCustomersState copyWith({
    List<SpOrganizerCustomer>? customers,
    int? total,
    int? page,
    int? totalPages,
    int? limit,
    String? query,
    String? scope,
    String? sortBy,
    String? sortDirection,
    bool? isLoading,
    bool? isLoadingMore,
    Object? error = _notSet,
  }) {
    return SpOrganizerCustomersState(
      customers: customers ?? this.customers,
      total: total ?? this.total,
      page: page ?? this.page,
      totalPages: totalPages ?? this.totalPages,
      limit: limit ?? this.limit,
      query: query ?? this.query,
      scope: scope ?? this.scope,
      sortBy: sortBy ?? this.sortBy,
      sortDirection: sortDirection ?? this.sortDirection,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: identical(error, _notSet) ? this.error : error as String?,
    );
  }
}

class SpOrganizerCustomersController
    extends Notifier<SpOrganizerCustomersState> {
  Future<void>? _loadFuture;
  int _loadRevision = 0;

  @override
  SpOrganizerCustomersState build() {
    ref.watch(demoModeProvider);
    return const SpOrganizerCustomersState();
  }

  Future<void> load({
    bool silent = false,
    String? query,
    String? scope,
    String? sortBy,
    String? sortDirection,
  }) {
    final nextQuery = query ?? state.query;
    final nextScope = scope ?? state.scope;
    final nextSortBy = sortBy ?? state.sortBy;
    final nextSortDirection = sortDirection ?? state.sortDirection;
    if (_loadFuture != null &&
        nextQuery == state.query &&
        nextScope == state.scope &&
        nextSortBy == state.sortBy &&
        nextSortDirection == state.sortDirection) {
      return _loadFuture!;
    }

    final revision = ++_loadRevision;
    late final Future<void> future;
    future =
        _loadFirstPage(
          revision: revision,
          silent: silent,
          query: nextQuery,
          scope: nextScope,
          sortBy: nextSortBy,
          sortDirection: nextSortDirection,
        ).whenComplete(() {
          if (identical(_loadFuture, future)) _loadFuture = null;
        });
    _loadFuture = future;
    return future;
  }

  Future<void> search(String query) => load(query: query);

  Future<void> setScope(String scope) => load(scope: scope);

  Future<void> setSort(String sortBy, String sortDirection) =>
      load(sortBy: sortBy, sortDirection: sortDirection);

  Future<void> loadMore() async {
    if (state.isLoading ||
        state.isLoadingMore ||
        !state.hasMore ||
        ref.read(demoModeProvider)) {
      return;
    }
    state = state.copyWith(isLoadingMore: true, error: null);
    final revision = _loadRevision;
    try {
      final page = await ref
          .read(spOrganizerRepositoryProvider)
          .getCustomersDirectory(
            query: state.query,
            scope: state.scope,
            page: state.page + 1,
            limit: state.limit,
            sortBy: state.sortBy,
            sortDirection: state.sortDirection,
          );
      if (revision != _loadRevision) return;
      state = state.copyWith(
        customers: [...state.customers, ...page.items],
        total: page.total,
        page: page.page,
        totalPages: page.totalPages,
        limit: page.limit,
        isLoadingMore: false,
        error: null,
      );
    } catch (error) {
      if (revision != _loadRevision) return;
      state = state.copyWith(isLoadingMore: false, error: error.toString());
    }
  }

  Future<void> archiveCustomer(int customerId, {String? reason}) async {
    await ref
        .read(spOrganizerRepositoryProvider)
        .archiveCustomer(customerId, reason: reason);
    await load(silent: true);
  }

  Future<void> restoreCustomer(int customerId) async {
    await ref.read(spOrganizerRepositoryProvider).restoreCustomer(customerId);
    await load(silent: true);
  }

  Future<void> _loadFirstPage({
    required int revision,
    required bool silent,
    required String query,
    required String scope,
    required String sortBy,
    required String sortDirection,
  }) async {
    if (ref.read(demoModeProvider)) {
      state = SpOrganizerCustomersState(
        query: query,
        scope: scope,
        sortBy: sortBy,
        sortDirection: sortDirection,
      );
      return;
    }
    if (!silent) {
      state = state.copyWith(
        isLoading: true,
        query: query,
        scope: scope,
        sortBy: sortBy,
        sortDirection: sortDirection,
        error: null,
      );
    }
    try {
      final page = await ref
          .read(spOrganizerRepositoryProvider)
          .getCustomersDirectory(
            query: query,
            scope: scope,
            page: 1,
            limit: state.limit,
            sortBy: sortBy,
            sortDirection: sortDirection,
          );
      if (revision != _loadRevision) return;
      state = SpOrganizerCustomersState(
        customers: page.items,
        total: page.total,
        page: page.page,
        totalPages: page.totalPages,
        limit: page.limit,
        query: query,
        scope: scope,
        sortBy: sortBy,
        sortDirection: sortDirection,
      );
    } catch (error) {
      if (revision != _loadRevision) return;
      state = state.copyWith(
        query: query,
        scope: scope,
        sortBy: sortBy,
        sortDirection: sortDirection,
        isLoading: false,
        isLoadingMore: false,
        error: error.toString(),
      );
    }
  }
}

final spOrganizerCustomersControllerProvider =
    NotifierProvider<SpOrganizerCustomersController, SpOrganizerCustomersState>(
      SpOrganizerCustomersController.new,
    );

const _notSet = Object();

class SpOrganizerProductsState {
  final List<SpOrganizerProduct> products;
  final int total;
  final int page;
  final int totalPages;
  final int limit;
  final String query;
  final bool includeArchived;
  final String sortBy;
  final String sortDirection;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;

  const SpOrganizerProductsState({
    this.products = const [],
    this.total = 0,
    this.page = 1,
    this.totalPages = 0,
    this.limit = 40,
    this.query = '',
    this.includeArchived = false,
    this.sortBy = 'title',
    this.sortDirection = 'asc',
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
  });

  bool get hasMore => page < totalPages;

  SpOrganizerProductsState copyWith({
    List<SpOrganizerProduct>? products,
    int? total,
    int? page,
    int? totalPages,
    int? limit,
    String? query,
    bool? includeArchived,
    String? sortBy,
    String? sortDirection,
    bool? isLoading,
    bool? isLoadingMore,
    Object? error = _notSet,
  }) {
    return SpOrganizerProductsState(
      products: products ?? this.products,
      total: total ?? this.total,
      page: page ?? this.page,
      totalPages: totalPages ?? this.totalPages,
      limit: limit ?? this.limit,
      query: query ?? this.query,
      includeArchived: includeArchived ?? this.includeArchived,
      sortBy: sortBy ?? this.sortBy,
      sortDirection: sortDirection ?? this.sortDirection,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: identical(error, _notSet) ? this.error : error as String?,
    );
  }
}

class SpOrganizerProductsController extends Notifier<SpOrganizerProductsState> {
  Future<void>? _loadFuture;
  int _loadRevision = 0;

  @override
  SpOrganizerProductsState build() {
    ref.watch(demoModeProvider);
    return const SpOrganizerProductsState();
  }

  Future<void> load({
    bool silent = false,
    String? query,
    bool? includeArchived,
    String? sortBy,
    String? sortDirection,
  }) {
    final nextQuery = query ?? state.query;
    final nextIncludeArchived = includeArchived ?? state.includeArchived;
    final nextSortBy = sortBy ?? state.sortBy;
    final nextSortDirection = sortDirection ?? state.sortDirection;
    if (_loadFuture != null &&
        nextQuery == state.query &&
        nextIncludeArchived == state.includeArchived &&
        nextSortBy == state.sortBy &&
        nextSortDirection == state.sortDirection) {
      return _loadFuture!;
    }

    final revision = ++_loadRevision;
    late final Future<void> future;
    future =
        _loadFirstPage(
          revision: revision,
          silent: silent,
          query: nextQuery,
          includeArchived: nextIncludeArchived,
          sortBy: nextSortBy,
          sortDirection: nextSortDirection,
        ).whenComplete(() {
          if (identical(_loadFuture, future)) _loadFuture = null;
        });
    _loadFuture = future;
    return future;
  }

  Future<void> search(String query) => load(query: query);

  Future<void> setIncludeArchived(bool value) {
    return load(includeArchived: value);
  }

  Future<void> setSort(String sortBy, String sortDirection) {
    return load(sortBy: sortBy, sortDirection: sortDirection);
  }

  Future<void> loadMore() async {
    if (state.isLoading ||
        state.isLoadingMore ||
        !state.hasMore ||
        ref.read(demoModeProvider)) {
      return;
    }
    state = state.copyWith(isLoadingMore: true, error: null);
    final revision = _loadRevision;
    try {
      final page = await ref
          .read(spOrganizerRepositoryProvider)
          .getProducts(
            query: state.query,
            page: state.page + 1,
            limit: state.limit,
            includeArchived: state.includeArchived,
            sortBy: state.sortBy,
            sortDirection: state.sortDirection,
          );
      if (revision != _loadRevision) return;
      state = state.copyWith(
        products: [...state.products, ...page.items],
        total: page.total,
        page: page.page,
        totalPages: page.totalPages,
        limit: page.limit,
        isLoadingMore: false,
        error: null,
      );
    } catch (error) {
      if (revision != _loadRevision) return;
      state = state.copyWith(isLoadingMore: false, error: error.toString());
    }
  }

  Future<SpOrganizerProduct> createProduct(
    SpOrganizerProductInput input,
  ) async {
    final product = await ref
        .read(spOrganizerRepositoryProvider)
        .createProduct(input);
    await load(silent: true);
    return product;
  }

  Future<SpOrganizerProduct> updateProduct(
    int productId,
    SpOrganizerProductInput input,
  ) async {
    final product = await ref
        .read(spOrganizerRepositoryProvider)
        .updateProduct(productId, input);
    await load(silent: true);
    return product;
  }

  Future<void> archiveProduct(int productId) async {
    await ref.read(spOrganizerRepositoryProvider).archiveProduct(productId);
    await load(silent: true);
  }

  Future<void> restoreProduct(int productId) async {
    await ref.read(spOrganizerRepositoryProvider).restoreProduct(productId);
    await load(silent: true);
  }

  Future<void> _loadFirstPage({
    required int revision,
    required bool silent,
    required String query,
    required bool includeArchived,
    required String sortBy,
    required String sortDirection,
  }) async {
    if (ref.read(demoModeProvider)) {
      state = SpOrganizerProductsState(
        query: query,
        includeArchived: includeArchived,
        sortBy: sortBy,
        sortDirection: sortDirection,
      );
      return;
    }
    if (!silent) {
      state = state.copyWith(
        isLoading: true,
        query: query,
        includeArchived: includeArchived,
        sortBy: sortBy,
        sortDirection: sortDirection,
        error: null,
      );
    }

    try {
      final page = await ref
          .read(spOrganizerRepositoryProvider)
          .getProducts(
            query: query,
            page: 1,
            limit: state.limit,
            includeArchived: includeArchived,
            sortBy: sortBy,
            sortDirection: sortDirection,
          );
      if (revision != _loadRevision) return;
      state = state.copyWith(
        products: page.items,
        total: page.total,
        page: page.page,
        totalPages: page.totalPages,
        limit: page.limit,
        query: query,
        includeArchived: includeArchived,
        sortBy: sortBy,
        sortDirection: sortDirection,
        isLoading: false,
        isLoadingMore: false,
        error: null,
      );
    } catch (error) {
      if (revision != _loadRevision) return;
      state = state.copyWith(
        query: query,
        includeArchived: includeArchived,
        sortBy: sortBy,
        sortDirection: sortDirection,
        isLoading: false,
        isLoadingMore: false,
        error: error.toString(),
      );
    }
  }
}

final spOrganizerProductsControllerProvider =
    NotifierProvider<SpOrganizerProductsController, SpOrganizerProductsState>(
      SpOrganizerProductsController.new,
    );

final spOrganizerParticipantsProvider = FutureProvider.autoDispose
    .family<SpOrganizerParticipantList, int>((ref, purchaseId) async {
      if (ref.watch(demoModeProvider)) {
        return const SpOrganizerParticipantList();
      }
      return ref
          .watch(spOrganizerRepositoryProvider)
          .getParticipants(purchaseId);
    });

final spOrganizerCalculationPreviewProvider = FutureProvider.autoDispose
    .family<SpOrganizerCalculationPreview, int>((ref, purchaseId) async {
      return ref
          .watch(spOrganizerRepositoryProvider)
          .getCalculationPreview(purchaseId);
    });

final spOrganizerFulfillmentOverviewProvider = FutureProvider.autoDispose
    .family<SpOrganizerFulfillmentOverview, int>((ref, purchaseId) async {
      return ref
          .watch(spOrganizerRepositoryProvider)
          .getFulfillmentOverview(purchaseId);
    });
