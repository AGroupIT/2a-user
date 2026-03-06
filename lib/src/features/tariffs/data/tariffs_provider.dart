import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';

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

class UserDeliveryTariff {
  final int id;
  final String name;
  final double baseCost;
  final String? allowedItems;
  final String? prohibitedItems;
  final List<UserWeightTier> weightTiers;
  final bool isActive;
  final bool requiresProductInfo;

  const UserDeliveryTariff({
    required this.id,
    required this.name,
    required this.baseCost,
    this.allowedItems,
    this.prohibitedItems,
    this.weightTiers = const [],
    this.isActive = true,
    this.requiresProductInfo = false,
  });

  factory UserDeliveryTariff.fromJson(Map<String, dynamic> json) {
    return UserDeliveryTariff(
      id: _parseInt(json['id']),
      name: json['name'] as String? ?? '',
      baseCost: _parse(json['baseCost']),
      allowedItems: json['allowedItems'] as String?,
      prohibitedItems: json['prohibitedItems'] as String?,
      weightTiers: (json['weightTiers'] as List<dynamic>?)
              ?.map((e) => UserWeightTier.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      isActive: json['isActive'] as bool? ?? true,
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

class UserPhotoCoefficient {
  final double minPercent;
  final double? maxPercent;
  final double coefficient;

  const UserPhotoCoefficient({
    required this.minPercent,
    this.maxPercent,
    required this.coefficient,
  });

  String get rangeLabel {
    if (minPercent == 0 && (maxPercent == null || maxPercent == 0)) {
      return 'Без фотоотчёта';
    }
    if (maxPercent == null) {
      return 'от ${minPercent.toStringAsFixed(0)}%';
    }
    return '${minPercent.toStringAsFixed(0)}–${maxPercent!.toStringAsFixed(0)}%';
  }

  factory UserPhotoCoefficient.fromJson(Map<String, dynamic> json) {
    return UserPhotoCoefficient(
      minPercent: _parse(json['minPercent']),
      maxPercent: json['maxPercent'] != null ? _parse(json['maxPercent']) : null,
      coefficient: _parse(json['coefficient']),
    );
  }
}

class UserTariffsData {
  final List<UserDeliveryTariff> deliveryTariffs;
  final List<UserPackagingType> packagingTypes;
  final List<UserPhotoCoefficient> photoCoefficients;

  const UserTariffsData({
    this.deliveryTariffs = const [],
    this.packagingTypes = const [],
    this.photoCoefficients = const [],
  });
}

// ============================================================
// Провайдер
// ============================================================

final userTariffsProvider = FutureProvider<UserTariffsData>((ref) async {
  final api = ref.read(apiClientProvider);

  try {
    final results = await Future.wait([
      api.get('/tariffs'),
      api.get('/packagings'),
      api.get('/photo-report-coefficients'),
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
    final coefficientsJson =
        extract(results[2].data, ['coefficients', 'data']);

    return UserTariffsData(
      deliveryTariffs: tariffsJson
          .map((e) => UserDeliveryTariff.fromJson(e as Map<String, dynamic>))
          .where((t) => t.isActive)
          .toList(),
      packagingTypes: packagingsJson
          .map((e) => UserPackagingType.fromJson(e as Map<String, dynamic>))
          .toList(),
      photoCoefficients: coefficientsJson
          .map((e) => UserPhotoCoefficient.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  } on DioException catch (e) {
    debugPrint('Error loading tariffs: $e');
    rethrow;
  }
});

// ============================================================
// Helpers
// ============================================================

double _parse(dynamic v) {
  if (v == null) return 0.0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0.0;
}

int _parseInt(dynamic v) {
  if (v == null) return 0;
  if (v is int) return v;
  return int.tryParse(v.toString()) ?? 0;
}
