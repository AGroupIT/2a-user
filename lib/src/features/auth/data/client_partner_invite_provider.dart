import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../../core/network/api_client.dart';

const _inviteTokenKey = 'pending_client_partner_invite_v1';
const _inviteIdempotencyKey = 'pending_client_partner_registration_key_v1';
final _inviteTokenPattern = RegExp(
  r'^[0-9a-fA-F-]{36}\.[1-9][0-9]{0,8}\.[A-Za-z0-9_-]{43}$',
);

enum ClientPartnerInvitePhase {
  loading,
  idle,
  pending,
  validating,
  valid,
  error,
}

class ClientPartnerInviteState {
  const ClientPartnerInviteState({
    this.phase = ClientPartnerInvitePhase.loading,
    this.token,
    this.registrationIdempotencyKey,
    this.partnerName,
    this.agentName,
    this.agentDomain,
    this.colorPrimary,
    this.colorSecondary,
    this.prefix,
    this.shortCode,
    this.error,
  });

  final ClientPartnerInvitePhase phase;
  final String? token;
  final String? registrationIdempotencyKey;
  final String? partnerName;
  final String? agentName;
  final String? agentDomain;
  final String? colorPrimary;
  final String? colorSecondary;
  final String? prefix;
  final String? shortCode;
  final String? error;

  bool get hasPendingInvite =>
      token != null &&
      registrationIdempotencyKey != null &&
      phase != ClientPartnerInvitePhase.idle &&
      phase != ClientPartnerInvitePhase.error;

  bool get isValidated => phase == ClientPartnerInvitePhase.valid;

  ClientPartnerInviteState copyWith({
    ClientPartnerInvitePhase? phase,
    String? token,
    String? registrationIdempotencyKey,
    String? partnerName,
    String? agentName,
    String? agentDomain,
    String? colorPrimary,
    String? colorSecondary,
    String? prefix,
    String? shortCode,
    String? error,
    bool clearError = false,
  }) => ClientPartnerInviteState(
    phase: phase ?? this.phase,
    token: token ?? this.token,
    registrationIdempotencyKey:
        registrationIdempotencyKey ?? this.registrationIdempotencyKey,
    partnerName: partnerName ?? this.partnerName,
    agentName: agentName ?? this.agentName,
    agentDomain: agentDomain ?? this.agentDomain,
    colorPrimary: colorPrimary ?? this.colorPrimary,
    colorSecondary: colorSecondary ?? this.colorSecondary,
    prefix: prefix ?? this.prefix,
    shortCode: shortCode ?? this.shortCode,
    error: clearError ? null : (error ?? this.error),
  );
}

class ClientPartnerInviteNotifier extends Notifier<ClientPartnerInviteState> {
  late ApiClient _apiClient;
  bool _capturedDuringRestore = false;
  int _captureGeneration = 0;
  int _validationGeneration = 0;

