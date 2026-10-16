import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:dio/dio.dart';

@JS('AbortController')
extension type _AbortController._(JSObject _) implements JSObject {
  external factory _AbortController();
  external JSObject get signal;
  external void abort();
}

extension type _FetchHeaders._(JSObject _) implements JSObject {
  external void forEach(JSFunction callback);
}

extension type _FetchResponse._(JSObject _) implements JSObject {
  external int get status;
  external String get statusText;
  external _FetchHeaders get headers;
  external JSPromise<JSArrayBuffer> arrayBuffer();
}

@JS('fetch')
external JSPromise<_FetchResponse> _fetch(String url, JSObject options);

HttpClientAdapter wrapMediaHttpAdapter(HttpClientAdapter adapter) =>
    StrictMediaBrowserAdapter(adapter);

/// Dio's XHR adapter follows redirects even when followRedirects is false.
/// Only protected media uses Fetch's mandatory redirect:error policy; other
/// API requests retain their existing adapter and interceptors unchanged.
class StrictMediaBrowserAdapter implements HttpClientAdapter {
  StrictMediaBrowserAdapter(this.delegate);
  final HttpClientAdapter delegate;
  final _active = <_AbortController>{};
  bool _closed = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.extra['private_media_no_redirect'] != true) {
      return delegate.fetch(options, requestStream, cancelFuture);
    }
    if (_closed || options.method != 'GET' || requestStream != null) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.cancel,
        message: 'Media request unavailable',
      );
    }
    final controller = _AbortController();
    _active.add(controller);
    var complete = false;
    Timer? timer;
    final timeout = options.receiveTimeout ?? options.connectTimeout;
    if (timeout != null && timeout > Duration.zero) {
      timer = Timer(timeout, () => controller.abort());
    }
    unawaited(
      cancelFuture?.then((_) {
        if (!complete) controller.abort();
      }),
    );
    try {
      final headers = <String, String>{
        for (final entry in options.headers.entries)
          entry.key: entry.value.toString(),
      };
      final init =
          <String, Object>{
                'method': 'GET',
                'headers': headers,
                'redirect': 'error',
                'credentials': 'omit',
                'mode': 'cors',
                'cache': 'no-store',
                'signal': controller.signal,
              }.jsify()
              as JSObject;
      final response = await _fetch(options.uri.toString(), init).toDart;
      final responseHeaders = <String, List<String>>{};
      response.headers.forEach(
        ((JSString value, JSString name) {
          responseHeaders[name.toDart.toLowerCase()] = [value.toDart];
        }).toJS,
      );
      final buffer = await response.arrayBuffer().toDart;
      return ResponseBody.fromBytes(
        buffer.toDart.asUint8List(),
        response.status,
        headers: responseHeaders,
        statusMessage: response.statusText,
      );
    } catch (_) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
        message: 'Media request blocked or unavailable',
      );
    } finally {
      complete = true;
      timer?.cancel();
      _active.remove(controller);
    }
  }

  @override
  void close({bool force = false}) {
    _closed = true;
    for (final controller in _active) {
      controller.abort();
    }
    delegate.close(force: force);
  }
}
