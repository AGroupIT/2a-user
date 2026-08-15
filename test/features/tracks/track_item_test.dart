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
}
