import 'dart:js_interop';
import 'dart:typed_data';

import 'package:video_player/video_player.dart';

@JS('Blob')
extension type _Blob._(JSObject _) implements JSObject {
  external factory _Blob(JSArray<JSAny> parts, JSObject options);
}

@JS('URL.createObjectURL')
external String _createObjectUrl(_Blob blob);

@JS('URL.revokeObjectURL')
external void _revokeObjectUrl(String url);

class _BlobVideoController extends VideoPlayerController {
  _BlobVideoController(String url, this.cleanup)
    : super.networkUrl(Uri.parse(url));
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
  final url = _createObjectUrl(
    _Blob(<JSAny>[bytes.toJS].toJS, {'type': mimeType}.jsify() as JSObject),
  );
  return (url: url, dispose: () async => _revokeObjectUrl(url));
}

Future<VideoPlayerController> createPrivateVideoSource(
  Uint8List bytes,
  String mimeType,
) async {
  final source = await createPrivateMediaSource(bytes, mimeType);
  return _BlobVideoController(source.url, source.dispose);
}
