import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/logging/client_log_service.dart';
import '../../../core/network/api_client.dart';

const _kClientProfileCacheKey = 'client_profile_cache_v1';

enum ClientTerminal {
  lyublino,
  km19;

  String get nameRu {
    switch (this) {
      case ClientTerminal.lyublino:
        return 'Люблино';
      case ClientTerminal.km19:
        return '19 километр';
    }
  }

  static ClientTerminal? fromJson(String? value) {
    switch (value) {
      case 'lyublino':
        return ClientTerminal.lyublino;
      case 'km19':
        return ClientTerminal.km19;
      default:
        return null;
    }
  }

  String toJson() {
    switch (this) {
      case ClientTerminal.lyublino:
        return 'lyublino';
      case ClientTerminal.km19:
        return 'km19';
    }
  }
}

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
  final ClientTerminal? terminal;

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
    this.terminal,
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
      terminal: ClientTerminal.fromJson(json['terminal'] as String?),
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
  final String? email;
  final String? phone;
  final String? colorPrimary;
  final String? colorSecondary;
  final String? logoUrl;
  final String? homeBannerImageUrl;
  final String? homeBannerEyebrow;
  final String? homeBannerTitle;
  final String? homeBannerDescription;
  final String? companyWebsiteUrl;
  final String? companyTelegramUrl;
  final String? companyTelegramChannelUrl;
  final String? companyWhatsappUrl;
  final String? companyVkUrl;
  final String? warehouseAddress;
  final String? warehousePhone;

  const AgentInfo({
    required this.id,
    required this.name,
    this.domain,
    this.prefix,
    this.email,
    this.phone,
    this.colorPrimary,
    this.colorSecondary,
    this.logoUrl,
    this.homeBannerImageUrl,
    this.homeBannerEyebrow,
    this.homeBannerTitle,
    this.homeBannerDescription,
    this.companyWebsiteUrl,
    this.companyTelegramUrl,
    this.companyTelegramChannelUrl,
    this.companyWhatsappUrl,
    this.companyVkUrl,
    this.warehouseAddress,
    this.warehousePhone,
  });

  factory AgentInfo.fromJson(Map<String, dynamic> json) {
    return AgentInfo(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      domain: json['domain'] as String?,
      prefix: json['prefix'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      colorPrimary: json['colorPrimary'] as String?,
      colorSecondary: json['colorSecondary'] as String?,
      logoUrl: json['logoUrl'] as String?,
      homeBannerImageUrl: json['homeBannerImageUrl'] as String?,
      homeBannerEyebrow: json['homeBannerEyebrow'] as String?,
      homeBannerTitle: json['homeBannerTitle'] as String?,
      homeBannerDescription: json['homeBannerDescription'] as String?,
      companyWebsiteUrl: json['companyWebsiteUrl'] as String?,
      companyTelegramUrl: json['companyTelegramUrl'] as String?,
      companyTelegramChannelUrl: json['companyTelegramChannelUrl'] as String?,
      companyWhatsappUrl: json['companyWhatsappUrl'] as String?,
      companyVkUrl: json['companyVkUrl'] as String?,
      warehouseAddress: json['warehouseAddress'] as String?,
      warehousePhone: json['warehousePhone'] as String?,
    );
  }

  bool get hasHomeBanner =>
      _hasText(homeBannerImageUrl) ||
      _hasText(homeBannerEyebrow) ||
      _hasText(homeBannerTitle) ||
      _hasText(homeBannerDescription);

  bool get hasCompanyContacts =>
      _hasText(phone) ||
      _hasText(email) ||
      _hasText(companyWebsiteUrl) ||
      _hasText(companyTelegramUrl) ||
      _hasText(companyTelegramChannelUrl) ||
      _hasText(companyWhatsappUrl) ||
      _hasText(companyVkUrl);

  bool get hasWarehouseContacts =>
      _hasText(warehouseAddress) || _hasText(warehousePhone);

  static bool _hasText(String? value) => value?.trim().isNotEmpty == true;
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

  // Проверяем, есть ли токен перед запросом (используем async версию для корректной работы после hot restart)
  final hasToken = await apiClient.hasTokenAsync();
  if (!hasToken) {
    debugPrint('🔐 No auth token, skipping profile request');
    return null;
  }

  final cachedProfile = await _readCachedClientProfile();
  if (cachedProfile != null) {
    unawaited(_refreshCachedClientProfile(apiClient));
    return cachedProfile;
  }

  try {
    final freshProfile = await _fetchAndCacheClientProfile(apiClient);
    if (freshProfile != null) return freshProfile;
    return null;
  } on DioException catch (e) {
    debugPrint('Error loading client profile: $e');
    ClientLogService.instance.add(
      type: 'client_profile_load_error',
      level: 'warning',
      message: 'Не удалось загрузить профиль клиента',
      data: {'dioType': e.type.name, 'error': e.toString()},
    );
    return _readCachedClientProfile();
  }
});

