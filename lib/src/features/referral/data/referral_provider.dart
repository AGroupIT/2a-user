import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/cache/stale_data_cache.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/demo_mode_provider.dart';
import '../../auth/data/auth_provider.dart';

// ============================================================
// Модели
// ============================================================

class ReferralEntry {
  final int id;
  final String? fullName;
  final int paidInvoicesCount;
  final double earnedKg;
  final DateTime? joinedAt;

  const ReferralEntry({
    required this.id,
    this.fullName,
    required this.paidInvoicesCount,
    required this.earnedKg,
    this.joinedAt,
  });

  factory ReferralEntry.fromJson(Map<String, dynamic> json) {
    return ReferralEntry(
      id: json['id'] as int? ?? 0,
      fullName: json['fullName'] as String?,
      paidInvoicesCount: json['paidInvoicesCount'] as int? ?? 0,
      earnedKg: (json['earnedKg'] as num?)?.toDouble() ?? 0.0,
      joinedAt: json['joinedAt'] != null
          ? DateTime.tryParse(json['joinedAt'] as String)
          : null,
    );
  }
}

class ReferralTransaction {
  final int id;
  final String type;
  final double kgAmount;
  final String? description;
  final DateTime createdAt;
  final DateTime? expiresAt;

  const ReferralTransaction({
    required this.id,
    required this.type,
    required this.kgAmount,
    this.description,
    required this.createdAt,
    this.expiresAt,
  });

  factory ReferralTransaction.fromJson(Map<String, dynamic> json) {
    return ReferralTransaction(
      id: json['id'] as int? ?? 0,
      type: json['type'] as String? ?? '',
      kgAmount: (json['kgAmount'] as num?)?.toDouble() ?? 0.0,
      description: json['description'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      expiresAt: json['expiresAt'] != null
          ? DateTime.tryParse(json['expiresAt'] as String)
          : null,
    );
  }
}

class ReferralData {
  final String? referralCode;
  final double referralKgBalance;
  final double maxBonusPercent; // % веса счёта — лимит на один счёт
  final String? referredByName;
  final String? referredByCode;
  final List<ReferralEntry> referrals;
  final List<ReferralTransaction> transactions;

  const ReferralData({
    this.referralCode,
    required this.referralKgBalance,
    this.maxBonusPercent = 15.0,
    this.referredByName,
    this.referredByCode,
    required this.referrals,
    required this.transactions,
  });

  factory ReferralData.fromJson(Map<String, dynamic> json) {
    final settings = json['settings'] as Map<String, dynamic>?;
    return ReferralData(
      referralCode: json['referralCode'] as String?,
      referralKgBalance: (json['referralKgBalance'] as num?)?.toDouble() ?? 0.0,
      maxBonusPercent:
          (settings?['maxBonusPercent'] as num?)?.toDouble() ?? 15.0,
      referredByName: json['referredBy'] != null
          ? (json['referredBy'] as Map<String, dynamic>)['fullName'] as String?
          : null,
      referredByCode: json['referredBy'] != null
          ? (json['referredBy'] as Map<String, dynamic>)['referralCode']
                as String?
          : null,
      referrals: (json['referrals'] as List<dynamic>? ?? [])
          .map((e) => ReferralEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      transactions: (json['transactions'] as List<dynamic>? ?? [])
          .map((e) => ReferralTransaction.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

// ============================================================
// Провайдер
// ============================================================

final referralProvider = FutureProvider<ReferralData>((ref) async {
  if (ref.watch(demoModeProvider)) {
    return const ReferralData(
      referralKgBalance: 0,
      referrals: [],
      transactions: [],
    );
  }
  final api = ref.read(apiClientProvider);
  final clientId = ref.watch(authProvider).clientId?.toString() ?? 'unknown';
  final responseData = await StaleDataCache.getJson(
    ref: ref,
    cacheKey: StaleDataCache.buildKey('referral', {'clientId': clientId}),
    label: 'бонусные кг',
    request: () => api.get('/client/referral'),
  );
  final data = responseData['data'] as Map<String, dynamic>;
  return ReferralData.fromJson(data);
});
