import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';

class ClientPartnerPayout {
  const ClientPartnerPayout({
    required this.id,
    required this.status,
    required this.periodFrom,
    required this.periodTo,
    required this.payableAmountUsd,
    this.paidAmountUsd,
    this.paidAt,
  });

  final int id;
  final String status;
  final DateTime periodFrom;
  final DateTime periodTo;
  final double payableAmountUsd;
  final double? paidAmountUsd;
  final DateTime? paidAt;

  factory ClientPartnerPayout.fromJson(Map<String, dynamic> json) =>
      ClientPartnerPayout(
        id: json['id'] as int,
        status: json['status'] as String? ?? 'draft',
        periodFrom: DateTime.parse(json['periodFrom'] as String),
        periodTo: DateTime.parse(json['periodTo'] as String),
        payableAmountUsd:
            double.tryParse(json['payableAmountUsd']?.toString() ?? '') ?? 0,
        paidAmountUsd: double.tryParse(json['paidAmountUsd']?.toString() ?? ''),
        paidAt: json['paidAt'] == null
            ? null
            : DateTime.parse(json['paidAt'] as String),
      );
}

class ClientPartnerProgramData {
  const ClientPartnerProgramData({
    required this.active,
    required this.partnerCode,
    this.inviteUrl,
    this.shortCode,
    this.prefix,
    this.rateUsdPerKg,
    required this.registeredCount,
    required this.awaitingWeightKg,
    required this.paidWeightKg,
    required this.paidClientsCount,
    required this.conversionPercent,
    required this.availableUsd,
    required this.reservedUsd,
    required this.payableUsd,
    required this.paidUsd,
    required this.lifetimeEarnedUsd,
    required this.payouts,
  });

  final bool active;
  final String partnerCode;
  final String? inviteUrl;
  final String? shortCode;
  final String? prefix;
  final double? rateUsdPerKg;
  final int registeredCount;
  final double awaitingWeightKg;
  final double paidWeightKg;
  final int paidClientsCount;
  final double conversionPercent;
  final double availableUsd;
  final double reservedUsd;
  final double payableUsd;
  final double paidUsd;
  final double lifetimeEarnedUsd;
  final List<ClientPartnerPayout> payouts;

  factory ClientPartnerProgramData.fromJson(Map<String, dynamic> json) {
    final partner = Map<String, dynamic>.from(json['partner'] as Map);
    final invite = json['invite'] is Map
        ? Map<String, dynamic>.from(json['invite'] as Map)
        : null;
    final prefix = json['prefix'] is Map
        ? Map<String, dynamic>.from(json['prefix'] as Map)
        : null;
    final rule = json['rule'] is Map
        ? Map<String, dynamic>.from(json['rule'] as Map)
        : null;
    final stats = Map<String, dynamic>.from(json['stats'] as Map? ?? const {});
    final totals = Map<String, dynamic>.from(
      json['totals'] as Map? ?? const {},
    );
    final availableUsd =
        double.tryParse(totals['availableUsd']?.toString() ?? '') ?? 0;
    final reservedUsd =
        double.tryParse(totals['reservedUsd']?.toString() ?? '') ?? 0;

    return ClientPartnerProgramData(
      active: json['active'] == true,
      partnerCode: partner['code'] as String? ?? '',
      inviteUrl: invite?['url'] as String?,
      shortCode: invite?['shortCode'] as String?,
      prefix: prefix?['prefix'] as String?,
      rateUsdPerKg: double.tryParse(rule?['rateUsdPerKg']?.toString() ?? ''),
      registeredCount: stats['registeredCount'] as int? ?? 0,
      awaitingWeightKg:
          double.tryParse(stats['awaitingWeightKg']?.toString() ?? '') ?? 0,
      paidWeightKg:
          double.tryParse(stats['paidWeightKg']?.toString() ?? '') ?? 0,
      paidClientsCount: stats['paidClientsCount'] as int? ?? 0,
      conversionPercent:
          double.tryParse(stats['conversionPercent']?.toString() ?? '') ?? 0,
      availableUsd: availableUsd,
      reservedUsd: reservedUsd,
      payableUsd:
          double.tryParse(totals['payableUsd']?.toString() ?? '') ??
          availableUsd + reservedUsd,
      paidUsd: double.tryParse(totals['paidUsd']?.toString() ?? '') ?? 0,
      lifetimeEarnedUsd:
          double.tryParse(totals['lifetimeEarnedUsd']?.toString() ?? '') ?? 0,
      payouts: (json['settlements'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (item) =>
                ClientPartnerPayout.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(),
    );
  }
}

final clientPartnerProgramProvider =
    FutureProvider.autoDispose<ClientPartnerProgramData?>((ref) async {
      final response = await ref
          .watch(apiClientProvider)
          .get('/client/partner');
      final body = response.data;
      if (body is! Map || body['data'] is! Map) return null;

      return ClientPartnerProgramData.fromJson(
        Map<String, dynamic>.from(body['data'] as Map),
      );
    });
