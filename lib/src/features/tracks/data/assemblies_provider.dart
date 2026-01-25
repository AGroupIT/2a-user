import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';

/// Модель сборки
class Assembly {
  final int id;
  final String number;
  final String? name;
  final String status;
  final String statusName;
  final String? statusColor;
  final String? clientCode;
  final String? clientName;
  final bool hasInsurance;
  final double? insuranceAmount;
  final String? tariffName;
  final double tariffCost;
  final List<String> packagingNames;
  final double packagingCost; // Сумма стоимости упаковок
  final int trackCount;
  final List<AssemblyTrack> tracks;
  final String? scalePhotoUrl;
  final String? comment;
  final String? deliveryMethod; // Способ доставки: self_pickup или transport_company
  final String? recipientName; // Имя получателя (для ТК)
  final String? recipientPhone; // Телефон получателя (для ТК)
  final String? recipientCity; // Город получателя (для ТК)
  final String? transportCompanyName; // Название транспортной компании
  final DateTime createdAt;
  final DateTime updatedAt;

  const Assembly({
    required this.id,
    required this.number,
    this.name,
    required this.status,
    required this.statusName,
    this.statusColor,
    this.clientCode,
    this.clientName,
    this.hasInsurance = false,
    this.insuranceAmount,
    this.tariffName,
    this.tariffCost = 0,
    this.packagingNames = const [],
    this.packagingCost = 0,
    this.trackCount = 0,
    this.tracks = const [],
    this.scalePhotoUrl,
    this.comment,
    this.deliveryMethod,
    this.recipientName,
    this.recipientPhone,
    this.recipientCity,
    this.transportCompanyName,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Assembly.fromJson(Map<String, dynamic> json) {
    // Парсим треки
    final tracksList = json['tracks'] as List<dynamic>? ?? [];
    final tracks = tracksList
        .map((t) => AssemblyTrack.fromJson(t as Map<String, dynamic>))
        .toList();

    // Парсим имена упаковки
    final packagingNames =
        (json['packagingNames'] as List<dynamic>?)
            ?.map((p) => p.toString())
            .toList() ??
        [];

    return Assembly(
      id: int.parse(json['id'].toString()),
      number: json['number'] as String? ?? '',
      name: json['name'] as String?,
      status: json['status'] as String? ?? '',
      statusName:
          json['statusName'] as String? ?? json['status'] as String? ?? '',
      statusColor: json['statusColor'] as String?,
      clientCode: json['clientCode'] as String?,
      clientName: json['clientName'] as String?,
      hasInsurance: json['hasInsurance'] as bool? ?? false,
      insuranceAmount: json['insuranceAmount'] != null
          ? double.tryParse(json['insuranceAmount'].toString())
          : null,
      tariffName: json['tariffName'] as String?,
      tariffCost: json['tariffCost'] != null
          ? double.tryParse(json['tariffCost'].toString()) ?? 0
          : 0,
      packagingNames: packagingNames,
      packagingCost: json['packagingCost'] != null
          ? double.tryParse(json['packagingCost'].toString()) ?? 0
          : 0,
      trackCount: json['trackCount'] as int? ?? tracks.length,
      tracks: tracks,
      scalePhotoUrl: json['scalePhotoUrl'] as String?,
      comment: json['comment'] as String?,
      deliveryMethod: json['deliveryMethod'] as String?,
      recipientName: json['recipientName'] as String?,
      recipientPhone: json['recipientPhone'] as String?,
      recipientCity: json['recipientCity'] as String?,
      transportCompanyName: json['transportCompanyName'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

/// Модель трека в сборке
class AssemblyTrack {
  final int id;
  final String trackNumber;
  final String? productName;
  final int quantity;
  final String? imageUrl;

  const AssemblyTrack({
    required this.id,
    required this.trackNumber,
    this.productName,
    this.quantity = 1,
    this.imageUrl,
  });

  factory AssemblyTrack.fromJson(Map<String, dynamic> json) {
    return AssemblyTrack(
      id: int.parse(json['id'].toString()),
      trackNumber: json['trackNumber'] as String? ?? '',
      productName: json['productName'] as String?,
      quantity: json['quantity'] as int? ?? 1,
      imageUrl: json['imageUrl'] as String?,
    );
  }
}

/// Провайдер для получения списка сборок по коду клиента
final assembliesListProvider = FutureProvider.family<List<Assembly>, String>((
  ref,
  clientCode,
) async {
  final apiClient = ref.read(apiClientProvider);

  try {
    final response = await apiClient.get(
      '/assemblies',
      queryParameters: {'clientCode': clientCode, 'take': 100},
    );

    if (response.statusCode == 200 && response.data != null) {
      final data = response.data as Map<String, dynamic>;
      final assembliesJson = data['assemblies'] as List<dynamic>? ?? [];

      return assembliesJson
          .map((json) => Assembly.fromJson(json as Map<String, dynamic>))
          .toList();
    }
    return [];
  } on DioException catch (e) {
    debugPrint('Error loading assemblies: $e');
    return [];
  }
});

/// Провайдер для дайджеста сборок - последние 5 сборок
final assembliesDigestProvider = FutureProvider.family<List<Assembly>, String>((
  ref,
  clientCode,
) async {
  final apiClient = ref.read(apiClientProvider);

  try {
    final response = await apiClient.get(
      '/assemblies',
      queryParameters: {'clientCode': clientCode, 'take': 5},
    );

    if (response.statusCode == 200 && response.data != null) {
      final data = response.data as Map<String, dynamic>;
      final assembliesJson = data['assemblies'] as List<dynamic>? ?? [];

      return assembliesJson
          .map((json) => Assembly.fromJson(json as Map<String, dynamic>))
          .toList();
    }
    return [];
  } on DioException catch (e) {
    debugPrint('Error loading assemblies digest: $e');
    return [];
  }
});

/// Провайдер для общего количества сборок
final assembliesCountProvider = FutureProvider.family<int, String>((
  ref,
  clientCode,
) async {
  final apiClient = ref.read(apiClientProvider);

  try {
    final response = await apiClient.get(
      '/assemblies',
      queryParameters: {'clientCode': clientCode, 'take': 1},
    );

    if (response.statusCode == 200 && response.data != null) {
      final data = response.data as Map<String, dynamic>;
      final pagination = data['pagination'] as Map<String, dynamic>?;
      return pagination?['total'] as int? ?? 0;
    }
    return 0;
  } on DioException catch (e) {
    debugPrint('Error loading assemblies count: $e');
    return 0;
  }
});

// ==================== API Mutations ====================

/// Сервис для API операций со сборками
class AssembliesApiService {
  final Ref _ref;

  AssembliesApiService(this._ref);

  ApiClient get _apiClient => _ref.read(apiClientProvider);

  /// Создать сборку (статус = new)
  Future<Assembly?> createAssembly({
    required int clientId,
    String? name,
    int? tariffId,
    List<int>? packagingTypeIds,
    bool hasInsurance = false,
    double? insuranceAmount,
    List<int>? trackIds,
  }) async {
    try {
      final response = await _apiClient.post(
        '/assemblies',
        data: {
          'clientId': clientId,
          if (name != null) 'name': name,
          if (tariffId != null) 'tariffId': tariffId,
          if (packagingTypeIds != null && packagingTypeIds.isNotEmpty)
            'packagingTypeIds': packagingTypeIds,
          'hasInsurance': hasInsurance,
          if (insuranceAmount != null) 'insuranceAmount': insuranceAmount,
          if (trackIds != null && trackIds.isNotEmpty) 'trackIds': trackIds,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data as Map<String, dynamic>;
        return Assembly.fromJson(data);
      }
      return null;
    } on DioException catch (e) {
      debugPrint('Error creating assembly: $e');
      return null;
    }
  }

  /// Добавить треки в сборку
  Future<bool> addTracksToAssembly({
    required int assemblyId,
    required List<int> trackIds,
  }) async {
    try {
      final response = await _apiClient.post(
        '/assemblies/$assemblyId/tracks',
        data: {'trackIds': trackIds},
      );
      return response.statusCode == 200;
    } on DioException catch (e) {
      debugPrint('Error adding tracks to assembly: $e');
      return false;
    }
  }

  /// Удалить треки из сборки
  Future<bool> removeTracksFromAssembly({
    required int assemblyId,
    required List<int> trackIds,
  }) async {
    try {
      final response = await _apiClient.delete(
        '/assemblies/$assemblyId/tracks',
        data: {'trackIds': trackIds},
      );
      return response.statusCode == 200;
    } on DioException catch (e) {
      debugPrint('Error removing tracks from assembly: $e');
      return false;
    }
  }

  /// Добавить комментарий к сборке
  Future<bool> addAssemblyComment({
    required int assemblyId,
    required String comment,
  }) async {
    try {
      final response = await _apiClient.patch(
        '/assemblies/$assemblyId',
        data: {'comment': comment},
      );
      return response.statusCode == 200;
    } on DioException catch (e) {
      debugPrint('Error adding assembly comment: $e');
      return false;
    }
  }

  /// Обновить страховку сборки
  Future<bool> updateAssemblyInsurance({
    required int assemblyId,
    required bool hasInsurance,
    double? insuranceAmount,
  }) async {
    try {
      final response = await _apiClient.patch(
        '/assemblies/$assemblyId',
        data: {
          'hasInsurance': hasInsurance,
          if (insuranceAmount != null) 'insuranceAmount': insuranceAmount,
        },
      );
      return response.statusCode == 200;
    } on DioException catch (e) {
      debugPrint('Error updating assembly insurance: $e');
      return false;
    }
  }

  /// Обновить способ доставки сборки
  Future<bool> updateAssemblyDelivery({
    required int assemblyId,
    required String deliveryMethod,
    String? recipientName,
    String? recipientPhone,
    String? recipientCity,
    String? transportCompanyName,
  }) async {
    try {
      final response = await _apiClient.patch(
        '/assemblies/$assemblyId',
        data: {
          'deliveryMethod': deliveryMethod,
          if (recipientName != null) 'recipientName': recipientName,
          if (recipientPhone != null) 'recipientPhone': recipientPhone,
          if (recipientCity != null) 'recipientCity': recipientCity,
          if (transportCompanyName != null) 'transportCompanyName': transportCompanyName,
        },
      );
      return response.statusCode == 200;
    } on DioException catch (e) {
      debugPrint('Error updating assembly delivery: $e');
      return false;
    }
  }
}

/// Провайдер для API сервиса сборок
final assembliesApiServiceProvider = Provider<AssembliesApiService>((ref) {
  return AssembliesApiService(ref);
});

/// Модель типа упаковки

/// Модель типа упаковки
class PackagingType {
  final int id;
  final String name;
  final String? nameRu;
  final double baseCost;

  const PackagingType({
    required this.id,
    required this.name,
    this.nameRu,
    this.baseCost = 0,
  });

  factory PackagingType.fromJson(Map<String, dynamic> json) {
    return PackagingType(
      id: int.tryParse(json['id'].toString()) ?? 0,
      name: json['name'] as String? ?? json['nameRu'] as String? ?? '',
      nameRu: json['nameRu'] as String?,
      baseCost: json['baseCost'] != null
          ? double.tryParse(json['baseCost'].toString()) ?? 0
          : 0,
    );
  }
}

/// Провайдер для тарифов (с поддержкой clientId)
final tariffsProvider = FutureProvider<List<Tariff>>((ref) async {
  final apiClient = ref.read(apiClientProvider);

  try {
    final response = await apiClient.get('/tariffs');

    if (response.statusCode == 200 && response.data != null) {
      final data = response.data as Map<String, dynamic>;
      final tariffList = data['tariffs'] as List<dynamic>? ?? data['data'] as List<dynamic>? ?? [];

      return tariffList
          .map((json) => Tariff.fromJson(json as Map<String, dynamic>))
          .toList();
    }
    return [];
  } on DioException catch (e) {
    debugPrint('Error loading tariffs: $e');
    return [];
  }
});

/// Провайдер для типов упаковки
final packagingTypesProvider = FutureProvider<List<PackagingType>>((ref) async {
  final apiClient = ref.read(apiClientProvider);

  try {
    final response = await apiClient.get('/packagings');

    if (response.statusCode == 200 && response.data != null) {
      final data = response.data as Map<String, dynamic>;
      final packagingList = data['packagings'] as List<dynamic>? ?? data['data'] as List<dynamic>? ?? [];

      return packagingList
          .map((json) => PackagingType.fromJson(json as Map<String, dynamic>))
          .toList();
    }
    return [];
  } on DioException catch (e) {
    debugPrint('Error loading packaging types: $e');
    return [];
  }
});

/// Модель тарифа
class Tariff {
  final int id;
  final String name;
  final double baseCost;

  const Tariff({required this.id, required this.name, required this.baseCost});

  factory Tariff.fromJson(Map<String, dynamic> json) {
    return Tariff(
      id: int.tryParse(json['id'].toString()) ?? 0,
      name: json['name'] as String? ?? '',
      baseCost: json['baseCost'] != null
          ? double.tryParse(json['baseCost'].toString()) ?? 0
          : 0,
    );
  }
}
