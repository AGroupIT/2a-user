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

    final groups = List.generate(2, (gi) {
      final id = 'asm-${(clientCode.hashCode ^ gi ^ rng.nextInt(1 << 20)).toRadixString(16)}';
      final packing = <String>[
        'Коробка',
        if (rng.nextBool()) 'Пузырчатая пленка',
        if (rng.nextInt(4) == 0) 'Деревянная обрешетка',
      ];
      final category = ['Сборный груз', 'Одежда', 'Хоз.товары/Текстиль'][rng.nextInt(3)];
      final insurance = rng.nextInt(3) == 0;
      final insuranceAmount = insurance ? (5000 + rng.nextInt(50000)).toDouble() : null;
      final createdAt = now.subtract(Duration(days: 10 + gi * 6 + rng.nextInt(5)));
      final status = ['На сборке', 'Отправлен', 'Прибыл на терминал'][rng.nextInt(3)];

      final groupScalePhotos = List.generate(1 + rng.nextInt(3), (pi) => pic('scale_${id}_$pi'));

      return (
        id: id,
        group: TrackGroup(
          id: id,
          status: status,
          packing: packing,
          category: category,
          insurance: insurance,
          insuranceAmount: insuranceAmount,
          createdAt: createdAt,
        ),
        groupScalePhotos: groupScalePhotos,
      );
    });

    final items = <TrackItem>[];

    for (final g in groups) {
      for (var i = 0; i < 3; i++) {
        final code = 'TRK-${clientCode.replaceAll(' ', '')}-${200000 + rng.nextInt(900000)}';
        final date = now.subtract(Duration(days: rng.nextInt(40), hours: rng.nextInt(24)));
        items.add(
          TrackItem(
            code: code,
            status: g.group.status ?? 'На сборке',
            date: date,
            groupId: g.id,
            group: g.group,
            groupScalePhotos: g.groupScalePhotos,
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
          comment: rng.nextInt(5) == 0 ? 'Ваш комментарий' : null,
          photoRequestAt: hasPhotoRequest ? date.add(const Duration(hours: 2)) : null,
          photoRequestComment: hasPhotoRequest ? 'Нужен фотоотчет по упаковке' : null,
          photoTaskStatus: hasPhotoRequest ? PhotoTaskStatus.newTask : null,
          photoTaskUpdatedAt: hasPhotoRequest ? date.add(const Duration(hours: 6)) : null,
          photoReportUrls: hasPhotoRequest ? [pic('pr_$code', w: 800, h: 800)] : const [],
        ),
      );
    }

    items.sort((a, b) => b.date.compareTo(a.date));
    _cache[clientCode] = items;
    return items;
  }
}
