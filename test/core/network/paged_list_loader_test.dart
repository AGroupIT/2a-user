import 'package:flutter_test/flutter_test.dart';
import 'package:twoalogisticcabineuser/src/core/network/paged_list_loader.dart';

void main() {
  test(
    'traverses paginated data in order without losing entries after 80',
    () async {
      final offsets = <int>[];
      final rows = await loadPagedList(
        fetchPage: (query) async {
          final skip = query['skip'] as int;
          offsets.add(skip);
          final count = skip == 0 ? 50 : 33;
          return {
            'data': List.generate(count, (index) => {'id': skip + index}),
            'pagination': {'hasMore': skip == 0, 'nextSkip': skip + count},
          };
        },
      );
      expect(offsets, [0, 50]);
      expect(rows.map((row) => row['id']), List.generate(83, (i) => i));
    },
  );

  test(
    'legacy raw list and requests envelope are accepted without truncation',
    () async {
      final legacy = List.generate(120, (i) => {'id': i});
      var calls = 0;
      expect(
        await loadPagedList(
          fetchPage: (_) async {
            calls++;
            return legacy;
          },
        ),
        legacy,
      );
      expect(calls, 1);
      expect(
        await loadPagedList(
          listKey: 'requests',
          fetchPage: (_) async => {'requests': legacy},
        ),
        legacy,
      );
    },
  );

  test(
    'nonprogressing pagination and failed later pages do not return partial success',
    () async {
      await expectLater(
        loadPagedList(
          fetchPage: (_) async => {
            'data': [
              {'id': 1},
            ],
            'pagination': {'hasMore': true, 'nextSkip': 0},
          },
        ),
        throwsFormatException,
      );
      await expectLater(
        loadPagedList(
          fetchPage: (query) async {
            if (query['skip'] == 1) throw StateError('offline');
            return {
              'data': [
                {'id': 1},
              ],
              'pagination': {'hasMore': true, 'nextSkip': 1},
            };
          },
        ),
        throwsStateError,
      );
    },
  );
}
