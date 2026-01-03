import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/photo_item.dart';

Future<void> _latency([Duration? _]) => Future<void>.microtask(() {});

abstract class PhotosRepository {
  Future<int> fetchTotalCount({required String clientCode});

  Future<List<PhotoItem>> fetchRecentPhotos({
    required String clientCode,
    required int limit,
  });

  Future<List<String>> fetchDaysWithPhotos({
    required String clientCode,
    required int month,
    required int year,
  });

  Future<List<PhotoItem>> fetchPhotosByDate({
    required String clientCode,
    required String date,
  });

  Future<List<PhotoItem>> searchPhotos({
    required String clientCode,
    required String query,
  });
}

final photosRepositoryProvider = Provider<PhotosRepository>((ref) {
  return FakePhotosRepository();
});

final photosDaysProvider = FutureProvider.family<List<String>, ({String clientCode, int month, int year})>((ref, q) async {
  final repo = ref.watch(photosRepositoryProvider);
  return repo.fetchDaysWithPhotos(clientCode: q.clientCode, month: q.month, year: q.year);
});

final photosTotalCountProvider = FutureProvider.family<int, String>((ref, clientCode) async {
  final repo = ref.watch(photosRepositoryProvider);
  return repo.fetchTotalCount(clientCode: clientCode);
});

final photosRecentProvider = FutureProvider.family<List<PhotoItem>, ({String clientCode, int limit})>((ref, q) async {
  final repo = ref.watch(photosRepositoryProvider);
  return repo.fetchRecentPhotos(clientCode: q.clientCode, limit: q.limit);
});

final photosByDateProvider = FutureProvider.family<List<PhotoItem>, ({String clientCode, String date})>((ref, q) async {
  final repo = ref.watch(photosRepositoryProvider);
  return repo.fetchPhotosByDate(clientCode: q.clientCode, date: q.date);
});

final photosSearchProvider = FutureProvider.family<List<PhotoItem>, ({String clientCode, String query})>((ref, q) async {
  final repo = ref.watch(photosRepositoryProvider);
  return repo.searchPhotos(clientCode: q.clientCode, query: q.query);
});

class FakePhotosRepository implements PhotosRepository {
  final Map<String, List<PhotoItem>> _cache = {};

  @override
  Future<int> fetchTotalCount({required String clientCode}) async {
    await _latency(const Duration(milliseconds: 200));
    return _getAll(clientCode).length;
  }

  @override
  Future<List<PhotoItem>> fetchRecentPhotos({
    required String clientCode,
    required int limit,
  }) async {
    await _latency();
    final items = _getAll(clientCode);
    return items.take(limit).toList(growable: false);
  }

  @override
  Future<List<String>> fetchDaysWithPhotos({
    required String clientCode,
    required int month,
    required int year,
  }) async {
    await _latency();
    final items = _getAll(clientCode);

    final dates = <String>{};
    for (final p in items) {
      if (p.date.year != year) continue;
      if (p.date.month != month + 1) continue;
      dates.add(_toYmd(p.date));
    }

    final list = dates.toList(growable: false);
    list.sort((a, b) => b.compareTo(a));
    return list;
  }

  @override
  Future<List<PhotoItem>> fetchPhotosByDate({
    required String clientCode,
    required String date,
  }) async {
    await _latency();
    final items = _getAll(clientCode);
    return items.where((p) => _toYmd(p.date) == date).toList(growable: false);
  }

  @override
  Future<List<PhotoItem>> searchPhotos({
    required String clientCode,
    required String query,
  }) async {
    await _latency();
    final items = _getAll(clientCode);
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];

    return items.where((p) {
      final inUrl = p.url.toLowerCase().contains(q);
      final inTrack = (p.trackingNumber ?? '').toLowerCase().contains(q);
      final inAsm = (p.assemblyNumber ?? '').toLowerCase().contains(q);
      return inUrl || inTrack || inAsm;
    }).toList(growable: false);
  }

  List<PhotoItem> _getAll(String clientCode) {
    final cached = _cache[clientCode];
    if (cached != null) return cached;

    final rng = Random(clientCode.hashCode ^ 0xC0FFEE);
    final now = DateTime.now();

    final items = List.generate(80, (i) {
      final date = now.subtract(
        Duration(
          days: rng.nextInt(45),
          hours: rng.nextInt(24),
          minutes: rng.nextInt(60),
        ),
      );

      final trackingNumber = rng.nextBool() ? 'TRK-${100000 + rng.nextInt(900000)}' : null;
      final assemblyNumber = rng.nextInt(5) == 0 ? 'ASM-${rng.nextInt(1 << 20).toRadixString(16)}' : null;

      final isVideo = rng.nextInt(12) == 0;
      final imageId = (i + 1) * 10 + rng.nextInt(10); // Используем стабильные ID от 10 до 800
      final url = isVideo
          ? 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4'
          : 'https://picsum.photos/id/$imageId/800/800';

      return PhotoItem(
        url: url,
        date: date,
        trackingNumber: trackingNumber,
        assemblyNumber: assemblyNumber,
      );
    })
      ..sort((a, b) => b.date.compareTo(a.date));

    _cache[clientCode] = items;
    return items;
  }

  String _toYmd(DateTime d) {
    String pad(int n) => n < 10 ? '0$n' : '$n';
    return '${d.year}-${pad(d.month)}-${pad(d.day)}';
  }
}
