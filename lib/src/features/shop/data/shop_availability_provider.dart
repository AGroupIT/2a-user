import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../clients/application/client_codes_controller.dart';

class MarketplaceCapabilities {
  const MarketplaceCapabilities({
    required this.catalog,
    required this.purchaseList,
    required this.orderHistory,
  });

  final bool catalog;
  final bool purchaseList;
  final bool orderHistory;

  factory MarketplaceCapabilities.fromJson(Map<String, dynamic> json) {
    return MarketplaceCapabilities(
      catalog: json['catalog'] == true,
      purchaseList: json['purchaseList'] == true,
      orderHistory: json['orderHistory'] == true,
    );
  }

  static const unavailable = MarketplaceCapabilities(
    catalog: false,
    purchaseList: false,
    orderHistory: true,
  );
}

class MarketplacePlatformAvailability {
  const MarketplacePlatformAvailability({
    required this.code,
    required this.nameRu,
    required this.nameZh,
    required this.available,
    required this.reason,
    required this.capabilities,
  });

  final String code;
  final String nameRu;
  final String? nameZh;
  final bool available;
  final String? reason;
  final MarketplaceCapabilities capabilities;

  factory MarketplacePlatformAvailability.fromJson(Map<String, dynamic> json) {
    final capabilities = json['capabilities'];
    return MarketplacePlatformAvailability(
      code: json['code']?.toString() ?? '',
      nameRu: json['nameRu']?.toString() ?? '',
      nameZh: json['nameZh']?.toString(),
      available: json['available'] == true,
      reason: json['reason']?.toString(),
      capabilities: capabilities is Map
          ? MarketplaceCapabilities.fromJson(
              Map<String, dynamic>.from(capabilities),
            )
          : MarketplaceCapabilities.unavailable,
    );
  }
}

class MarketplaceAvailability {
  const MarketplaceAvailability({
    required this.available,
    required this.reason,
    required this.platforms,
  });

  final bool available;
  final String? reason;
  final List<MarketplacePlatformAvailability> platforms;

  factory MarketplaceAvailability.fromJson(Map<String, dynamic> json) {
    final platforms = json['platforms'];
    return MarketplaceAvailability(
      available: json['available'] == true,
      reason: json['reason']?.toString(),
      platforms: platforms is List
          ? platforms
                .whereType<Map>()
                .map(
                  (item) => MarketplacePlatformAvailability.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList(growable: false)
          : const [],
    );
  }

  static const unavailable = MarketplaceAvailability(
    available: false,
    reason: 'availability_unavailable',
    platforms: [],
  );

  MarketplacePlatformAvailability? platform(String code) {
    for (final platform in platforms) {
      if (platform.code == code) return platform;
    }
    return null;
  }

  bool canBrowse(String code) {
    final selected = platform(code);
    return available &&
        selected != null &&
        selected.available &&
        selected.capabilities.catalog;
  }

  bool canUsePurchaseList(String code) {
    final selected = platform(code);
    return available &&
        selected != null &&
        selected.available &&
        selected.capabilities.purchaseList;
  }

  bool get hasBrowsablePlatform =>
      platforms.any((platform) => canBrowse(platform.code));

  List<String> get browsablePlatformCodes => platforms
      .where((platform) => canBrowse(platform.code))
      .map((platform) => platform.code)
      .toList(growable: false);
}

class ShopAvailabilityService {
  const ShopAvailabilityService(this._apiClient);

  final ApiClient _apiClient;

  Future<MarketplaceAvailability> getAvailability() async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        '/shop/availability',
      );
      final data = response.data;
      if (response.statusCode == 200 && data != null) {
        return MarketplaceAvailability.fromJson(data);
      }
    } on DioException catch (error) {
      debugPrint('Marketplace availability request failed: $error');
    } catch (error) {
      debugPrint('Marketplace availability response is invalid: $error');
    }
    return MarketplaceAvailability.unavailable;
  }
}

final shopAvailabilityServiceProvider = Provider<ShopAvailabilityService>((
  ref,
) {
  return ShopAvailabilityService(ref.watch(apiClientProvider));
});

final shopAvailabilityRefreshIntervalProvider = Provider<Duration>((ref) {
  return const Duration(seconds: 30);
});

final shopAvailabilityProvider =
    FutureProvider.autoDispose<MarketplaceAvailability>((ref) async {
      // Переключение активного клиентского кода должно обновлять доступность.
      ref.watch(activeClientCodeProvider);

      final service = ref.read(shopAvailabilityServiceProvider);
      final refreshInterval = ref.read(shopAvailabilityRefreshIntervalProvider);
      Timer? refreshTimer;
      var disposed = false;
      ref.onDispose(() {
        disposed = true;
        refreshTimer?.cancel();
      });

      // На desktop боковое меню живёт постоянно. Периодический revalidation
      // применяет изменение agent settings без повторного входа и без
      // подключения к общему realtime-emitter с большим blast radius.
      final availability = await service.getAvailability();
      if (disposed || !ref.mounted) return availability;

      refreshTimer = Timer(refreshInterval, () {
        if (ref.mounted) ref.invalidateSelf();
      });

      return availability;
    });
