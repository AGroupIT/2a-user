import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/services/demo_mode_provider.dart';
import 'sp_v2_models.dart';
import 'sp_v2_repository.dart';

final spV2RepositoryProvider = Provider<SpV2Repository>((ref) {
  return SpV2Repository(ref.watch(apiClientProvider));
});

class SpV2PurchasesState {
  final List<SpV2Purchase> purchases;
  final bool isLoading;
  final String? error;
  final String query;

  const SpV2PurchasesState({
    this.purchases = const [],
    this.isLoading = false,
    this.error,
    this.query = '',
  });

  SpV2PurchasesState copyWith({
    List<SpV2Purchase>? purchases,
    bool? isLoading,
    String? error,
    String? query,
  }) {
    return SpV2PurchasesState(
      purchases: purchases ?? this.purchases,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      query: query ?? this.query,
    );
  }
}

class SpV2PurchasesController extends Notifier<SpV2PurchasesState> {
  Future<void>? _loadFuture;

  @override
  SpV2PurchasesState build() {
    if (ref.watch(demoModeProvider)) {
      return const SpV2PurchasesState();
    }
    return const SpV2PurchasesState();
  }

  Future<void> load({bool silent = false, String? query}) {
    final nextQuery = query ?? state.query;
    if (_loadFuture != null && query == null) return _loadFuture!;

    late final Future<void> future;
    future = _loadInternal(silent: silent, query: nextQuery).whenComplete(() {
      if (identical(_loadFuture, future)) _loadFuture = null;
    });
    _loadFuture = future;
    return future;
  }

  Future<void> search(String query) {
    state = state.copyWith(query: query);
    return load(query: query);
  }

  Future<SpV2Purchase> createPurchase(CreateSpV2PurchaseInput input) async {
    final repository = ref.read(spV2RepositoryProvider);
    final purchase = await repository.createPurchase(input);
    state = state.copyWith(
      purchases: [purchase, ...state.purchases],
      error: null,
    );
    return purchase;
  }

  Future<void> _loadInternal({
    required bool silent,
    required String query,
  }) async {
    if (ref.read(demoModeProvider)) {
      state = state.copyWith(
        purchases: const [],
        isLoading: false,
        error: null,
        query: query,
      );
      return;
    }

    if (!silent) {
      state = state.copyWith(isLoading: true, error: null, query: query);
    }

    try {
      final repository = ref.read(spV2RepositoryProvider);
      final purchases = await repository.getPurchases(query: query);
      state = state.copyWith(
        purchases: purchases,
        isLoading: false,
        error: null,
        query: query,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        error: error.toString(),
        query: query,
      );
    }
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
