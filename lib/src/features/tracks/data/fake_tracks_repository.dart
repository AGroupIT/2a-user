import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/track_item.dart';

Future<void> _latency() => Future<void>.microtask(() {});

abstract class TracksRepository {
  Future<List<TrackItem>> fetchTracks({required String clientCode});
}

final tracksRepositoryProvider = Provider<TracksRepository>((ref) {
  return FakeTracksRepository();
});

final tracksListProvider = FutureProvider.family<List<TrackItem>, String>((ref, clientCode) async {
  final repo = ref.watch(tracksRepositoryProvider);
  return repo.fetchTracks(clientCode: clientCode);
});

class FakeTracksRepository implements TracksRepository {
  final Map<String, List<TrackItem>> _cache = {};

  static const _statuses = <String>[
    'В ожидании',
    'На складе',
    'На сборке',
    'Отправлен',
    'Прибыл на терминал',
    'Сформирован к выдаче',
    'Получен',
  ];

  @override
  Future<List<TrackItem>> fetchTracks({required String clientCode}) async {
    await _latency();
    final cached = _cache[clientCode];
    if (cached != null) return cached;

    final rng = Random(clientCode.hashCode ^ 0xABCD1234);
    final now = DateTime.now();

    String pic(String seed, {int w = 900, int h = 700}) => 'https://picsum.photos/seed/$seed/$w/$h';

    final assemblies = List.generate(2, (gi) {
      final id = rng.nextInt(10000);
      final number = 'ASM-${(clientCode.hashCode ^ gi ^ rng.nextInt(1 << 20)).toRadixString(16)}';
      final createdAt = now.subtract(Duration(days: 10 + gi * 6 + rng.nextInt(5)));
      final status = ['assembling', 'sent', 'arrived'][rng.nextInt(3)];
      final statusName = ['На сборке', 'Отправлен', 'Прибыл на терминал'][rng.nextInt(3)];

      final groupScalePhotos = List.generate(1 + rng.nextInt(3), (pi) => pic('scale_${number}_$pi'));

      return (
        id: id,
        assembly: TrackAssembly(
          id: id,
          number: number,
          status: status,
          statusName: statusName,
        ),
        groupScalePhotos: groupScalePhotos,
      );
    });

    final items = <TrackItem>[];

    for (final g in assemblies) {
      for (var i = 0; i < 3; i++) {
        final code = 'TRK-${clientCode.replaceAll(' ', '')}-${200000 + rng.nextInt(900000)}';
        final date = now.subtract(Duration(days: rng.nextInt(40), hours: rng.nextInt(24)));
        items.add(
          TrackItem(
            code: code,
            status: g.assembly.statusName ?? 'На сборке',
            date: date,
            createdAt: date,
            updatedAt: date,
            groupId: g.id.toString(),
            assembly: g.assembly,
            comment: rng.nextInt(6) == 0 ? 'Проверить упаковку' : null,
          ),
        );
      }
    }

    for (var i = 0; i < 14; i++) {
      final code = 'TRK-${clientCode.replaceAll(' ', '')}-${100000 + i}';
      final status = _statuses[rng.nextInt(_statuses.length)];
      final date = now.subtract(Duration(days: rng.nextInt(40), hours: rng.nextInt(24)));
      final hasPhotoRequest = rng.nextInt(10) == 0;
      items.add(
        TrackItem(
          code: code,
          status: status,
          date: date,
          createdAt: date,
          updatedAt: date,
          comment: rng.nextInt(5) == 0 ? 'Ваш комментарий' : null,
          photoRequests: hasPhotoRequest
              ? [
                  PhotoRequest(
                    id: i,
                    status: 'new',
                    wishes: 'Нужен фотоотчет по упаковке',
                    createdAt: date.add(const Duration(hours: 2)),
                    completedAt: date.add(const Duration(hours: 6)),
                    mediaUrls: [pic('pr_$code', w: 800, h: 800)],
                  ),
                ]
              : const [],
        ),
      );
    }

    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _cache[clientCode] = items;
    return items;
  }
}
