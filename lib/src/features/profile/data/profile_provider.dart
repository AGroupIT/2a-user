import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';

/// Модель профиля клиента
class ClientProfile {
  final int id;
  final String fullName;
  final String email;
  final String? phone;
  final double balance;
  final bool isActive;
  final List<ClientCodeInfo> codes;
  final AgentInfo? agent;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const ClientProfile({
    required this.id,
    required this.fullName,
    required this.email,
    this.phone,
    required this.balance,
    required this.isActive,
    required this.codes,
    this.agent,
    required this.createdAt,
    this.updatedAt,
  });

  factory ClientProfile.fromJson(Map<String, dynamic> json) {
    final codesJson = json['codes'] as List<dynamic>? ?? [];
    final agentJson = json['agent'] as Map<String, dynamic>?;

    // Balance может приходить как String или num
    double parseBalance(dynamic value) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    return ClientProfile(
      id: json['id'] as int,
      fullName: json['fullName'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String?,
      balance: parseBalance(json['balance']),
      isActive: json['isActive'] as bool? ?? true,
      codes: codesJson
          .map((c) => ClientCodeInfo.fromJson(c as Map<String, dynamic>))
          .toList(),
      agent: agentJson != null ? AgentInfo.fromJson(agentJson) : null,
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
    );
  }
}

class ClientCodeInfo {
  final int id;
  final String code;

  const ClientCodeInfo({required this.id, required this.code});

  factory ClientCodeInfo.fromJson(Map<String, dynamic> json) {
    return ClientCodeInfo(
      id: json['id'] as int,
      code: json['code'] as String? ?? '',
    );
  }
}

class AgentInfo {
  final int id;
  final String name;
  final String? domain;
  final String? prefix;
  final String? colorPrimary;
  final String? colorSecondary;
  final String? logoUrl;

  const AgentInfo({
    required this.id,
    required this.name,
    this.domain,
    this.prefix,
    this.colorPrimary,
    this.colorSecondary,
    this.logoUrl,
  });

  factory AgentInfo.fromJson(Map<String, dynamic> json) {
    return AgentInfo(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      domain: json['domain'] as String?,
      prefix: json['prefix'] as String?,
      colorPrimary: json['colorPrimary'] as String?,
      colorSecondary: json['colorSecondary'] as String?,
      logoUrl: json['logoUrl'] as String?,
    );
  }
}

/// Модель статистики клиента
class ClientStats {
  final Map<String, int> tracks;
  final Map<String, int> invoices;
  final Map<String, int> photoRequests;
  final Map<String, int> questions;
  final int totalTracks;
  final int totalInvoices;
  final int totalAssemblies;

  const ClientStats({
    required this.tracks,
    required this.invoices,
    required this.photoRequests,
    required this.questions,
    required this.totalTracks,
    required this.totalInvoices,
    required this.totalAssemblies,
  });

  factory ClientStats.fromJson(Map<String, dynamic> json) {
    final tracksMap = (json['tracks'] as Map<String, dynamic>? ?? {}).map(
      (k, v) => MapEntry(k, v as int? ?? 0),
    );
    final invoicesMap = (json['invoices'] as Map<String, dynamic>? ?? {}).map(
      (k, v) => MapEntry(k, v as int? ?? 0),
    );
    final photoRequestsMap =
        (json['photoRequests'] as Map<String, dynamic>? ?? {}).map(
          (k, v) => MapEntry(k, v as int? ?? 0),
        );
    final questionsMap = (json['questions'] as Map<String, dynamic>? ?? {}).map(
      (k, v) => MapEntry(k, v as int? ?? 0),
    );
    final totals = json['totals'] as Map<String, dynamic>? ?? {};

    return ClientStats(
      tracks: tracksMap,
      invoices: invoicesMap,
      photoRequests: photoRequestsMap,
      questions: questionsMap,
      totalTracks: totals['tracks'] as int? ?? 0,
      totalInvoices: totals['invoices'] as int? ?? 0,
      totalAssemblies: totals['assemblies'] as int? ?? 0,
    );
  }

  /// Пустая статистика
  static const empty = ClientStats(
    tracks: {},
    invoices: {},
    photoRequests: {},
    questions: {},
    totalTracks: 0,
    totalInvoices: 0,
    totalAssemblies: 0,
  );
}

/// Провайдер для получения профиля клиента
final clientProfileProvider = FutureProvider<ClientProfile?>((ref) async {
  final apiClient = ref.read(apiClientProvider);
  
  // Проверяем, есть ли токен перед запросом
  final hasToken = apiClient.hasToken;
  if (!hasToken) {
    debugPrint('🔐 No auth token, skipping profile request');
    return null;
  }

  try {
    final response = await apiClient.get('/client/profile');

    if (response.statusCode == 200 && response.data != null) {
      final data = response.data as Map<String, dynamic>;
      final profileData = data['data'] as Map<String, dynamic>?;
      if (profileData != null) {
        return ClientProfile.fromJson(profileData);
      }
    }
    return null;
  } on DioException catch (e) {
    debugPrint('Error loading client profile: $e');
    return null;
  }
});

/// Провайдер для получения статистики клиента
final clientStatsProvider = FutureProvider.family<ClientStats, String?>((
  ref,
  clientCode,
) async {
  final apiClient = ref.read(apiClientProvider);

  try {
    final queryParams = <String, dynamic>{};
    if (clientCode != null && clientCode.isNotEmpty) {
      queryParams['clientCode'] = clientCode;
    }

    final response = await apiClient.get(
      '/client/stats',
      queryParameters: queryParams,
    );

    if (response.statusCode == 200 && response.data != null) {
      final data = response.data as Map<String, dynamic>;
      final statsData = data['data'] as Map<String, dynamic>?;
      if (statsData != null) {
        return ClientStats.fromJson(statsData);
      }
    }
    return ClientStats.empty;
  } on DioException catch (e) {
    debugPrint('Error loading client stats: $e');
    return ClientStats.empty;
  }
});

/// Репозиторий для работы с профилем клиента
class ProfileRepository {
  final ApiClient _apiClient;

  ProfileRepository(this._apiClient);

  /// Обновить профиль клиента
  Future<void> updateProfile({
    String? fullName,
    String? email,
    String? phone,
  }) async {
    final data = <String, dynamic>{};
    if (fullName != null) data['fullName'] = fullName;
    if (email != null) data['email'] = email;
    if (phone != null) data['phone'] = phone;

    final response = await _apiClient.patch('/client/profile', data: data);

    if (response.statusCode != 200) {
      final error = response.data?['error'] as String? ?? 'Ошибка обновления';
      throw Exception(error);
    }
  }

  /// Сменить пароль
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final response = await _apiClient.post(
      '/client/profile',
      data: {
        'action': 'changePassword',
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      },
    );

    if (response.statusCode != 200) {
      final error = response.data?['error'] as String? ?? 'Ошибка смены пароля';
      throw Exception(error);
    }
  }
}

/// Провайдер для репозитория профиля
final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.read(apiClientProvider));
});
