import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/api_client.dart';

const partnerLinkAgentDomain = '2a-logistic.ru';
const _partnerLinkTokenKey = 'pending_partner_link_token_v1';
final _partnerLinkTokenPattern = RegExp(r'^[A-Za-z0-9_-]{40,128}$');

enum PartnerLinkPhase {
  loading,
  idle,
  pending,
  validating,
  completing,
  completed,
  error,
}

class PartnerLinkState {
  const PartnerLinkState({
    this.phase = PartnerLinkPhase.loading,
    this.token,
    this.dismissedToken,
    this.partnerName,
    this.clientCode,
    this.error,
  });

  final PartnerLinkPhase phase;
  final String? token;
  final String? dismissedToken;
  final String? partnerName;
  final String? clientCode;
  final String? error;

  bool get hasPendingToken =>
      token != null &&
      phase != PartnerLinkPhase.idle &&
      phase != PartnerLinkPhase.completed;

  bool shouldCaptureRouteToken(String routeToken) =>
      routeToken != token && routeToken != dismissedToken;

  String? pendingTokenForRoute(String? routeToken) {
    if (routeToken != null) {
      return routeToken == dismissedToken ? null : routeToken;
    }
    return hasPendingToken ? token : null;
  }

  PartnerLinkState copyWith({
    PartnerLinkPhase? phase,
    String? token,
    bool clearToken = false,
    String? dismissedToken,
    String? partnerName,
    String? clientCode,
    String? error,
    bool clearError = false,
  }) {
    return PartnerLinkState(
      phase: phase ?? this.phase,
      token: clearToken ? null : (token ?? this.token),
      dismissedToken: dismissedToken ?? this.dismissedToken,
      partnerName: partnerName ?? this.partnerName,
      clientCode: clientCode ?? this.clientCode,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class PartnerLinkNotifier extends Notifier<PartnerLinkState> {
  late ApiClient _apiClient;
  bool _capturedDuringRestore = false;

  @override
  PartnerLinkState build() {
    _apiClient = ref.read(apiClientProvider);
    _capturedDuringRestore = false;
    Future<void>.microtask(_restore);
    return const PartnerLinkState();
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_partnerLinkTokenKey);
      if (_capturedDuringRestore) return;
      if (token != null && _partnerLinkTokenPattern.hasMatch(token)) {
        state = PartnerLinkState(phase: PartnerLinkPhase.pending, token: token);
      } else {
        if (token != null) await prefs.remove(_partnerLinkTokenKey);
        state = const PartnerLinkState(phase: PartnerLinkPhase.idle);
      }
    } catch (error) {
      debugPrint('Partner link restore failed: $error');
      if (!_capturedDuringRestore) {
        state = const PartnerLinkState(phase: PartnerLinkPhase.idle);
      }
    }
  }

  Future<bool> captureToken(String rawToken) async {
    final token = rawToken.trim();
    _capturedDuringRestore = true;
    if (!_partnerLinkTokenPattern.hasMatch(token)) {
      state = PartnerLinkState(
        phase: PartnerLinkPhase.error,
        token: token.length <= 256 ? token : null,
        error: 'Ссылка партнёра недействительна',
      );
      return false;
    }

    if (state.token != token || !state.hasPendingToken) {
      state = PartnerLinkState(phase: PartnerLinkPhase.pending, token: token);
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_partnerLinkTokenKey, token);
    } catch (error) {
      debugPrint('Partner link persist failed: $error');
    }
    return true;
  }

  Future<bool> validate() async {
    final token = state.token;
    if (token == null) return false;
    state = state.copyWith(
      phase: PartnerLinkPhase.validating,
      clearError: true,
    );
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        '/partner-link/sessions/${Uri.encodeComponent(token)}',
      );
      final data = response.data?['data'];
      if (data is! Map) throw StateError('Некорректный ответ сервера');
      state = state.copyWith(
        phase: PartnerLinkPhase.pending,
        partnerName: data['partnerName'] as String?,
        clearError: true,
      );
      return true;
    } catch (error) {
      state = state.copyWith(
        phase: PartnerLinkPhase.error,
        error: _messageFromError(error, 'Не удалось проверить ссылку партнёра'),
      );
      return false;
    }
  }

  Future<bool> complete() async {
    final token = state.token;
    if (token == null) return false;
    state = state.copyWith(
      phase: PartnerLinkPhase.completing,
      clearError: true,
    );
    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        '/partner-link/sessions/${Uri.encodeComponent(token)}/complete',
      );
      final data = response.data?['data'];
      if (data is! Map) throw StateError('Некорректный ответ сервера');
      final clientCode = data['clientCode'] as String?;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_partnerLinkTokenKey);
      } catch (error) {
        debugPrint('Partner link cleanup failed: $error');
      }
      state = PartnerLinkState(
        phase: PartnerLinkPhase.completed,
        token: token,
        partnerName: state.partnerName,
        clientCode: clientCode,
      );
      return true;
    } catch (error) {
      state = state.copyWith(
        phase: PartnerLinkPhase.error,
        error: _messageFromError(error, 'Не удалось привязать аккаунт'),
      );
      return false;
    }
  }

  Future<void> clear() async {
    _capturedDuringRestore = true;
    final dismissedToken = state.token;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_partnerLinkTokenKey);
    } catch (error) {
      debugPrint('Partner link cleanup failed: $error');
    }
    state = PartnerLinkState(
      phase: PartnerLinkPhase.idle,
      dismissedToken: dismissedToken,
    );
  }

  String _messageFromError(Object error, String fallback) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map && data['error'] is String) {
        return data['error'] as String;
      }
      if (error.response?.statusCode == 410) {
        return 'Срок действия ссылки истёк. Запросите новую ссылку у партнёра.';
      }
    }
    return fallback;
  }
}

final partnerLinkProvider =
    NotifierProvider<PartnerLinkNotifier, PartnerLinkState>(
      PartnerLinkNotifier.new,
    );
