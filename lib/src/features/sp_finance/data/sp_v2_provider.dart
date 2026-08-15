import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/services/demo_mode_provider.dart';
import 'sp_v2_models.dart';
import 'sp_v2_repository.dart';

final spV2RepositoryProvider = Provider<SpV2Repository>((ref) {
  return SpV2Repository(ref.watch(apiClientProvider));
});

const _spPurchasesStateUnset = Object();

class SpV2PurchasesState {
  final List<SpV2Purchase> purchases;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final SpV2PurchaseDirectoryQuery directoryQuery;
  final SpV2PurchaseDirectoryPagination pagination;
  final SpV2PurchaseDirectorySummary summary;
  final List<SpV2PurchaseDirectoryStatus> statusOptions;
  final bool usedLegacyResponse;

  const SpV2PurchasesState({
    this.purchases = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.directoryQuery = const SpV2PurchaseDirectoryQuery(),
    this.pagination = const SpV2PurchaseDirectoryPagination(),
    this.summary = const SpV2PurchaseDirectorySummary(),
    this.statusOptions = const [],
    this.usedLegacyResponse = false,
  });

  String get query => directoryQuery.query;
  bool get hasNextPage => pagination.hasNextPage && !usedLegacyResponse;

  SpV2PurchasesState copyWith({
    List<SpV2Purchase>? purchases,
    bool? isLoading,
    bool? isLoadingMore,
    Object? error = _spPurchasesStateUnset,
    SpV2PurchaseDirectoryQuery? directoryQuery,
    SpV2PurchaseDirectoryPagination? pagination,
    SpV2PurchaseDirectorySummary? summary,
    List<SpV2PurchaseDirectoryStatus>? statusOptions,
    bool? usedLegacyResponse,
  }) {
    return SpV2PurchasesState(
      purchases: purchases ?? this.purchases,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: identical(error, _spPurchasesStateUnset)
          ? this.error
          : error as String?,
      directoryQuery: directoryQuery ?? this.directoryQuery,
      pagination: pagination ?? this.pagination,
      summary: summary ?? this.summary,
      statusOptions: statusOptions ?? this.statusOptions,
      usedLegacyResponse: usedLegacyResponse ?? this.usedLegacyResponse,
    );
  }
}

class SpV2PurchasesController extends Notifier<SpV2PurchasesState> {
  int _requestGeneration = 0;

  @override
  SpV2PurchasesState build() {
    if (ref.watch(demoModeProvider)) {
      return const SpV2PurchasesState();
    }
    return const SpV2PurchasesState();
  }

  Future<void> load({bool silent = false, String? query}) {
    final nextQuery = state.directoryQuery.copyWith(
      query: query ?? state.query,
      page: 1,
    );
    return _loadPage(query: nextQuery, silent: silent);
  }

  Future<void> search(String query) {
    return updateDirectoryQuery(
      state.directoryQuery.copyWith(query: query, page: 1),
    );
  }

  Future<void> updateDirectoryQuery(SpV2PurchaseDirectoryQuery query) {
    final normalized = query.copyWith(page: 1);
    state = state.copyWith(directoryQuery: normalized, error: null);
    return _loadPage(query: normalized);
  }

  Future<void> clearDirectoryFilters() {
    return updateDirectoryQuery(
      SpV2PurchaseDirectoryQuery(
        query: state.query,
        limit: state.directoryQuery.limit,
      ),
    );
  }

  Future<void> loadMore() async {
    if (!state.hasNextPage || state.isLoading || state.isLoadingMore) return;
    final nextQuery = state.directoryQuery.copyWith(
      page: state.pagination.page + 1,
    );
    await _loadPage(query: nextQuery, silent: true, append: true);
  }

  Future<SpV2Purchase> createPurchase(CreateSpV2PurchaseInput input) async {
    final repository = ref.read(spV2RepositoryProvider);
    final purchase = await repository.createPurchase(input);
    await load(silent: true);
    return purchase;
  }

  Future<void> _loadPage({
    required SpV2PurchaseDirectoryQuery query,
    bool silent = false,
    bool append = false,
  }) async {
    if (ref.read(demoModeProvider)) {
      state = state.copyWith(
        purchases: const [],
        isLoading: false,
        isLoadingMore: false,
        error: null,
        directoryQuery: query,
        pagination: const SpV2PurchaseDirectoryPagination(),
        summary: const SpV2PurchaseDirectorySummary(),
      );
      return;
    }

    final requestGeneration = ++_requestGeneration;
    state = state.copyWith(
      isLoading: !silent && !append,
      isLoadingMore: append,
      error: null,
      directoryQuery: query,
    );

    try {
      final repository = ref.read(spV2RepositoryProvider);
      final page = await repository.getPurchasesPage(query);
      if (requestGeneration != _requestGeneration) return;

      final purchases = append
          ? _mergePurchases(state.purchases, page.purchases)
          : page.purchases;
      state = state.copyWith(
        purchases: purchases,
        isLoading: false,
        isLoadingMore: false,
        error: null,
        directoryQuery: query,
        pagination: page.pagination,
        summary: page.summary,
        statusOptions: page.statusOptions,
        usedLegacyResponse: page.usedLegacyResponse,
      );
    } catch (error) {
      if (requestGeneration != _requestGeneration) return;
      state = state.copyWith(
        isLoading: false,
        isLoadingMore: false,
        error: error.toString(),
        directoryQuery: query,
      );
    }
  }

  List<SpV2Purchase> _mergePurchases(
    List<SpV2Purchase> current,
    List<SpV2Purchase> next,
  ) {
    final byId = <int, SpV2Purchase>{
      for (final purchase in current) purchase.id: purchase,
      for (final purchase in next) purchase.id: purchase,
    };
    return byId.values.toList(growable: false);
  }
}

final spV2PurchasesControllerProvider =
    NotifierProvider<SpV2PurchasesController, SpV2PurchasesState>(
      SpV2PurchasesController.new,
    );

final spV2PurchaseDetailProvider = FutureProvider.autoDispose
    .family<SpV2Purchase, int>((ref, purchaseId) async {
      final repository = ref.watch(spV2RepositoryProvider);
      return repository.getPurchase(purchaseId);
    });

final spV2CustomersProvider = FutureProvider.autoDispose<List<SpV2Customer>>((
  ref,
) async {
  if (ref.watch(demoModeProvider)) return const [];
  return ref.watch(spV2RepositoryProvider).getCustomers();
});
