import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../clients/application/client_codes_controller.dart';
import '../../tracks/data/tracks_provider.dart';
import '../data/garage_remote_client.dart';
import '../data/garage_repository.dart';
import '../domain/garage_models.dart';

final garageRemoteClientProvider = Provider<GarageRemoteClient>((ref) {
  return ApiClientGarageRemoteClient(ref.watch(apiClientProvider));
});

final garageRepositoryProvider = Provider<GarageRepository>((ref) {
  return RemoteGarageRepository(ref.watch(garageRemoteClientProvider));
});

final garageAvailabilityProvider =
    FutureProvider.autoDispose<GarageAvailability>((ref) async {
      ref.watch(activeClientCodeProvider);
      return ref.watch(garageRepositoryProvider).getAvailability();
    });

final garageRequestStatusesProvider =
    FutureProvider.autoDispose<List<GarageRequestStatusDefinition>>((
      ref,
    ) async {
      final statuses = await ref.watch(
        statusesByTypeProvider('garage_request').future,
      );
      final definitions =
          statuses
              .where(
                (status) =>
                    canonicalGarageRequestStatuses.contains(status.code) &&
                    status.isActive,
              )
              .map(
                (status) => GarageRequestStatusDefinition(
                  code: status.code,
                  nameRu: status.nameRu,
                  color: status.color,
                  sortOrder: status.sortOrder,
                ),
              )
              .toList(growable: false)
            ..sort((left, right) => left.sortOrder.compareTo(right.sortOrder));
      return definitions;
    });

final garageRequestsProvider = FutureProvider.autoDispose<List<GarageRequest>>((
  ref,
) async {
  ref.watch(activeClientCodeProvider);
  return ref.watch(garageRepositoryProvider).getRequests();
});

final garageRequestProvider = FutureProvider.autoDispose
    .family<GarageRequest, int>((ref, requestId) async {
      ref.watch(activeClientCodeProvider);
      return ref.watch(garageRepositoryProvider).getRequest(requestId);
    });

final garageOrdersProvider = FutureProvider.autoDispose<List<GarageOrder>>((
  ref,
) async {
  ref.watch(activeClientCodeProvider);
  return ref.watch(garageRepositoryProvider).getOrders();
});

final garageOrderProvider = FutureProvider.autoDispose.family<GarageOrder, int>(
  (ref, orderId) async {
    ref.watch(activeClientCodeProvider);
    return ref.watch(garageRepositoryProvider).getOrder(orderId);
  },
);

final garageInvoiceProvider = FutureProvider.autoDispose
    .family<GarageInvoice, int>((ref, orderId) async {
      ref.watch(activeClientCodeProvider);
      return ref.watch(garageRepositoryProvider).getOrderInvoice(orderId);
    });

@immutable
class GarageVehiclesState {
  final List<GarageVehicle> vehicles;
  final bool isMutating;
  final Object? mutationError;
  final StackTrace? mutationStackTrace;

  GarageVehiclesState({
    required List<GarageVehicle> vehicles,
    this.isMutating = false,
    this.mutationError,
    this.mutationStackTrace,
  }) : vehicles = List.unmodifiable(vehicles);

  GarageVehiclesState copyWith({
    List<GarageVehicle>? vehicles,
    bool? isMutating,
    Object? mutationError,
    StackTrace? mutationStackTrace,
    bool clearMutationError = false,
  }) {
    return GarageVehiclesState(
      vehicles: vehicles ?? this.vehicles,
      isMutating: isMutating ?? this.isMutating,
      mutationError: clearMutationError
          ? null
          : (mutationError ?? this.mutationError),
      mutationStackTrace: clearMutationError
          ? null
          : (mutationStackTrace ?? this.mutationStackTrace),
    );
  }
}

final garageVehiclesControllerProvider =
    AsyncNotifierProvider.autoDispose<
      GarageVehiclesController,
      GarageVehiclesState
    >(GarageVehiclesController.new);

class GarageVehiclesController extends AsyncNotifier<GarageVehiclesState> {
  GarageRepository get _repository => ref.read(garageRepositoryProvider);