Future<void> _refreshCachedClientProfile(ApiClient apiClient) async {
  try {
    await _fetchAndCacheClientProfile(apiClient);
  } on DioException catch (e) {
    debugPrint('Background client profile refresh failed: $e');
  } catch (e, stackTrace) {
    ClientLogService.instance.error(
      'Не удалось обновить кэш профиля клиента в фоне',
      error: e,
      stackTrace: stackTrace,
    );
  }
}

Future<void> cacheClientProfileData(Map<String, dynamic> profileData) {
  if (!_hasFullAgentProfileData(profileData)) {
    return Future<void>.value();
  }
  return _cacheClientProfile(profileData);
}

Future<void> clearCachedClientProfile() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kClientProfileCacheKey);
  } catch (error, stackTrace) {
    ClientLogService.instance.error(
      'Не удалось очистить кэш профиля клиента',
      error: error,
      stackTrace: stackTrace,
    );
  }
}

Future<ClientProfile?> _fetchAndCacheClientProfile(ApiClient apiClient) async {
  final response = await apiClient.get('/client/profile');
  if (response.statusCode != 200 || response.data == null) return null;

  final data = response.data as Map<String, dynamic>;
  final profileData = data['data'] as Map<String, dynamic>?;
  if (profileData == null) return null;

  unawaited(_cacheClientProfile(profileData));
  return ClientProfile.fromJson(profileData);
}

Future<void> _cacheClientProfile(Map<String, dynamic> profileData) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kClientProfileCacheKey, jsonEncode(profileData));
  } catch (error, stackTrace) {
    ClientLogService.instance.error(
      'Не удалось сохранить профиль клиента в кэш',
      error: error,
      stackTrace: stackTrace,
    );
  }
}

Future<ClientProfile?> _readCachedClientProfile() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kClientProfileCacheKey);
    if (raw == null || raw.isEmpty) return null;
    final json = jsonDecode(raw);
    if (json is! Map<String, dynamic>) return null;
    ClientLogService.instance.add(
      type: 'client_profile_cache_hit',
      level: 'info',
      message: 'Используем кэшированный профиль клиента',
    );
    return ClientProfile.fromJson(json);
  } catch (error, stackTrace) {
    ClientLogService.instance.error(
      'Не удалось прочитать кэш профиля клиента',
      error: error,
      stackTrace: stackTrace,
    );
    return null;
  }
}

bool _hasFullAgentProfileData(Map<String, dynamic> profileData) {
  final agent = profileData['agent'];
  if (agent is! Map<String, dynamic>) return false;

  return agent.containsKey('colorPrimary') ||
      agent.containsKey('colorSecondary') ||
      agent.containsKey('logoUrl') ||
      agent.containsKey('homeBannerImageUrl');
}

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
    ClientTerminal? terminal,
    bool clearTerminal = false,
  }) async {
    final data = <String, dynamic>{};
    if (fullName != null) data['fullName'] = fullName;
    if (email != null) data['email'] = email;
    if (phone != null) data['phone'] = phone;
    if (clearTerminal) {
      data['terminal'] = null;
    } else if (terminal != null) {
      data['terminal'] = terminal.toJson();
    }

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
