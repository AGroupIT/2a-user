import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:twoalogisticcabineuser/src/core/network/api_client.dart';
import 'package:twoalogisticcabineuser/src/features/tracks/data/assemblies_provider.dart';
import 'package:twoalogisticcabineuser/src/features/tracks/data/tracks_provider.dart';
import 'package:twoalogisticcabineuser/src/features/training/data/assembly_training_session.dart';
import 'package:twoalogisticcabineuser/src/features/training/presentation/training_target.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(
    () => SharedPreferences.setMockInitialValues({
      'auth_token': 'real-token-must-not-be-used',
      'active_client_code': 'REAL',
    }),
  );

  test(
    'real services submit fixture assembly and refreshed tracks contain it',
    () async {
      final session = AssemblyTrainingSession(
        registry: TrainingTargetRegistry(),
      );
      addTearDown(session.dispose);
      final c = session.container;
      final keepAlive = c.listen(
        paginatedTracksProvider(assemblyTrainingClientCode),
        (_, _) {},
      );
      addTearDown(keepAlive.close);
      final notifier = keepAlive.read();
      while (notifier.state.isLoading) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      expect(notifier.state.error, isNull);
      expect(notifier.state.tracks.map((t) => t.id), assemblyTrainingTrackIds);
      expect(
        notifier.state.tracks
            .where((t) => t.isAvailableForAssemblySelection)
            .length,
        2,
      );
      expect(await c.read(apiClientProvider).getToken(), isNull);
      expect(
        (await c.read(tariffsProvider.future)).single.id,
        assemblyTrainingTariffId,
      );
      expect(
        (await c.read(packagingTypesProvider.future)).first.id,
        assemblyTrainingPackagingId,
      );
      final statuses = await c.read(trackStatusesProvider.future);
      expect(statuses.map((s) => s.code), [
        'pending',
        'in_warehouse',
        'in_assembly',
        'shipped',
        'arrived_terminal',
        'ready_for_pickup',
        'delivered',
        'return_requested',
        'returned',
      ]);
      var notifications = 0;
      session.addListener(() => notifications++);
      final result = await c
          .read(assembliesApiServiceProvider)
          .createAssembly(
            clientId: assemblyTrainingClientId,
            clientCodeId: assemblyTrainingClientCodeId,
            tariffId: assemblyTrainingTariffId,
            packagingTypeIds: [assemblyTrainingPackagingId],
            placePreference: 'single_if_possible',
            goodsDescription: 'Футболки, 2 шт.; носки, 3 пары',
            trackIds: assemblyTrainingTrackIds.take(2).toList(),
          );
      expect(result.isSuccess, isTrue);
      expect(result.assembly!.number, assemblyTrainingAssemblyNumber);
      expect(session.assemblyCreated, isTrue);
      expect(notifications, 1);
      expect(
        session.submittedPayload!['trackIds'],
        assemblyTrainingTrackIds.take(2).toList(),
      );
      await notifier.loadInitial();
      expect(
        notifier.state.tracks
            .where((t) => t.assembly?.id == assemblyTrainingAssemblyId)
            .length,
        2,
      );
      expect(
        (await c.read(
          assembliesListProvider(assemblyTrainingClientCode).future,
        )).single.id,
        assemblyTrainingAssemblyId,
      );
      expect(session.rejectedRequests, isEmpty);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys(), {'auth_token', 'active_client_code'});
      expect(prefs.getString('active_client_code'), 'REAL');
    },
  );

  test(
    'foreign identifiers and non-exercise operations cannot succeed',
    () async {
      final session = AssemblyTrainingSession(
        registry: TrainingTargetRegistry(),
      );
      addTearDown(session.dispose);
      final api = session.container.read(apiClientProvider);
      await expectLater(
        api.post('/client/assemblies/123/confirm-receipt'),
        throwsA(isA<DioException>()),
      );
      await expectLater(
        api.get('/tracks', queryParameters: {'clientCode': 'REAL'}),
        throwsA(isA<DioException>()),
      );
      final result = await session.container
          .read(assembliesApiServiceProvider)
          .createAssembly(
            clientId: assemblyTrainingClientId,
            clientCodeId: assemblyTrainingClientCodeId,
            tariffId: assemblyTrainingTariffId,
            packagingTypeIds: [assemblyTrainingPackagingId],
            placePreference: 'single_if_possible',
            goodsDescription: 'TRAINING',
            trackIds: [assemblyTrainingTrackIds.last],
          );
      expect(result.isSuccess, isFalse);
      expect(session.assemblyCreated, isFalse);
      expect(session.rejectedRequests.length, 3);
    },
  );

  test('fresh sessions do not inherit submitted fixture state', () async {
    final first = AssemblyTrainingSession(registry: TrainingTargetRegistry());
    first.dispose();
    final next = AssemblyTrainingSession(registry: TrainingTargetRegistry());
    addTearDown(next.dispose);
    expect(next.assemblyCreated, isFalse);
    expect(next.submittedPayload, isNull);
  });
}
