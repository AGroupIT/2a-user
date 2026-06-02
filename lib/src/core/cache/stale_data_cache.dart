import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../logging/client_log_service.dart';

const staleDataRefreshMessage =
    'Показаны сохранённые данные. Обновите страницу, чтобы увидеть свежие данные.';

class StaleDataNotice {
  const StaleDataNotice({
    required this.createdAt,
    required this.label,
    required this.message,
  });

  final DateTime createdAt;
  final String label;
  final String message;
}

final staleDataNoticeProvider =
    NotifierProvider<StaleDataNoticeNotifier, StaleDataNotice?>(
      StaleDataNoticeNotifier.new,
    );

class StaleDataNoticeNotifier extends Notifier<StaleDataNotice?> {
  static const _throttle = Duration(seconds: 8);

  @override
  StaleDataNotice? build() => null;

  void show(String label) {
    final now = DateTime.now();
    final previous = state;
    if (previous != null && now.difference(previous.createdAt) < _throttle) {
      return;
    }

    state = StaleDataNotice(
      createdAt: now,
      label: label,
      message: staleDataRefreshMessage,
    );
  }

  void clear() {
    state = null;
  }
}

class StaleDataCache {
  StaleDataCache._();

  static const _prefix = 'stale_data_cache_v1';
  static const defaultTimeout = Duration(seconds: 8);

  static String buildKey(String namespace, Map<String, dynamic> parts) {
    final normalized =
        parts.entries
            .where((entry) => entry.value != null)
            .map((entry) => {'key': entry.key, 'value': entry.value.toString()})
            .toList()
          ..sort((a, b) => a['key']!.compareTo(b['key']!));
    final encoded = base64Url.encode(utf8.encode(jsonEncode(normalized)));
    return '$namespace:$encoded';
  }

  static Future<Map<String, dynamic>> getJson({
    required Ref ref,
    required String cacheKey,
    required String label,
    required Future<Response<dynamic>> Function() request,
    Duration timeout = defaultTimeout,
  }) async {
    try {
      final response = await request().timeout(timeout);
      final data = response.data;
      if (response.statusCode == 200 && data is Map<String, dynamic>) {
        unawaited(_write(cacheKey, data));
        return data;
      }
      throw StateError(
        'Unexpected response for $label: ${response.statusCode}',
      );
    } catch (error, stackTrace) {
      if (!_isFallbackEligible(error)) {
        Error.throwWithStackTrace(error, stackTrace);
      }

      final cached = await _read(cacheKey);
      if (cached != null) {
        ref.read(staleDataNoticeProvider.notifier).show(label);
        ClientLogService.instance.add(
          type: 'stale_cache_hit',
          level: 'warning',
          message: 'Показаны сохранённые данные: $label',
          data: {
            'label': label,
            'cacheKey': _safeKey(cacheKey),
            'errorType': error.runtimeType.toString(),
            'error': _safeError(error),
          },
        );
        return cached;
      }

      ClientLogService.instance.add(
        type: 'stale_cache_miss',
        level: 'warning',
        message: 'Нет сохранённых данных для $label',
        data: {
          'label': label,
          'cacheKey': _safeKey(cacheKey),
          'errorType': error.runtimeType.toString(),
          'error': _safeError(error),
        },
      );
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  static Future<void> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs
          .getKeys()
          .where((key) => key.startsWith('$_prefix:'))
          .toList();
      await Future.wait(keys.map(prefs.remove));
    } catch (error) {
      ClientLogService.instance.add(
        type: 'stale_cache_clear_error',
        level: 'warning',
        message: 'Не удалось очистить сохранённый кэш',
        data: {'error': _safeError(error)},
      );
    }
  }

  static Future<void> _write(String cacheKey, Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = <String, dynamic>{
        'cachedAt': DateTime.now().toUtc().toIso8601String(),
        'data': data,
      };
      await prefs.setString('$_prefix:$cacheKey', jsonEncode(payload));
    } catch (error) {
      ClientLogService.instance.add(
        type: 'stale_cache_write_error',
        level: 'warning',
        message: 'Не удалось сохранить данные для офлайн-показа',
        data: {'cacheKey': _safeKey(cacheKey), 'error': _safeError(error)},
      );
    }
  }

  static Future<Map<String, dynamic>?> _read(String cacheKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_prefix:$cacheKey');
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      final data = decoded['data'];
      return data is Map<String, dynamic> ? data : null;
    } catch (error) {
      ClientLogService.instance.add(
        type: 'stale_cache_read_error',
        level: 'warning',
        message: 'Не удалось прочитать сохранённые данные',
        data: {'cacheKey': _safeKey(cacheKey), 'error': _safeError(error)},
      );
      return null;
    }
  }

  static bool _isFallbackEligible(Object error) {
    if (error is TimeoutException) return true;
    if (error is! DioException) return false;

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
      case DioExceptionType.unknown:
        return true;
      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        return statusCode != null && statusCode >= 500;
      case DioExceptionType.badCertificate:
      case DioExceptionType.cancel:
        return false;
    }
  }

  static String _safeKey(String cacheKey) =>
      cacheKey.length > 80 ? '${cacheKey.substring(0, 80)}…' : cacheKey;

  static String _safeError(Object error) {
    return error.toString().replaceAll(
      RegExp(r'Bearer\s+[A-Za-z0-9._~-]+', caseSensitive: false),
      'Bearer <redacted>',
    );
  }
}
