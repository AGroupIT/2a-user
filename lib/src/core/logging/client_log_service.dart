import 'dart:collection';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../config/sentry_config.dart';

class ClientLogEntry {
  const ClientLogEntry({
    required this.timestamp,
    required this.type,
    required this.level,
    required this.message,
    this.route,
    this.requestId,
    this.userId,
    this.clientCode,
    this.agentId,
    this.data,
  });

  final DateTime timestamp;
  final String type;
  final String level;
  final String message;
  final String? route;
  final String? requestId;
  final int? userId;
  final String? clientCode;
  final int? agentId;
  final Map<String, dynamic>? data;

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'type': type,
      'level': level,
      'message': message,
      if (route != null) 'route': route,
      if (requestId != null) 'requestId': requestId,
      if (userId != null) 'userId': userId,
      if (clientCode != null) 'clientCode': clientCode,
      if (agentId != null) 'agentId': agentId,
      if (data != null && data!.isNotEmpty) 'data': data,
    };
  }
}

class ClientLogUserContext {
  const ClientLogUserContext({this.userId, this.clientCode, this.agentId});

  final int? userId;
  final String? clientCode;
  final int? agentId;
}

class ClientLogService {
  ClientLogService._();

  static final ClientLogService instance = ClientLogService._();
  static const int _maxEntries = 180;

  final Queue<ClientLogEntry> _entries = Queue<ClientLogEntry>();
  ClientLogUserContext _userContext = const ClientLogUserContext();
  String? _currentScreen;

  String? get currentScreen => _currentScreen;

  void setUserContext({int? userId, String? clientCode, int? agentId}) {
    _userContext = ClientLogUserContext(
      userId: userId,
      clientCode: _redactText(clientCode),
      agentId: agentId,
    );

    if (SentryConfig.enabled) {
      Sentry.configureScope((scope) {
        scope.setUser(SentryUser(id: userId?.toString()));
        scope.setContexts('client', {
          if (clientCode != null) 'code': clientCode,
          if (agentId != null) 'agentId': agentId,
        });
      });
    }
  }

  void clearUserContext() {
    _userContext = const ClientLogUserContext();
    if (SentryConfig.enabled) {
      Sentry.configureScope((scope) => scope.setUser(null));
    }
  }

  void screen(String route) {
    final normalized = route.trim().isEmpty ? 'unknown' : route.trim();
    _currentScreen = normalized;
    add(
      type: 'screen',
      level: 'info',
      message: 'Открыт экран $normalized',
      route: normalized,
    );
  }

  void action(String name, {Map<String, dynamic>? data}) {
    add(
      type: 'action',
      level: 'info',
      message: name,
      route: _currentScreen,
      data: data,
    );
  }

  void shownMessage(
    String message, {
    bool isError = false,
    String source = 'toast',
    Map<String, dynamic>? data,
  }) {
    add(
      type: isError ? 'shown_error' : 'shown_message',
      level: isError ? 'warning' : 'info',
      message: isError
          ? 'Показали ошибку: $message'
          : 'Показали уведомление: $message',
      route: _currentScreen,
      data: {'source': source, if (data != null) ...data},
    );
  }

  void apiRequest({
    required String method,
    required String url,
    required String requestId,
    String? operation,
  }) {
    add(
      type: 'api_request',
      level: 'info',
      message: operation == null ? '$method $url' : '$operation: $method $url',
      route: _currentScreen,
      requestId: requestId,
      data: {
        'method': method,
        'url': url,
        if (operation != null) 'operation': operation,
      },
    );
  }

  void apiResponse({
    required String method,
    required String url,
    required String requestId,
    required int? statusCode,
    required int durationMs,
    String? operation,
  }) {
    add(
      type: 'api_response',
      level: statusCode != null && statusCode >= 400 ? 'warning' : 'info',
      message: operation == null
          ? '$method $url -> ${statusCode ?? 'no_status'}'
          : '$operation: $method $url -> ${statusCode ?? 'no_status'}',
      route: _currentScreen,
      requestId: requestId,
      data: {
        'method': method,
        'url': url,
        'statusCode': statusCode,
        'durationMs': durationMs,
        if (operation != null) 'operation': operation,
      },
    );
  }

  void apiError({
    required String method,
    required String url,
    required String requestId,
    required int? statusCode,
    required int durationMs,
    required DioExceptionType type,
    String? error,
    String? operation,
  }) {
    add(
      type: 'api_error',
      level: 'error',
      message: operation == null
          ? '$method $url failed ${statusCode ?? type.name}'
          : '$operation: $method $url failed ${statusCode ?? type.name}',
      route: _currentScreen,
      requestId: requestId,
      data: {
        'method': method,
        'url': url,
        'statusCode': statusCode,
        'durationMs': durationMs,
        'dioType': type.name,
        if (operation != null) 'operation': operation,
        if (error != null) 'error': _redactText(error),
      },
    );
  }

  void apiRetry({
    required String method,
    required String url,
    required String requestId,
    required int attempt,
    required int maxAttempts,
    Object? error,
  }) {
    add(
      type: 'api_retry',
      level: 'warning',
      message: 'Повтор API-запроса $method $url',
      route: _currentScreen,
      requestId: requestId,
      data: {
        'method': method,
        'url': url,
        'attempt': attempt,
        'maxAttempts': maxAttempts,
        if (error != null) 'error': _redactText(error.toString()),
      },
    );
  }

  void apiTimeout({
    required String method,
    required String path,
    required Duration timeout,
  }) {
    add(
      type: 'api_timeout',
      level: 'error',
      message: 'API-запрос превысил общий таймаут $method $path',
      route: _currentScreen,
      data: {
        'method': method,
        'path': path,
        'timeoutMs': timeout.inMilliseconds,
      },
    );
  }

