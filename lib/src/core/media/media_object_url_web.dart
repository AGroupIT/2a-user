import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

@JS('Blob')
external JSFunction get _blobConstructor;
@JS('URL.createObjectURL')
external JSString _createObjectUrl(JSObject blob);
@JS('URL.revokeObjectURL')
external void _revokeObjectUrl(JSString url);

String createMediaObjectUrl(Uint8List bytes, String mimeType) {
  final blob = _blobConstructor.callAsConstructor<JSObject>(
    [bytes.toJS].toJS,
    {'type': mimeType}.jsify(),
  );
  return _createObjectUrl(blob).toDart;
}

void revokeMediaObjectUrl(String url) => _revokeObjectUrl(url.toJS);
