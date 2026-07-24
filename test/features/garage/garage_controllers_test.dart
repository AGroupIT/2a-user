import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:twoalogisticcabineuser/src/features/clients/application/client_codes_controller.dart';
import 'package:twoalogisticcabineuser/src/features/garage/application/garage_providers.dart';
import 'package:twoalogisticcabineuser/src/features/garage/data/garage_repository.dart';
import 'package:twoalogisticcabineuser/src/features/garage/domain/garage_models.dart';
import 'package:twoalogisticcabineuser/src/features/tracks/data/tracks_provider.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(
      const GarageVehicleInput(
        vin: 'VIN',
        make: 'Make',
        model: 'Model',
        modelYear: 2020,
      ),
    );
    registerFallbackValue(
      const GarageRequestInput(vehicleId: 1, clientCodeId: 1),
    );
    registerFallbackValue(const GarageRequestUpdate(clientComment: null));
    registerFallbackValue(
      const GarageRequestItemInput(
        partName: 'Part',
        partNumber: 'P-1',
        preference: GaragePartPreference.original,
        existUrl: 'https://exist.ru/item',
      ),
    );
  });

  test(
    'Garage request status catalog uses canonical active database rows',
    () async {
      final container = ProviderContainer(
        overrides: [
          statusesByTypeProvider('garage_request').overrideWith(
            (ref) async => const [
              TrackStatus(
                id: 2,
                type: 'garage_request',
                code: 'paid',
                nameRu: 'Оплачена',
                color: '#16A34A',
                sortOrder: 7,
                isActive: true,
              ),
              TrackStatus(
                id: 1,
                type: 'garage_request',
                code: 'new',
                nameRu: 'Новая',
                color: '#2E7DFF',
                sortOrder: 2,
                isActive: true,
              ),
              TrackStatus(
                id: 3,
                type: 'garage_request',
                code: 'submitted',
                nameRu: 'Старый статус',
                sortOrder: 1,
                isActive: true,
              ),
              TrackStatus(
                id: 4,
                type: 'garage_request',
                code: 'in_progress',
                nameRu: 'Неактивный',
                sortOrder: 3,
                isActive: false,
              ),
            ],
          ),
        ],
      );
      addTearDown(container.dispose);

      final statuses = await container.read(
        garageRequestStatusesProvider.future,
      );

      expect(statuses.map((status) => status.code), ['new', 'paid']);
      expect(statuses.first.nameRu, 'Новая');
    },
  );

  test('vehicles controller loads and updates immutable list', () async {
    final repository = _MockGarageRepository();
    final initial = _vehicle(id: 1, nickname: 'Первый');
    final created = _vehicle(id: 2, nickname: 'Второй');
    when(repository.getVehicles).thenAnswer((_) async => [initial]);
    when(
      () => repository.createVehicle(any()),
    ).thenAnswer((_) async => created);

    final container = _container(repository);
    addTearDown(container.dispose);
    final subscription = container.listen(
      garageVehiclesControllerProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    final loaded = await container.read(
      garageVehiclesControllerProvider.future,
    );
    expect(loaded.vehicles.single.id, 1);

    await container
        .read(garageVehiclesControllerProvider.notifier)
        .createVehicle(
          const GarageVehicleInput(
            vin: 'VIN-2',
            make: 'Make',
            model: 'Model',
            modelYear: 2021,
          ),
        );

    final state = container.read(garageVehiclesControllerProvider).requireValue;
    expect(state.vehicles.map((vehicle) => vehicle.id), [2, 1]);
    expect(state.isMutating, isFalse);
  });

  test('vehicles controller exposes mutation error and rethrows it', () async {
    final repository = _MockGarageRepository();
    final error = StateError('vehicle has active requests');
    when(repository.getVehicles).thenAnswer((_) async => [_vehicle(id: 1)]);
    when(() => repository.deleteVehicle(1)).thenThrow(error);

    final container = _container(repository);
    addTearDown(container.dispose);
    final subscription = container.listen(
      garageVehiclesControllerProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);
    await container.read(garageVehiclesControllerProvider.future);

    await expectLater(
      container
          .read(garageVehiclesControllerProvider.notifier)
          .deleteVehicle(1),
      throwsA(same(error)),
    );

    final state = container.read(garageVehiclesControllerProvider).requireValue;
    expect(state.vehicles.single.id, 1);
    expect(state.mutationError, same(error));
  });

  test('draft controller loads, adds item, and submits idempotently', () async {
    final repository = _MockGarageRepository();
    final draft = _request(id: 11, status: 'draft');
    final item = _item(id: 101, requestId: 11);
    final submitted = _request(id: 11, status: 'submitted', items: [item]);
    when(() => repository.getRequest(11)).thenAnswer((_) async => draft);
    when(
      () => repository.addRequestItem(11, any()),
    ).thenAnswer((_) async => item);
    when(
      () => repository.submitRequest(
        11,
        idempotencyKey: any(named: 'idempotencyKey'),
      ),
    ).thenAnswer((_) async => submitted);

    final container = _container(repository);
    addTearDown(container.dispose);
    final controller = container.read(
      garageRequestDraftControllerProvider.notifier,
    );

    await controller.load(11);
    await controller.addItem(
      const GarageRequestItemInput(
        partName: 'Колодки',
        partNumber: '04465-33480',
        preference: GaragePartPreference.original,
        existUrl: 'https://exist.ru/item',
      ),
    );
    await controller.submit(idempotencyKey: 'submit-11');

    final state = container.read(garageRequestDraftControllerProvider);
    expect(state.request?.status, 'submitted');
    expect(state.request?.items.single.id, 101);
    verify(
      () => repository.submitRequest(11, idempotencyKey: 'submit-11'),
    ).called(1);
  });

  test('draft controller blocks item mutation after submit', () async {
    final repository = _MockGarageRepository();
    when(
      () => repository.getRequest(11),
    ).thenAnswer((_) async => _request(id: 11, status: 'submitted'));

    final container = _container(repository);
    addTearDown(container.dispose);
    final controller = container.read(
      garageRequestDraftControllerProvider.notifier,
    );
    await controller.load(11);

    await expectLater(
      controller.addItem(
        const GarageRequestItemInput(
          partName: 'Колодки',
          partNumber: '04465-33480',
          preference: GaragePartPreference.original,
          existUrl: 'https://exist.ru/item',
        ),
      ),
      throwsStateError,
    );
    verifyNever(() => repository.addRequestItem(any(), any()));
  });

  test('draft controller updates request and existing positions', () async {
    final repository = _MockGarageRepository();
    final existingItem = _item(id: 101, requestId: 11);
    final draft = _request(id: 11, status: 'draft', items: [existingItem]);
    final updatedRequest = draft.copyWith(clientComment: 'Новый комментарий');
    final updatedItem = GarageRequestItem(
      id: 101,
      requestId: 11,
      orderNumber: 1,
      partName: 'Колодки передние',
      partNumber: '04465-33480',
      partNumberNormalized: '0446533480',
      preference: GaragePartPreference.original,
      existUrl: 'https://exist.ru/item',
      quantity: 2,
      side: 'Передняя',
      position: 'Передняя ось',
      clientComment: null,
      isOptional: false,
      createdAt: null,
      updatedAt: null,
    );
    when(() => repository.getRequest(11)).thenAnswer((_) async => draft);
    when(
      () => repository.updateRequest(11, any()),
    ).thenAnswer((_) async => updatedRequest);
    when(
      () => repository.updateRequestItem(101, any()),
    ).thenAnswer((_) async => updatedItem);
    when(() => repository.deleteRequestItem(101)).thenAnswer((_) async {});

    final container = _container(repository);
    addTearDown(container.dispose);
    final controller = container.read(
      garageRequestDraftControllerProvider.notifier,
    );

    await controller.load(11);
    await controller.update(
      const GarageRequestUpdate(
        vehicleId: 1,
        clientCodeId: 1,
        clientComment: 'Новый комментарий',
      ),
    );
    await controller.updateItem(
      101,
      const GarageRequestItemInput(
        partName: 'Колодки передние',
        partNumber: '04465-33480',
        preference: GaragePartPreference.original,
        existUrl: 'https://exist.ru/item',
        quantity: 2,
        side: 'Передняя',
        position: 'Передняя ось',
      ),
    );

    var state = container.read(garageRequestDraftControllerProvider);
    expect(state.request?.clientComment, 'Новый комментарий');
    expect(state.request?.items.single.quantity, 2);
    expect(state.request?.items.single.position, 'Передняя ось');

    await controller.deleteItem(101);
    state = container.read(garageRequestDraftControllerProvider);
    expect(state.request?.items, isEmpty);
    verify(() => repository.updateRequest(11, any())).called(1);
    verify(() => repository.updateRequestItem(101, any())).called(1);
    verify(() => repository.deleteRequestItem(101)).called(1);
  });
}