  void httpConnectionReset({String? reason}) {
    add(
      type: 'http_connection_reset',
      level: 'warning',
      message: 'Сброшены HTTP-соединения',
      route: _currentScreen,
      data: {if (reason != null) 'reason': reason},
    );
  }

  void error(String message, {Object? error, StackTrace? stackTrace}) {
    add(
      type: 'error',
      level: 'error',
      message: message,
      route: _currentScreen,
      data: {
        if (error != null) 'error': _redactText(error.toString()),
        if (stackTrace != null)
          'stackTrace': _redactText(stackTrace.toString()),
      },
    );
  }

  Future<void> captureNonFatal(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? data,
  }) async {
    add(
      type: 'non_fatal_error',
      level: 'error',
      message: message,
      route: _currentScreen,
      data: {
        if (error != null) 'error': _redactText(error.toString()),
        if (stackTrace != null)
          'stackTrace': _redactText(stackTrace.toString()),
        if (data != null) ...data,
      },
    );

    if (!SentryConfig.enabled) return;

    final sanitizedData = _sanitizeMap(data) ?? const <String, dynamic>{};
    await Sentry.captureException(
      error ?? StateError(message),
      stackTrace: stackTrace,
      hint: Hint.withMap({
        'type': 'non_fatal',
        'message': _redactText(message),
        if (_currentScreen != null) 'route': _currentScreen,
        if (sanitizedData.isNotEmpty) 'data': sanitizedData,
      }),
    );
  }

  void add({
    required String type,
    required String level,
    required String message,
    String? route,
    String? requestId,
    Map<String, dynamic>? data,
  }) {
    final entry = ClientLogEntry(
      timestamp: DateTime.now().toUtc(),
      type: type,
      level: level,
      message: _redactText(message) ?? '',
      route: route,
      requestId: requestId,
      userId: _userContext.userId,
      clientCode: _userContext.clientCode,
      agentId: _userContext.agentId,
      data: _sanitizeMap(data),
    );

    _entries.addLast(entry);
    while (_entries.length > _maxEntries) {
      _entries.removeFirst();
    }

    if (SentryConfig.enabled) {
      Sentry.addBreadcrumb(
        Breadcrumb(
          message: entry.message,
          category: type,
          level: _sentryLevel(level),
          data: entry.toJson(),
        ),
      );
    }

    if (kDebugMode && level == 'error') {
      debugPrint('[ClientLog] ${entry.message}');
    }
  }

  List<Map<String, dynamic>> lastLogs({int limit = 100}) {
    return _entries
        .toList()
        .reversed
        .take(limit)
        .map((e) => e.toJson())
        .toList()
      ..sort((a, b) => '${a['timestamp']}'.compareTo('${b['timestamp']}'));
  }

  List<Map<String, dynamic>> lastApiErrors({int limit = 20}) {
    return _entries
        .where((e) => e.type == 'api_error')
        .toList()
        .reversed
        .take(limit)
        .map((e) => e.toJson())
        .toList()
        .reversed
        .toList();
  }

  SentryLevel _sentryLevel(String level) {
    switch (level) {
      case 'error':
        return SentryLevel.error;
      case 'warning':
        return SentryLevel.warning;
      case 'debug':
        return SentryLevel.debug;
      default:
        return SentryLevel.info;
    }
  }

  Map<String, dynamic>? _sanitizeMap(Map<String, dynamic>? input) {
    if (input == null) return null;
    final result = <String, dynamic>{};
    for (final entry in input.entries) {
      final key = entry.key;
      if (_isSensitiveKey(key)) {
        result[key] = '<redacted>';
      } else {
        result[key] = _sanitizeValue(entry.value);
      }
    }
    return result;
  }

  dynamic _sanitizeValue(dynamic value) {
    if (value is String) return _redactText(value);
    if (value is num || value is bool || value == null) return value;
    if (value is Map) {
      return _sanitizeMap({
        for (final entry in value.entries) entry.key.toString(): entry.value,
      });
    }
    if (value is Iterable) {
      return value.take(20).map(_sanitizeValue).toList();
    }
    return _redactText(value.toString());
  }

  bool _isSensitiveKey(String key) {
    final lower = key.toLowerCase();
    return lower.contains('authorization') ||
        lower.contains('token') ||
        lower.contains('password') ||
        lower.contains('secret') ||
        lower.contains('cookie') ||
        lower == 'email' ||
        lower == 'phone';
  }

  static String? _redactText(String? value) {
    if (value == null) return null;
    var result = value;
    result = result.replaceAll(
      RegExp(r'Bearer\s+[A-Za-z0-9._~+/=-]+', caseSensitive: false),
      'Bearer <redacted>',
    );
    result = result.replaceAll(
      RegExp(r'([A-Za-z0-9._%+-]+)@([A-Za-z0-9.-]+\.[A-Za-z]{2,})'),
      '<email>',
    );
    result = result.replaceAll(
      RegExp(r'(?<![A-Za-z0-9])\+?\d[\d\s().-]{8,}\d(?![A-Za-z0-9])'),
      '<phone>',
    );
    if (result.length > 500) {
      result = '${result.substring(0, 500)}...';
    }
    return result;
  }
}

class ClientLogNavigatorObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _log(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (newRoute != null) _log(newRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute != null) _log(previousRoute);
  }

  void _log(Route<dynamic> route) {
    final name = route.settings.name;
    if (name == null || name.isEmpty) return;
    ClientLogService.instance.screen(name);
  }
}