  @override
  Future<GarageVehiclesState> build() async {
    ref.watch(activeClientCodeProvider);
    final vehicles = await _repository.getVehicles();
    return GarageVehiclesState(vehicles: vehicles);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final vehicles = await _repository.getVehicles();
      return GarageVehiclesState(vehicles: vehicles);
    });
  }

  Future<GarageVehicle> createVehicle(GarageVehicleInput input) async {
    final current = _requireState();
    _beginMutation(current);
    try {
      final created = await _repository.createVehicle(input);
      state = AsyncData(
        current.copyWith(
          vehicles: [created, ...current.vehicles],
          isMutating: false,
          clearMutationError: true,
        ),
      );
      return created;
    } catch (error, stackTrace) {
      _failMutation(current, error, stackTrace);
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<GarageVehicle> updateVehicle(
    int vehicleId,
    GarageVehicleInput input,
  ) async {
    final current = _requireState();
    _beginMutation(current);
    try {
      final updated = await _repository.updateVehicle(vehicleId, input);
      final vehicles = [
        for (final vehicle in current.vehicles)
          if (vehicle.id == vehicleId) updated else vehicle,
      ];
      state = AsyncData(
        current.copyWith(
          vehicles: vehicles,
          isMutating: false,
          clearMutationError: true,
        ),
      );
      return updated;
    } catch (error, stackTrace) {
      _failMutation(current, error, stackTrace);
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<void> deleteVehicle(int vehicleId) async {
    final current = _requireState();
    _beginMutation(current);
    try {
      await _repository.deleteVehicle(vehicleId);
      state = AsyncData(
        current.copyWith(
          vehicles: current.vehicles
              .where((vehicle) => vehicle.id != vehicleId)
              .toList(growable: false),
          isMutating: false,
          clearMutationError: true,
        ),
      );
    } catch (error, stackTrace) {
      _failMutation(current, error, stackTrace);
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  GarageVehiclesState _requireState() {
    final current = state.asData?.value;
    if (current == null) {
      throw StateError('Garage vehicles are not loaded');
    }
    return current;
  }

  void _beginMutation(GarageVehiclesState current) {
    state = AsyncData(
      current.copyWith(isMutating: true, clearMutationError: true),
    );
  }

  void _failMutation(
    GarageVehiclesState current,
    Object error,
    StackTrace stackTrace,
  ) {
    state = AsyncData(
      current.copyWith(
        isMutating: false,
        mutationError: error,
        mutationStackTrace: stackTrace,
      ),
    );
  }
}

@immutable
class GarageRequestDraftState {
  final GarageRequest? request;
  final bool isLoading;
  final bool isSaving;
  final Object? error;
  final StackTrace? stackTrace;

  const GarageRequestDraftState({
    this.request,
    this.isLoading = false,
    this.isSaving = false,
    this.error,
    this.stackTrace,
  });

  GarageRequestDraftState copyWith({
    GarageRequest? request,
    bool? isLoading,
    bool? isSaving,
    Object? error,
    StackTrace? stackTrace,
    bool clearRequest = false,
    bool clearError = false,
  }) {
    return GarageRequestDraftState(
      request: clearRequest ? null : (request ?? this.request),
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      error: clearError ? null : (error ?? this.error),
      stackTrace: clearError ? null : (stackTrace ?? this.stackTrace),
    );
  }
}

final garageRequestDraftControllerProvider =
    NotifierProvider<GarageRequestDraftController, GarageRequestDraftState>(
      GarageRequestDraftController.new,
    );

class GarageRequestDraftController extends Notifier<GarageRequestDraftState> {
  GarageRepository get _repository => ref.read(garageRepositoryProvider);

  @override
  GarageRequestDraftState build() {
    ref.watch(activeClientCodeProvider);
    return const GarageRequestDraftState();
  }

  void reset() {
    state = const GarageRequestDraftState();
  }

  Future<GarageRequest> load(int requestId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final request = await _repository.getRequest(requestId);
      state = GarageRequestDraftState(request: request);
      return request;
    } catch (error, stackTrace) {
      state = state.copyWith(
        isLoading: false,
        error: error,
        stackTrace: stackTrace,
      );
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<GarageRequest> create(
    GarageRequestInput input, {
    String? idempotencyKey,
  }) async {
    _beginSave();
    try {
      final request = await _repository.createRequest(
        input,
        idempotencyKey: idempotencyKey,
      );
      state = GarageRequestDraftState(request: request);
      ref.invalidate(garageRequestsProvider);
      return request;
    } catch (error, stackTrace) {
      _failSave(error, stackTrace);
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<GarageRequest> update(GarageRequestUpdate update) async {
    final current = _requireDraft();
    _ensureDraft(current);
    _beginSave();
    try {
      final request = await _repository.updateRequest(current.id, update);
      state = GarageRequestDraftState(request: request);
      ref.invalidate(garageRequestsProvider);
      return request;
    } catch (error, stackTrace) {
      _failSave(error, stackTrace);
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<GarageRequestItem> addItem(GarageRequestItemInput input) async {
    final current = _requireDraft();
    _ensureDraft(current);
    _beginSave();
    try {
      final item = await _repository.addRequestItem(current.id, input);
      final items = [...current.items, item]
        ..sort((left, right) => left.orderNumber.compareTo(right.orderNumber));
      state = GarageRequestDraftState(request: current.copyWith(items: items));
      return item;
    } catch (error, stackTrace) {
      _failSave(error, stackTrace);
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<GarageRequestItem> updateItem(
    int itemId,
    GarageRequestItemInput input,
  ) async {
    final current = _requireDraft();
    _ensureDraft(current);
    _beginSave();
    try {
      final item = await _repository.updateRequestItem(itemId, input);
      final items = [
        for (final existing in current.items)
          if (existing.id == itemId) item else existing,
      ];
      state = GarageRequestDraftState(request: current.copyWith(items: items));
      return item;
    } catch (error, stackTrace) {
      _failSave(error, stackTrace);
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<void> deleteItem(int itemId) async {
    final current = _requireDraft();
    _ensureDraft(current);
    _beginSave();
    try {
      await _repository.deleteRequestItem(itemId);
      state = GarageRequestDraftState(
        request: current.copyWith(
          items: current.items
              .where((item) => item.id != itemId)
              .toList(growable: false),
        ),
      );
    } catch (error, stackTrace) {
      _failSave(error, stackTrace);
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<GarageRequest> submit({required String idempotencyKey}) async {
    final current = _requireDraft();
    _ensureDraft(current);
    _beginSave();
    try {
      final request = await _repository.submitRequest(
        current.id,
        idempotencyKey: idempotencyKey,
      );
      state = GarageRequestDraftState(request: request);
      ref.invalidate(garageRequestsProvider);
      return request;
    } catch (error, stackTrace) {
      _failSave(error, stackTrace);
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  GarageRequest _requireDraft() {
    final request = state.request;
    if (request == null) {
      throw StateError('Garage request draft is not loaded');
    }
    return request;
  }

  void _ensureDraft(GarageRequest request) {
    if (request.status != 'draft') {
      throw StateError('Garage request is no longer editable');
    }
  }

  void _beginSave() {
    state = state.copyWith(isSaving: true, clearError: true);
  }

  void _failSave(Object error, StackTrace stackTrace) {
    state = state.copyWith(
      isLoading: false,
      isSaving: false,
      error: error,
      stackTrace: stackTrace,
    );
  }
}
