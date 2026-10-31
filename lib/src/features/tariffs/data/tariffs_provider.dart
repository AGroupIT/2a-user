import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../tracks/domain/photo_report_options.dart';
import '../../../core/services/demo_mode_provider.dart';

// ============================================================
// Модели
// ============================================================

class UserWeightTier {
  final double minWeight;
  final double? maxWeight;
  final double pricePerKg;

  const UserWeightTier({
    required this.minWeight,
    this.maxWeight,
    required this.pricePerKg,
  });

  factory UserWeightTier.fromJson(Map<String, dynamic> json) {
    return UserWeightTier(
      minWeight: _parse(json['minWeight']),
      maxWeight: json['maxWeight'] != null ? _parse(json['maxWeight']) : null,
      pricePerKg: _parse(json['pricePerKg']),
    );
  }
}

class UserDensityTier {
  final double minDensity;
  final double? maxDensity;
  final double? clientPricePerKg;
  final double? clientPricePerM3;

  const UserDensityTier({
    required this.minDensity,
    this.maxDensity,
    this.clientPricePerKg,
    this.clientPricePerM3,
  });

  // Matches CalculatorDensityTier: a supplied m³ price takes precedence.
  bool get isVolumetric => clientPricePerM3 != null;
  double? get price => isVolumetric ? clientPricePerM3 : clientPricePerKg;

  factory UserDensityTier.fromJson(Map<String, dynamic> json) {
    return UserDensityTier(
      minDensity: _parse(json['minDensity']),
      maxDensity: _parseNullable(json['maxDensity']),
      clientPricePerKg: _parseNullable(json['clientPricePerKg']),
      clientPricePerM3: _parseNullable(json['clientPricePerM3']),
    );
  }
}

class UserDeliveryTariff {
  final int id;
  final String name;
  final double baseCost;
  final String? allowedItems;
  final String? prohibitedItems;
  final List<UserWeightTier> weightTiers;
  final String pricingType;
  final List<UserDensityTier> densityTiers;
  final bool isActive;
  final bool isCurrentlyActive;
  final DateTime? validFrom;
  final DateTime? validTo;
  final bool requiresProductInfo;

  const UserDeliveryTariff({
    required this.id,
    required this.name,
    required this.baseCost,
    this.allowedItems,
    this.prohibitedItems,
    this.weightTiers = const [],
    this.pricingType = 'weight',
    this.densityTiers = const [],
    this.isActive = true,
    this.isCurrentlyActive = true,
    this.validFrom,
    this.validTo,
    this.requiresProductInfo = false,
  });

  bool get isDensityBased => pricingType == 'density';

  double? get minimumDensityPricePerKg => _densityMinimum(volumetric: false);
  double? get minimumDensityPricePerM3 => _densityMinimum(volumetric: true);

  double? _densityMinimum({required bool volumetric}) {
    double? minimum;
    for (final tier in densityTiers) {
      final price = tier.price;
      if (tier.isVolumetric != volumetric || price == null) continue;
      if (minimum == null || price < minimum) minimum = price;
    }
    return minimum;
  }

