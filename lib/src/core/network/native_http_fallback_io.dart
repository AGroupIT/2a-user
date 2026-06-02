import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cronet_http/cronet_http.dart';
import 'package:cupertino_http/cupertino_http.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import '../logging/client_log_service.dart';
import '../services/runtime/app_runtime_info.dart';
import 'api_config.dart';

class NativeHttpFallback {
  NativeHttpFallback({required this.tokenProvider});

  final Future<String?> Function() tokenProvider;

  http.Client? _client;
  String? _clientKind;

  bool get isAvailable {
    return defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.android;
  }

  Future<Response<T>?> get<T>({
    required String baseUrl,
    required String path,
    Map<String, dynamic>? queryParameters,
    Options? options,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    if (!isAvailable) return null;

    final uri = _buildUri(baseUrl, path, queryParameters);
    final requestOptions = RequestOptions(
      baseUrl: baseUrl,
      path: path,
      method: 'GET',
      queryParameters: queryParameters ?? const {},
      headers: await _headers(options),
      responseType: options?.responseType ?? ResponseType.json,
      receiveTimeout: options?.receiveTimeout ?? timeout,
      sendTimeout: options?.sendTimeout ?? timeout,
      validateStatus: options?.validateStatus,
      extra: {
        ...?options?.extra,
        'native_http_fallback': true,
        'native_http_client': _clientKind ?? _platformClientKind,
      },
    );

    final client = _ensureClient();
    final startedAt = DateTime.now();
    ClientLogService.instance.add(
      type: 'native_http_fallback_request',
      level: 'warning',
      message: 'Пробуем native HTTP fallback для GET',
      data: {'client': _clientKind, 'path': path, 'baseUrl': baseUrl},
    );

    try {
      final response = await client
          .get(uri, headers: _stringHeaders(requestOptions.headers))
          .timeout(timeout);
      final dioResponse = _toDioResponse<T>(response, requestOptions);
      final validateStatus = options?.validateStatus ?? _defaultValidateStatus;
      final statusCode = dioResponse.statusCode;
      final isValid = validateStatus(statusCode);

      ClientLogService.instance.add(
        type: 'native_http_fallback_response',
        level: isValid ? 'info' : 'warning',
        message: 'Native HTTP fallback получил ответ',
        data: {
          'client': _clientKind,
          'path': path,
          'baseUrl': baseUrl,
          'statusCode': statusCode,
          'durationMs': DateTime.now().difference(startedAt).inMilliseconds,
        },
      );

      if (!isValid && statusCode != null) {
        throw DioException.badResponse(
          statusCode: statusCode,
          requestOptions: requestOptions,
          response: dioResponse,
        );
      }
      return dioResponse;
    } on TimeoutException catch (error) {
      throw DioException.connectionTimeout(
        timeout: timeout,
        requestOptions: requestOptions,
        error: error,
      );
    } on DioException {
      rethrow;
    } catch (error) {
      ClientLogService.instance.add(
        type: 'native_http_fallback_error',
        level: 'warning',
        message: 'Native HTTP fallback не сработал',
        data: {
          'client': _clientKind,
          'path': path,
          'baseUrl': baseUrl,
          'error': error.toString(),
        },
      );
      throw DioException.connectionError(
        requestOptions: requestOptions,
        reason: error.toString(),
        error: error,
      );
    }
  }

  http.Client _ensureClient() {
    final existing = _client;
    if (existing != null) return existing;

    try {
      if (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS) {
        _clientKind = 'cupertino_urlsession';
        return _client = CupertinoClient.defaultSessionConfiguration();
      }

      if (defaultTargetPlatform == TargetPlatform.android) {
        _clientKind = 'android_cronet';
        final engine = CronetEngine.build(
          cacheMode: CacheMode.memory,
          cacheMaxSize: 2 * 1024 * 1024,
          enableHttp2: true,
          enableQuic: true,
        );
        return _client = CronetClient.fromCronetEngine(
          engine,
          closeEngine: true,
        );
      }
    } catch (error) {
      ClientLogService.instance.add(
        type: 'native_http_fallback_client_error',
        level: 'warning',
        message:
            'Не удалось создать platform native HTTP client, используем IOClient',
        data: {
          'targetPlatform': defaultTargetPlatform.name,
          'error': error.toString(),
        },
      );
    }

    _clientKind = 'dart_io';
    return _client = IOClient(HttpClient());
  }

  String get _platformClientKind {
    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      return 'cupertino_urlsession';
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'android_cronet';
    }
    return 'dart_io';
  }

  Future<Map<String, Object?>> _headers(Options? options) async {
    final headers = <String, Object?>{
      ...ApiConfig.defaultHeaders,
      ...await AppRuntimeInfo.instance.headers(),
      ...?options?.headers,
    };

    if (!_hasHeader(headers, 'Authorization')) {
      final token = await tokenProvider();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  Map<String, String> _stringHeaders(Map<String, Object?> headers) {
    final result = <String, String>{};
    headers.forEach((key, value) {
      if (value == null) return;
      result[key] = value.toString();
    });
    return result;
  }

  bool _hasHeader(Map<String, Object?> headers, String name) {
    final lowerName = name.toLowerCase();
    return headers.keys.any((key) => key.toLowerCase() == lowerName);
  }

  Uri _buildUri(
    String baseUrl,
    String path,
    Map<String, dynamic>? queryParameters,
  ) {
    final normalizedBase = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
    final normalizedPath = path.startsWith('/') ? path.substring(1) : path;
    final uri = Uri.parse(normalizedBase).resolve(normalizedPath);
    if (queryParameters == null || queryParameters.isEmpty) return uri;
    return uri.replace(
      queryParameters: queryParameters.map(
        (key, value) => MapEntry(key, value?.toString() ?? ''),
      ),
    );
  }

  Response<T> _toDioResponse<T>(
    http.Response response,
    RequestOptions requestOptions,
  ) {
    final data = _decodeBody(response, requestOptions.responseType);
    return Response<T>(
      data: data as T?,
      headers: Headers.fromMap(
        response.headers.map((key, value) => MapEntry(key, [value])),
      ),
      requestOptions: requestOptions,
      statusCode: response.statusCode,
      statusMessage: response.reasonPhrase,
      isRedirect: response.isRedirect,
    );
  }

  Object? _decodeBody(http.Response response, ResponseType responseType) {
    if (responseType == ResponseType.bytes) return response.bodyBytes;
    final text = utf8.decode(response.bodyBytes, allowMalformed: true);
    if (responseType == ResponseType.plain) return text;

    final contentType = response.headers['content-type']?.toLowerCase() ?? '';
    if (text.isEmpty) return null;
    if (responseType == ResponseType.json || contentType.contains('json')) {
      return jsonDecode(text);
    }
    return text;
  }

  bool _defaultValidateStatus(int? status) {
    return status != null && status >= 200 && status < 300;
  }

  void close() {
    _client?.close();
    _client = null;
    _clientKind = null;
  }
}
