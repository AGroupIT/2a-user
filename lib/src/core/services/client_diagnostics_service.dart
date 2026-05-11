import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../network/api_client.dart';
import 'platform_helper.dart';

class ClientDiagnosticsService {
  static const Duration _defaultThrottle = Duration(seconds: 20);
  static final Map<String, DateTime> _lastSentAt = <String, DateTime>{};

  static void log(
    ApiClient apiClient, {
    required String app,
    required String event,
    String? route,
    Map<String, Object?> meta = const <String, Object?>{},
    String? throttleKey,
    Duration throttle = _defaultThrottle,
  }) {
    if (throttleKey != null && !_canSend(throttleKey, throttle)) return;

    unawaited(
      _send(apiClient, app: app, event: event, route: route, meta: meta),
    );
  }

  static int elapsedMs(DateTime startedAt) {
    return DateTime.now().difference(startedAt).inMilliseconds;
  }

  static String errorSummary(Object error) {
    if (error is DioException) {
      final status = error.response?.statusCode;
      final path = error.requestOptions.path;
      return '${error.type.name}${status == null ? '' : ' $status'} $path';
    }
    return error.toString();
  }

  static bool _canSend(String key, Duration throttle) {
    final now = DateTime.now();
    final lastSentAt = _lastSentAt[key];
    if (lastSentAt != null && now.difference(lastSentAt) < throttle) {
      return false;
    }
    _lastSentAt[key] = now;
    return true;
  }

  static Future<void> _send(
    ApiClient apiClient, {
    required String app,
    required String event,
    String? route,
    required Map<String, Object?> meta,
  }) async {
    try {
      await apiClient.post<void>(
        '/client-diagnostics',
        data: <String, Object?>{
          'app': app,
          'event': event,
          'route': route,
          'platform': getPlatformNameImpl(),
          'meta': _sanitizeMeta(meta),
        },
        options: Options(
          sendTimeout: const Duration(seconds: 2),
          receiveTimeout: const Duration(seconds: 2),
        ),
      );
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[Diagnostics] skipped: $error');
      }
    }
  }

  static Map<String, Object?> _sanitizeMeta(Map<String, Object?> meta) {
    final result = <String, Object?>{};
    for (final entry in meta.entries.take(24)) {
      result[entry.key] = _sanitizeValue(entry.value);
    }
    return result;
  }

  static Object? _sanitizeValue(Object? value) {
    if (value == null || value is num || value is bool) return value;
    if (value is DateTime) return value.toIso8601String();
    if (value is String) {
      return value.length > 300 ? value.substring(0, 300) : value;
    }
    if (value is Iterable) {
      return value.take(12).map(_sanitizeValue).toList();
    }
    if (value is Map) {
      return value.map<String, Object?>(
        (key, mapValue) => MapEntry(key.toString(), _sanitizeValue(mapValue)),
      );
    }
    final text = value.toString();
    return text.length > 300 ? text.substring(0, 300) : text;
  }
}
