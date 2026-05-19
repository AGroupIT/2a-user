import 'dart:async';

import 'package:dio/dio.dart';

import '../logging/client_log_service.dart';
import '../services/runtime/app_runtime_info.dart';
import 'api_client.dart';
import 'api_config.dart';

class NetworkDiagnosticCheck {
  const NetworkDiagnosticCheck({
    required this.name,
    required this.method,
    required this.url,
    required this.durationMs,
    this.statusCode,
    this.errorType,
    this.error,
  });

  final String name;
  final String method;
  final String url;
  final int durationMs;
  final int? statusCode;
  final String? errorType;
  final String? error;

  bool get ok =>
      error == null &&
      statusCode != null &&
      statusCode! >= 200 &&
      statusCode! < 500;

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'method': method,
      'url': url,
      'durationMs': durationMs,
      if (statusCode != null) 'statusCode': statusCode,
      if (errorType != null) 'errorType': errorType,
      if (error != null) 'error': error,
      'ok': ok,
    };
  }
}

class NetworkDiagnosticReport {
  const NetworkDiagnosticReport({
    required this.createdAt,
    required this.activeBaseUrl,
    required this.primaryBaseUrl,
    required this.fallbackBaseUrl,
    required this.usingFallback,
    required this.checks,
  });

  final DateTime createdAt;
  final String activeBaseUrl;
  final String primaryBaseUrl;
  final String? fallbackBaseUrl;
  final bool usingFallback;
  final List<NetworkDiagnosticCheck> checks;

  Map<String, dynamic> toJson() {
    return {
      'createdAt': createdAt.toIso8601String(),
      'activeBaseUrl': activeBaseUrl,
      'primaryBaseUrl': primaryBaseUrl,
      if (fallbackBaseUrl != null) 'fallbackBaseUrl': fallbackBaseUrl,
      'usingFallback': usingFallback,
      'checks': checks.map((check) => check.toJson()).toList(),
    };
  }

  String toSupportText() {
    final buffer = StringBuffer()
      ..writeln('2A network diagnostics')
      ..writeln('createdAt: ${createdAt.toIso8601String()}')
      ..writeln('activeBaseUrl: $activeBaseUrl')
      ..writeln('primaryBaseUrl: $primaryBaseUrl')
      ..writeln('fallbackBaseUrl: ${fallbackBaseUrl ?? '-'}')
      ..writeln('usingFallback: $usingFallback');

    for (final check in checks) {
      buffer
        ..writeln()
        ..writeln('${check.name}: ${check.method} ${check.url}')
        ..writeln('durationMs: ${check.durationMs}')
        ..writeln('statusCode: ${check.statusCode ?? '-'}')
        ..writeln('errorType: ${check.errorType ?? '-'}')
        ..writeln('error: ${check.error ?? '-'}');
    }
    return buffer.toString();
  }
}

class NetworkDiagnosticsService {
  const NetworkDiagnosticsService(this._api);

  static const _timeout = Duration(seconds: 8);

  final ApiClient _api;

  Future<NetworkDiagnosticReport> collect({String? clientCode}) async {
    final token = await _api.getToken();
    final runtimeHeaders = await AppRuntimeInfo.instance.headers();
    final activeBaseUrl = _api.activeBaseUrl;
    final fallbackBaseUrl = ApiConfig.fallbackBaseUrl;

    final checks = <Future<NetworkDiagnosticCheck>>[
      _check(
        name: 'primary_health',
        baseUrl: ApiConfig.baseUrl,
        path: '/health',
        runtimeHeaders: runtimeHeaders,
      ),
      if (activeBaseUrl != ApiConfig.baseUrl)
        _check(
          name: 'active_health',
          baseUrl: activeBaseUrl,
          path: '/health',
          runtimeHeaders: runtimeHeaders,
        ),
      if (fallbackBaseUrl != null && fallbackBaseUrl != activeBaseUrl)
        _check(
          name: 'fallback_health',
          baseUrl: fallbackBaseUrl,
          path: '/health',
          runtimeHeaders: runtimeHeaders,
        ),
      _check(
        name: 'active_profile',
        baseUrl: activeBaseUrl,
        path: '/client/profile',
        token: token,
        runtimeHeaders: runtimeHeaders,
      ),
      if (clientCode != null && clientCode.isNotEmpty)
        _check(
          name: 'active_photos_take_1',
          baseUrl: activeBaseUrl,
          path: '/photos',
          token: token,
          runtimeHeaders: runtimeHeaders,
          queryParameters: {
            'clientCode': clientCode,
            'source': 'photoRequest',
            'take': 1,
          },
        ),
    ];

    final result = await Future.wait(checks);
    ClientLogService.instance.add(
      type: 'network_diagnostics',
      level: result.any((check) => !check.ok) ? 'warning' : 'info',
      message: 'Собрана диагностика сети',
      data: {
        'activeBaseUrl': activeBaseUrl,
        'usingFallback': _api.isUsingFallbackBaseUrl,
        'checks': result.map((check) => check.toJson()).toList(),
      },
    );

    return NetworkDiagnosticReport(
      createdAt: DateTime.now().toUtc(),
      activeBaseUrl: activeBaseUrl,
      primaryBaseUrl: ApiConfig.baseUrl,
      fallbackBaseUrl: fallbackBaseUrl,
      usingFallback: _api.isUsingFallbackBaseUrl,
      checks: result,
    );
  }

  Future<NetworkDiagnosticCheck> _check({
    required String name,
    required String baseUrl,
    required String path,
    required Map<String, String> runtimeHeaders,
    String? token,
    Map<String, dynamic>? queryParameters,
  }) async {
    final dio = Dio(
      BaseOptions(
        connectTimeout: _timeout,
        receiveTimeout: _timeout,
        sendTimeout: _timeout,
        validateStatus: (_) => true,
      ),
    );
    final uri = _buildUri(baseUrl, path, queryParameters);
    final stopwatch = Stopwatch()..start();

    try {
      final response = await dio
          .getUri<dynamic>(
            uri,
            options: Options(
              headers: {
                ...ApiConfig.defaultHeaders,
                ...runtimeHeaders,
                if (token != null && token.isNotEmpty)
                  'Authorization': 'Bearer $token',
              },
            ),
          )
          .timeout(_timeout + const Duration(seconds: 2));
      stopwatch.stop();
      return NetworkDiagnosticCheck(
        name: name,
        method: 'GET',
        url: uri.toString(),
        durationMs: stopwatch.elapsedMilliseconds,
        statusCode: response.statusCode,
      );
    } on DioException catch (error) {
      stopwatch.stop();
      return NetworkDiagnosticCheck(
        name: name,
        method: 'GET',
        url: uri.toString(),
        durationMs: stopwatch.elapsedMilliseconds,
        statusCode: error.response?.statusCode,
        errorType: error.type.name,
        error: error.message ?? error.toString(),
      );
    } on TimeoutException catch (error) {
      stopwatch.stop();
      return NetworkDiagnosticCheck(
        name: name,
        method: 'GET',
        url: uri.toString(),
        durationMs: stopwatch.elapsedMilliseconds,
        errorType: 'timeout',
        error: error.toString(),
      );
    } catch (error) {
      stopwatch.stop();
      return NetworkDiagnosticCheck(
        name: name,
        method: 'GET',
        url: uri.toString(),
        durationMs: stopwatch.elapsedMilliseconds,
        errorType: error.runtimeType.toString(),
        error: error.toString(),
      );
    } finally {
      dio.close(force: true);
    }
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
        (key, value) => MapEntry(key, value.toString()),
      ),
    );
  }
}
