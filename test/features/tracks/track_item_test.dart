import 'package:flutter_test/flutter_test.dart';
import 'package:twoalogisticcabineuser/src/features/tracks/domain/track_item.dart';

void main() {
  group('TrackItem.isPending', () {
    TrackItem track({required String status, required String statusCode}) {
      final now = DateTime(2026, 7, 29);
      return TrackItem(
        code: 'YT123',
        status: status,
        statusCode: statusCode,
        date: now,
        createdAt: now,
        updatedAt: now,
      );
    }

    test('uses backend pending status code instead of translated label', () {
      expect(track(status: 'Ожидает', statusCode: 'pending').isPending, isTrue);
      expect(
        track(status: 'В ожидании', statusCode: 'in_warehouse').isPending,
        isFalse,
      );
    });

    test('rejects other codes and supports old responses without code', () {
      expect(track(status: 'Создан', statusCode: 'created').isPending, isFalse);
      expect(track(status: 'В ожидании', statusCode: '').isPending, isTrue);
    });
  });

  group('TrackItem assembly selection', () {
    TrackItem parse({bool? canAdd, String? reason}) => TrackItem.fromJson({
      'id': 12,
      'trackNumber': 'YT-ASSEMBLY',
      'status': 'in_warehouse',
      'statusName': 'На складе',
      'createdAt': '2026-08-25T01:00:00.000Z',
      'updatedAt': '2026-08-25T01:00:00.000Z',
      if (canAdd != null) 'canAddToAssembly': canAdd,
      if (reason != null) 'assemblyBlockReason': reason,
    });

    test('uses backend cooldown decision and explains it', () {
      final value = parse(canAdd: false, reason: 'warehouse_arrival_cooldown');

      expect(value.isAvailableForAssemblySelection, isFalse);
      expect(value.assemblySelectionHint, contains('можно завтра'));
    });

    test('blocks an active return request', () {
      final value = parse(canAdd: false, reason: 'return_requested');

      expect(value.isAvailableForAssemblySelection, isFalse);
      expect(value.assemblySelectionHint, 'По треку запрошен возврат');
    });

    test('keeps backward compatibility with an older backend', () {
      expect(parse().isAvailableForAssemblySelection, isTrue);
    });
  });

  test('TrackReturnInfo parses persisted return and status label', () {
    final value = TrackReturnInfo.fromJson({
      'id': 18,
      'returnCode': 'SF-9988',
      'status': 'in_progress',
      'screenshotUrl': '/uploads/return.jpg',
      'note': 'Проверяется складом',
      'createdAt': '2026-08-20T01:00:00.000Z',
      'updatedAt': '2026-08-20T02:00:00.000Z',
    });

    expect(value.id, 18);
    expect(value.returnCode, 'SF-9988');
    expect(value.statusLabel, 'В работе');
    expect(value.screenshotUrl, '/uploads/return.jpg');
    expect(value.updatedAt, DateTime.utc(2026, 8, 20, 2));
    expect(value.clientConfirmedAt, isNull);
    expect(value.canConfirmCompletion, isFalse);
  });

  test(
    'completed return can be confirmed until client confirmation is stored',
    () {
      final completed = TrackReturnInfo.fromJson({
        'id': 19,
        'returnCode': 'SF-RETURNED',
        'status': 'completed',
        'createdAt': '2026-08-21T01:00:00.000Z',
      });
      final confirmed = TrackReturnInfo.fromJson({
        'id': 19,
        'returnCode': 'SF-RETURNED',
        'status': 'completed',
        'createdAt': '2026-08-21T01:00:00.000Z',
        'clientConfirmedAt': '2026-08-22T03:00:00.000Z',
      });

      expect(completed.canConfirmCompletion, isTrue);
      expect(confirmed.canConfirmCompletion, isFalse);
      expect(confirmed.clientConfirmedAt, DateTime.utc(2026, 8, 22, 3));
    },
  );

  test('assembly receipt confirmation follows canonical delivery statuses', () {
    TrackAssembly assembly(String status) =>
        TrackAssembly(id: 7, number: 'ASM-7', status: status);

    expect(assembly('in_assembly').canConfirmReceipt, isFalse);
    expect(assembly('shipped').canConfirmReceipt, isTrue);
    expect(assembly('arrived_terminal').canConfirmReceipt, isTrue);
    expect(assembly('ready_for_pickup').canConfirmReceipt, isTrue);
    expect(assembly('delivered').canConfirmReceipt, isFalse);

    expect(assembly('ready_for_pickup').canEditDelivery, isTrue);
    expect(assembly('delivered').canEditDelivery, isFalse);
  });
}