class _MockGarageRepository extends Mock implements GarageRepository {}

ProviderContainer _container(GarageRepository repository) {
  return ProviderContainer(
    overrides: [
      activeClientCodeProvider.overrideWithValue('A-001'),
      garageRepositoryProvider.overrideWithValue(repository),
    ],
  );
}

GarageVehicle _vehicle({required int id, String? nickname}) {
  return GarageVehicle.fromJson({
    'id': id,
    'vinNormalized': 'VIN-$id',
    'nickname': nickname,
    'make': 'Make',
    'model': 'Model',
    'modelYear': 2020,
  });
}

GarageRequest _request({
  required int id,
  required String status,
  List<GarageRequestItem> items = const [],
}) {
  return GarageRequest(
    id: id,
    requestNumber: 'GAR-A-$id',
    vehicleId: 1,
    clientId: 1,
    agentId: 1,
    processorAgentId: 1,
    clientCodeId: 1,
    assignedEmployeeId: null,
    status: status,
    needsEmployeeResponse: false,
    needsClientResponse: false,
    lastMessageAt: null,
    lastClientMessageAt: null,
    lastEmployeeMessageAt: null,
    vehicleSnapshot: null,
    clientComment: null,
    currentOfferId: null,
    submittedAt: null,
    cancelledAt: null,
    cancelReason: null,
    createdAt: null,
    updatedAt: null,
    items: items,
  );
}

GarageRequestItem _item({required int id, required int requestId}) {
  return GarageRequestItem(
    id: id,
    requestId: requestId,
    orderNumber: 1,
    partName: 'Колодки',
    partNumber: '04465-33480',
    partNumberNormalized: '0446533480',
    preference: GaragePartPreference.original,
    existUrl: 'https://exist.ru/item',
    quantity: 1,
    side: null,
    position: null,
    clientComment: null,
    isOptional: false,
    createdAt: null,
    updatedAt: null,
  );
}
