import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:twoalogisticcabineuser/src/core/media/media_image_byte_cache.dart';

void main() {
  test(
    'different decoded variants share one in-flight download and cached bytes',
    () async {
      final cache = MediaImageByteCache();
      final result = Completer<Uint8List>();
      var requests = 0;
      Future<Uint8List> fetch() {
        requests++;
        return result.future;
      }

      final first = cache.load('account-a', '/image', fetch);
      final second = cache.load('account-a', '/image', fetch);
      result.complete(Uint8List.fromList([1, 2, 3]));
      expect(await first, await second);
      expect(await cache.load('account-a', '/image', fetch), [1, 2, 3]);
      expect(requests, 1);
    },
  );
  test(
    'LRU obeys total byte budget and oversized photos are not retained',
    () async {
      final cache = MediaImageByteCache(maximumBytes: 6, maximumEntryBytes: 4);
      var requests = 0;
      Future<Uint8List> load(String path, [int length = 3]) =>
          cache.load('a', path, () async {
            requests++;
            return Uint8List(length);
          });
      await load('a');
      await load('b');
      await load('a');
      await load('c');
      expect(requests, 3);
      await load('b');
      expect(requests, 4);
      await load('huge', 5);
      await load('huge', 5);
      expect(requests, 6);
    },
  );
  test(
    'session change invalidates cached and in-flight private bytes',
    () async {
      final cache = MediaImageByteCache();
      final old = Completer<Uint8List>();
      final pending = cache.load('first-account', '/image', () => old.future);
      final rejected = expectLater(pending, throwsStateError);
      await cache.load(
        'second-account',
        '/image',
        () async => Uint8List.fromList([2]),
      );
      old.complete(Uint8List.fromList([1]));
      await rejected;
      expect(
        await cache.load(
          'second-account',
          '/image',
          () async => throw StateError('must be cached'),
        ),
        [2],
      );
    },
  );
  test('failed requests can retry without poisoning other variants', () async {
    final cache = MediaImageByteCache();
    await expectLater(
      cache.load('a', 'image', () async => throw StateError('network')),
      throwsStateError,
    );
    expect(
      await cache.load('a', 'image', () async => Uint8List.fromList([3])),
      [3],
    );
  });
  test(
    'decoder eviction removes only failed bytes, not a newer repaired entry',
    () async {
      final cache = MediaImageByteCache();
      final broken = await cache.load(
        'a',
        'image',
        () async => Uint8List.fromList([0]),
      );
      cache.evict('a', 'image', broken);
      final repaired = await cache.load(
        'a',
        'image',
        () async => Uint8List.fromList([1]),
      );
      cache.evict('a', 'image', broken);
      expect(
        await cache.load(
          'a',
          'image',
          () async => throw StateError('must stay cached'),
        ),
        repaired,
      );
      await cache.load('b', 'image', () async => Uint8List.fromList([2]));
      cache.evict('a', 'image', repaired);
      expect(
        await cache.load(
          'b',
          'image',
          () async => throw StateError('wrong account eviction'),
        ),
        [2],
      );
    },
  );
}
