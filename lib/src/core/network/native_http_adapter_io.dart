import 'dart:async';
import 'package:cronet_http/cronet_http.dart';
import 'package:cupertino_http/cupertino_http.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../logging/client_log_service.dart';

HttpClientAdapter? createNativeHttpAdapter() {
  if (!_NativeHttpAdapter.isSupportedPlatform) return null;
  return _NativeHttpAdapter();
}

class _NativeHttpAdapter implements HttpClientAdapter {
  http.Client? _client;
  String? _clientKind;
  bool _closed = false;
  bool _loggedClient = false;
  bool _closeAfterActiveRequests = false;
  int _activeRequests = 0;

  static bool get isSupportedPlatform {
    return defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.android;
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (_closed) {
      throw StateError("Can't establish connection after adapter was closed.");
    }

    final client = _ensureClient();
    _activeRequests++;
    var completionDeferredToNativeFuture = false;

    try {
      final request = http.StreamedRequest(options.method, options.uri)
        ..followRedirects = options.followRedirects
        ..maxRedirects = options.maxRedirects
        ..persistentConnection = options.persistentConnection;

      _copyHeaders(options, request);
      options.extra['native_http_client'] = _clientKind;

      final bodyBytes = await _collectRequestBody(options, requestStream);
      request.contentLength = bodyBytes.length;
      if (bodyBytes.isNotEmpty) {
        request.sink.add(bodyBytes);
      }
      unawaited(request.sink.close());

      final sendFuture = _withRequestStartTimeout(
        client.send(request),
        options,
        hasBody: bodyBytes.isNotEmpty,
      );
      final response = await _withCancel(
        sendFuture,
        cancelFuture,
        options,
        onCancel: () {
          completionDeferredToNativeFuture = true;
          // CupertinoClient/CronetClient не умеют безопасно закрываться, пока
          // нативный запрос ещё выполняется. Поэтому при отмене Dio ждём
          // завершения underlying future и только потом считаем запрос
          // законченным для deferred close.
          unawaited(sendFuture.whenComplete(_markRequestComplete));
        },
      );

      return ResponseBody(
        _trackResponseStream(
          _withReceiveTimeout(response.stream, options).map(_asUint8List),
        ),
        response.statusCode,
        headers: response.headers.map((key, value) => MapEntry(key, [value])),
        isRedirect: response.isRedirect,
        statusMessage: response.reasonPhrase,
      );
    } on DioException {
      if (!completionDeferredToNativeFuture) {
        _markRequestComplete();
      }
      rethrow;
    } catch (error) {
      if (!completionDeferredToNativeFuture) {
        _markRequestComplete();
      }
      throw DioException.connectionError(
        requestOptions: options,
        reason: error.toString(),
        error: error,
      );
    }
  }

  http.Client _ensureClient() {
    final existing = _client;
    if (existing != null) return existing;

    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      _clientKind = 'cupertino_urlsession';
      final client = CupertinoClient.defaultSessionConfiguration();
      _logClientCreated();
      return _client = client;
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      _clientKind = 'android_cronet';
      final engine = CronetEngine.build(
        cacheMode: CacheMode.memory,
        cacheMaxSize: 2 * 1024 * 1024,
        enableHttp2: true,
        enableQuic: true,
      );
      final client = CronetClient.fromCronetEngine(engine, closeEngine: true);
      _logClientCreated();
      return _client = client;
    }