  @override
  ClientPartnerInviteState build() {
    _apiClient = ref.read(apiClientProvider);
    unawaited(Future<void>.microtask(_restore));
    return const ClientPartnerInviteState();
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_inviteTokenKey);
      final idempotencyKey = prefs.getString(_inviteIdempotencyKey);
      if (_capturedDuringRestore) return;
      if (token != null &&
          _inviteTokenPattern.hasMatch(token) &&
          idempotencyKey != null &&
          idempotencyKey.length >= 8) {
        state = ClientPartnerInviteState(
          phase: ClientPartnerInvitePhase.pending,
          token: token,
          registrationIdempotencyKey: idempotencyKey,
        );
        unawaited(validate());
      } else {
        await _clearPreferences(prefs);
        state = const ClientPartnerInviteState(
          phase: ClientPartnerInvitePhase.idle,
        );
      }
    } catch (error) {
      debugPrint('Client partner invite restore failed: $error');
      if (!_capturedDuringRestore) {
        state = const ClientPartnerInviteState(
          phase: ClientPartnerInvitePhase.idle,
        );
      }
    }
  }

  Future<bool> captureToken(String rawToken) async {
    final token = rawToken.trim();
    _capturedDuringRestore = true;
    final captureGeneration = ++_captureGeneration;
    _validationGeneration += 1;
    if (!_inviteTokenPattern.hasMatch(token)) {
      state = const ClientPartnerInviteState(
        phase: ClientPartnerInvitePhase.error,
        error: 'Партнёрская ссылка недействительна',
      );
      return false;
    }

    final isSameToken = state.token == token;
    final idempotencyKey =
        isSameToken && state.registrationIdempotencyKey != null
        ? state.registrationIdempotencyKey!
        : const Uuid().v4();
    state = ClientPartnerInviteState(
      phase: ClientPartnerInvitePhase.pending,
      token: token,
      registrationIdempotencyKey: idempotencyKey,
    );
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_inviteTokenKey, token);
      await prefs.setString(_inviteIdempotencyKey, idempotencyKey);
      if (captureGeneration != _captureGeneration) {
        await _persistCurrentInvite(prefs);
      }
    } catch (error) {
      debugPrint('Client partner invite persist failed: $error');
    }
    return true;
  }

  Future<bool> validate() async {
    final token = state.token;
    final idempotencyKey = state.registrationIdempotencyKey;
    if (token == null || idempotencyKey == null) return false;
    final validationGeneration = ++_validationGeneration;
    state = state.copyWith(
      phase: ClientPartnerInvitePhase.validating,
      clearError: true,
    );
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        '/public/client-partner-invites/${Uri.encodeComponent(token)}',
      );
      final data = response.data?['data'];
      if (data is! Map) throw StateError('Некорректный ответ сервера');
      if (!_isCurrentValidation(validationGeneration, token, idempotencyKey)) {
        return false;
      }
      state = state.copyWith(
        phase: ClientPartnerInvitePhase.valid,
        partnerName: data['partnerName'] as String?,
        agentName: data['agentName'] as String?,
        agentDomain: data['agentDomain'] as String?,
        colorPrimary: data['colorPrimary'] as String?,
        colorSecondary: data['colorSecondary'] as String?,
        prefix: data['prefix'] as String?,
        shortCode: data['shortCode'] as String?,
        clearError: true,
      );
      return true;
    } catch (error) {
      if (!_isCurrentValidation(validationGeneration, token, idempotencyKey)) {
        return false;
      }
      state = state.copyWith(
        phase: ClientPartnerInvitePhase.error,
        error: _messageFromError(error),
      );
      return false;
    }
  }

  Future<void> clear() async {
    _capturedDuringRestore = true;
    _captureGeneration += 1;
    _validationGeneration += 1;
    try {
      final prefs = await SharedPreferences.getInstance();
      await _clearPreferences(prefs);
    } catch (error) {
      debugPrint('Client partner invite cleanup failed: $error');
    }
    state = const ClientPartnerInviteState(
      phase: ClientPartnerInvitePhase.idle,
    );
  }

  Future<void> _clearPreferences(SharedPreferences prefs) async {
    await prefs.remove(_inviteTokenKey);
    await prefs.remove(_inviteIdempotencyKey);
  }

  bool _isCurrentValidation(
    int validationGeneration,
    String token,
    String idempotencyKey,
  ) =>
      validationGeneration == _validationGeneration &&
      state.token == token &&
      state.registrationIdempotencyKey == idempotencyKey;

  Future<void> _persistCurrentInvite(SharedPreferences prefs) async {
    final token = state.token;
    final idempotencyKey = state.registrationIdempotencyKey;
    if (token == null || idempotencyKey == null) {
      await _clearPreferences(prefs);
      return;
    }
    await prefs.setString(_inviteTokenKey, token);
    await prefs.setString(_inviteIdempotencyKey, idempotencyKey);
  }

  String _messageFromError(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map && data['error'] is String) {
        return data['error'] as String;
      }
      if (error.response?.statusCode == 410) {
        return 'Ссылка больше не активна. Попросите партнёра отправить новую.';
      }
    }
    return 'Не удалось проверить партнёрскую ссылку';
  }
}

final clientPartnerInviteProvider =
    NotifierProvider<ClientPartnerInviteNotifier, ClientPartnerInviteState>(
      ClientPartnerInviteNotifier.new,
    );
