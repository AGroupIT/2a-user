import 'dart:typed_data';

/// Bounded memory cache for one authenticated image session. Different
/// decoded sizes share a download without persisting private bytes to disk.
class MediaImageByteCache {
  MediaImageByteCache({
    this.maximumBytes = 24 * 1024 * 1024,
    this.maximumEntryBytes = 8 * 1024 * 1024,
  });

  final int maximumBytes;
  final int maximumEntryBytes;
  final _entries = <String, Uint8List>{};
  final _pending = <String, Future<Uint8List>>{};
  String? _identity;
  int _bytes = 0;

  /// A late decoder error must not evict repaired bytes or another session.
  void evict(String identity, String path, Uint8List failedBytes) {
    if (_identity != identity || !identical(_entries[path], failedBytes)) {
      return;
    }
    _bytes -= _entries.remove(path)!.length;
  }

  Future<Uint8List> load(
    String identity,
    String path,
    Future<Uint8List> Function() fetch,
  ) {
    if (_identity != identity) {
      _identity = identity;
      _entries.clear();
      _pending.clear();
      _bytes = 0;
    }
    final hit = _entries.remove(path);
    if (hit != null) {
      _entries[path] = hit;
      return Future.value(hit);
    }
    final pending = _pending[path];
    if (pending != null) return pending;
    late Future<Uint8List> request;
    request = Future.sync(fetch)
        .then((bytes) {
          if (_identity != identity) throw StateError('Media session changed');
          if (bytes.length <= maximumEntryBytes &&
              bytes.length <= maximumBytes) {
            while (_bytes + bytes.length > maximumBytes &&
                _entries.isNotEmpty) {
              _bytes -= _entries.remove(_entries.keys.first)!.length;
            }
            _entries[path] = bytes;
            _bytes += bytes.length;
          }
          return bytes;
        })
        .whenComplete(() {
          if (identical(_pending[path], request)) _pending.remove(path);
        });
    _pending[path] = request;
    return request;
  }
}