    // createNativeHttpAdapter() must prevent unsupported platforms from using
    // this adapter. Keep this as a defensive guard instead of falling back to
    // dart:io on mobile.
    throw UnsupportedError('Unsupported native HTTP platform');
  }

  void _logClientCreated() {
    if (_loggedClient) return;
    _loggedClient = true;
    ClientLogService.instance.add(
      type: 'native_http_adapter_created',
      level: 'info',
      message: 'API запросы используют platform-native HTTP stack',
      data: {
        'client': _clientKind,
        'targetPlatform': defaultTargetPlatform.name,
      },
    );
  }

  Future<Uint8List> _collectRequestBody(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
  ) async {
    if (requestStream == null) return Uint8List(0);

    final chunks = <int>[];
    Stream<Uint8List> stream = requestStream;
    final sendTimeout = options.sendTimeout;
    if (sendTimeout != null && sendTimeout > Duration.zero) {
      stream = stream.timeout(
        sendTimeout,
        onTimeout: (sink) {
          sink.addError(
            DioException.sendTimeout(
              timeout: sendTimeout,
              requestOptions: options,
            ),
          );
          sink.close();
        },
      );
    }

    await for (final chunk in stream) {
      chunks.addAll(chunk);
    }
    return Uint8List.fromList(chunks);
  }

  Future<http.StreamedResponse> _withRequestStartTimeout(
    Future<http.StreamedResponse> future,
    RequestOptions options, {
    required bool hasBody,
  }) {
    final timeout = hasBody
        ? (options.sendTimeout ?? options.connectTimeout)
        : options.connectTimeout;
    if (timeout == null || timeout <= Duration.zero) {
      return future;
    }
    return future.timeout(
      timeout,
      onTimeout: () {
        if (hasBody) {
          throw DioException.sendTimeout(
            timeout: timeout,
            requestOptions: options,
          );
        }
        throw DioException.connectionTimeout(
          requestOptions: options,
          timeout: timeout,
        );
      },
    );
  }

  Stream<List<int>> _withReceiveTimeout(
    http.ByteStream stream,
    RequestOptions options,
  ) {
    final receiveTimeout = options.receiveTimeout;
    if (receiveTimeout == null || receiveTimeout <= Duration.zero) {
      return stream;
    }
    return stream.timeout(
      receiveTimeout,
      onTimeout: (sink) {
        sink.addError(
          DioException.receiveTimeout(
            timeout: receiveTimeout,
            requestOptions: options,
          ),
        );
        sink.close();
      },
    );
  }

  Future<T> _withCancel<T>(
    Future<T> future,
    Future<void>? cancelFuture,
    RequestOptions options, {
    void Function()? onCancel,
  }) {
    if (cancelFuture == null) return future;
    var settled = false;
    final guardedFuture = future.then<T>(
      (value) {
        settled = true;
        return value;
      },
      onError: (Object error, StackTrace stackTrace) {
        settled = true;
        Error.throwWithStackTrace(error, stackTrace);
      },
    );

    return Future.any<T>([
      guardedFuture,
      cancelFuture.then<T>((_) {
        if (settled) {
          return guardedFuture;
        }
        settled = true;
        onCancel?.call();
        throw DioException.requestCancelled(
          requestOptions: options,
          reason: 'request cancelled',
        );
      }),
    ]);
  }

  void _copyHeaders(RequestOptions options, http.BaseRequest request) {
    options.headers.forEach((key, value) {
      if (value == null) return;
      request.headers[key] = value.toString();
    });

    final contentType = options.contentType;
    if (contentType != null &&
        !request.headers.keys.any(
          (key) => key.toLowerCase() == Headers.contentTypeHeader,
        )) {
      request.headers[Headers.contentTypeHeader] = contentType;
    }
  }

  Uint8List _asUint8List(List<int> chunk) {
    return chunk is Uint8List ? chunk : Uint8List.fromList(chunk);
  }

  Stream<Uint8List> _trackResponseStream(Stream<Uint8List> stream) async* {
    try {
      yield* stream;
    } finally {
      _markRequestComplete();
    }
  }

  void _markRequestComplete() {
    if (_activeRequests > 0) {
      _activeRequests--;
    }
    if (_activeRequests == 0 && _closeAfterActiveRequests) {
      _disposeClient();
    }
  }

  void _disposeClient() {
    _closeAfterActiveRequests = false;
    final client = _client;
    final clientKind = _clientKind;
    _client = null;
    _clientKind = null;
    if (client == null) return;
    try {
      client.close();
    } catch (error) {
      // close() у cupertino_http/cronet_http бросает исключение, если нативный
      // стек считает, что запрос ещё жив. Это не должно падать в приложение:
      // новый Dio уже создан, старый клиент просто будет освобождён ОС позже.
      ClientLogService.instance.add(
        type: 'native_http_adapter_close_failed',
        level: 'warning',
        message: 'Нативный HTTP-клиент не удалось закрыть синхронно',
        data: {'client': clientKind, 'error': error.toString()},
      );
      debugPrint('[NativeHttpAdapter] close ignored: $error');
    }
  }

  @override
  void close({bool force = false}) {
    _closed = true;
    if (_activeRequests > 0) {
      _closeAfterActiveRequests = true;
      ClientLogService.instance.add(
        type: 'native_http_adapter_close_deferred',
        level: 'info',
        message:
            'Закрытие нативного HTTP-клиента отложено до завершения запросов',
        data: {
          'client': _clientKind,
          'activeRequests': _activeRequests,
          'force': force,
        },
      );
      return;
    }
    _disposeClient();
  }
}
