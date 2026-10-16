import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

class _LocalVideoController extends VideoPlayerController {
  _LocalVideoController(String url, this.cleanup)
    : super.file(File.fromUri(Uri.parse(url)));
  final Future<void> Function() cleanup;
  @override
  Future<void> dispose() async {
    try {
      await super.dispose();
    } finally {
      await cleanup();
    }
  }
}

Future<({String url, Future<void> Function() dispose})>
createPrivateMediaSource(Uint8List bytes, String mimeType) async {
  final root = await getTemporaryDirectory();
  final directory = await Directory(root.path).createTemp('private-media-');
  final subtype = mimeType.split('/').last.split(';').first;
  final extension = subtype == 'mpeg'
      ? 'mp3'
      : RegExp(r'^[a-zA-Z0-9]+$').hasMatch(subtype)
      ? subtype
      : 'bin';
  final file = File('${directory.path}/media.$extension');
  Future<void>? cleanupInFlight;
  Future<void> cleanup() => cleanupInFlight ??= () async {
    if (await file.exists()) await file.delete();
    if (await directory.exists()) await directory.delete();
  }();

  try {
    await file.writeAsBytes(bytes, flush: true);
    return (url: file.uri.toString(), dispose: cleanup);
  } catch (_) {
    await cleanup();
    rethrow;
  }
}

Future<VideoPlayerController> createPrivateVideoSource(
  Uint8List bytes,
  String mimeType,
) async {
  final source = await createPrivateMediaSource(bytes, mimeType);
  return _LocalVideoController(source.url, source.dispose);
}