  factory UserDeliveryTariff.fromJson(Map<String, dynamic> json) {
    return UserDeliveryTariff(
      id: _parseInt(json['id']),
      name: json['name'] as String? ?? '',
      baseCost: _parse(json['baseCost']),
      allowedItems: json['allowedItems'] as String?,
      prohibitedItems: json['prohibitedItems'] as String?,
      weightTiers:
          (json['weightTiers'] as List<dynamic>?)
              ?.map((e) => UserWeightTier.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      pricingType: json['pricingType'] as String? ?? 'weight',
      densityTiers:
          (json['densityTiers'] as List<dynamic>?)
              ?.map((e) => UserDensityTier.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      isActive: json['isActive'] as bool? ?? true,
      isCurrentlyActive:
          json['isCurrentlyActive'] as bool? ??
          json['isActive'] as bool? ??
          true,
      validFrom: _parseDate(json['validFrom']),
      validTo: _parseDate(json['validTo']),
      requiresProductInfo: json['requiresProductInfo'] as bool? ?? false,
    );
  }
}

class UserPackagingType {
  final int id;
  final String name;
  final double baseCost;

  const UserPackagingType({
    required this.id,
    required this.name,
    required this.baseCost,
  });

  factory UserPackagingType.fromJson(Map<String, dynamic> json) {
    return UserPackagingType(
      id: _parseInt(json['id']),
      name: json['nameRu'] as String? ?? json['name'] as String? ?? '',
      baseCost: _parse(json['baseCost']),
    );
  }
}

class UserTariffsData {
  final List<UserDeliveryTariff> deliveryTariffs;
  final List<UserPackagingType> packagingTypes;
  final PhotoReportOptions? photoReportOptions;

  const UserTariffsData({
    this.deliveryTariffs = const [],
    this.packagingTypes = const [],
    this.photoReportOptions,
  });
}

// ============================================================
// Провайдер
// ============================================================

final userTariffsProvider = FutureProvider<UserTariffsData>((ref) async {
  if (ref.watch(demoModeProvider)) {
    return const UserTariffsData();
  }
  final api = ref.read(apiClientProvider);

  try {
    final results = await Future.wait([
      api.get('/tariffs'),
      api.get('/packagings'),
      api.get('/client/photo-report-options'),
    ]);

    List<dynamic> extract(dynamic data, List<String> keys) {
      if (data is Map<String, dynamic>) {
        for (final key in keys) {
          if (data[key] is List) return data[key] as List<dynamic>;
        }
      }
      if (data is List) return data;
      return [];
    }

    final tariffsJson = extract(results[0].data, ['tariffs', 'data']);
    final packagingsJson = extract(results[1].data, ['packagings', 'data']);
    final optionsJson = Map<String, dynamic>.from(
      results[2].data['data'] as Map,
    );

    return UserTariffsData(
      deliveryTariffs: tariffsJson
          .map((e) => UserDeliveryTariff.fromJson(e as Map<String, dynamic>))
          .where((t) => t.isActive)
          .toList(),
      packagingTypes: packagingsJson
          .map((e) => UserPackagingType.fromJson(e as Map<String, dynamic>))
          .toList(),
      photoReportOptions: PhotoReportOptions.fromJson(optionsJson),
    );
  } on DioException catch (e) {
    debugPrint('Error loading tariffs: $e');
    rethrow;
  }
});

final publicDefaultTariffsProvider = FutureProvider<List<UserDeliveryTariff>>((
  ref,
) async {
  final api = ref.read(apiClientProvider);
  final response = await api.get(
    '/public/tariffs',
    queryParameters: const {'agentId': 1, 'take': 6},
  );

  final data = response.data;
  final List<dynamic> list = data is Map<String, dynamic>
      ? (data['tariffs'] as List<dynamic>? ??
            data['data'] as List<dynamic>? ??
            const <dynamic>[])
      : data is List
      ? data
      : const <dynamic>[];

  return list
      .map((e) => UserDeliveryTariff.fromJson(e as Map<String, dynamic>))
      .where((t) => t.isActive)
      .toList();
});

// ============================================================
// Helpers
// ============================================================

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String && value.trim().isNotEmpty) {
    return DateTime.tryParse(value);
  }
  return null;
}

double _parse(dynamic v) {
  if (v == null) return 0.0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0.0;
}

double? _parseNullable(dynamic value) {
  if (value == null) return null;
  final parsed = value is num
      ? value.toDouble()
      : double.tryParse(value.toString());
  return parsed != null && parsed.isFinite ? parsed : null;
}

int _parseInt(dynamic v) {
  if (v == null) return 0;
  if (v is int) return v;
  return int.tryParse(v.toString()) ?? 0;
}
