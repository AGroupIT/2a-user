import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../domain/marketplace.dart';
import '../domain/shop_category.dart';
import '../domain/shop_item.dart';
import '../domain/shop_item_detail.dart';

/// Параметры поиска товаров
class ShopSearchParams {
  final String query;
  final Marketplace marketplace;
  final int page;
  final int pageSize;
  final String? categoryId;
  final String orderBy;
  final double? minPrice;
  final double? maxPrice;

  const ShopSearchParams({
    required this.query,
    this.marketplace = Marketplace.poizon,
    this.page = 0,
    this.pageSize = 20,
    this.categoryId,
    this.orderBy = 'Default',
    this.minPrice,
    this.maxPrice,
  });

  ShopSearchParams copyWith({
    String? query,
    Marketplace? marketplace,
    int? page,
    int? pageSize,
    String? categoryId,
    String? orderBy,
    double? minPrice,
    double? maxPrice,
  }) {
    return ShopSearchParams(
      query: query ?? this.query,
      marketplace: marketplace ?? this.marketplace,
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
      categoryId: categoryId ?? this.categoryId,
      orderBy: orderBy ?? this.orderBy,
      minPrice: minPrice ?? this.minPrice,
      maxPrice: maxPrice ?? this.maxPrice,
    );
  }

  /// Copy resetting nullable fields
  ShopSearchParams copyWithReset({
    String? query,
    Marketplace? marketplace,
    int? page,
    int? pageSize,
    String? categoryId,
    String? orderBy,
    bool resetMinPrice = false,
    bool resetMaxPrice = false,
  }) {
    return ShopSearchParams(
      query: query ?? this.query,
      marketplace: marketplace ?? this.marketplace,
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
      categoryId: categoryId ?? this.categoryId,
      orderBy: orderBy ?? this.orderBy,
      minPrice: resetMinPrice ? null : this.minPrice,
      maxPrice: resetMaxPrice ? null : this.maxPrice,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ShopSearchParams &&
          query == other.query &&
          marketplace == other.marketplace &&
          page == other.page &&
          pageSize == other.pageSize &&
          categoryId == other.categoryId &&
          orderBy == other.orderBy &&
          minPrice == other.minPrice &&
          maxPrice == other.maxPrice;

  @override
  int get hashCode => Object.hash(query, marketplace, page, pageSize, categoryId, orderBy, minPrice, maxPrice);
}

/// Результат поиска
class ShopSearchResult {
  final List<ShopItem> items;
  final int total;
  final int page;
  final int pageSize;

  const ShopSearchResult({
    this.items = const [],
    this.total = 0,
    this.page = 0,
    this.pageSize = 20,
  });
}

/// Выбранная площадка
final selectedMarketplaceProvider =
    NotifierProvider<SelectedMarketplaceNotifier, Marketplace>(
  SelectedMarketplaceNotifier.new,
);

class SelectedMarketplaceNotifier extends Notifier<Marketplace> {
  @override
  Marketplace build() => Marketplace.poizon;

  void select(Marketplace marketplace) {
    state = marketplace;
  }
}

/// Поиск товаров
final shopSearchProvider = FutureProvider.family<ShopSearchResult, ShopSearchParams>((ref, params) async {
  final apiClient = ref.read(apiClientProvider);

  try {
    final queryParameters = <String, dynamic>{
      'q': params.query,
      'provider': params.marketplace.apiKey,
      'page': params.page,
      'pageSize': params.pageSize,
      'orderBy': params.orderBy,
    };
    if (params.categoryId != null && params.categoryId!.isNotEmpty) {
      queryParameters['categoryId'] = params.categoryId;
    }
    if (params.minPrice != null) {
      queryParameters['minPrice'] = params.minPrice;
    }
    if (params.maxPrice != null) {
      queryParameters['maxPrice'] = params.maxPrice;
    }

    final response = await apiClient.get(
      '/shop/search',
      queryParameters: queryParameters,
    );

    if (response.statusCode == 200 && response.data != null) {
      final data = response.data as Map<String, dynamic>;
      final itemsJson = data['items'] as List<dynamic>? ?? [];

      return ShopSearchResult(
        items: itemsJson
            .map((json) => ShopItem.fromJson(json as Map<String, dynamic>))
            .toList(),
        total: data['total'] as int? ?? 0,
        page: data['page'] as int? ?? 0,
        pageSize: data['pageSize'] as int? ?? 20,
      );
    }
    return const ShopSearchResult();
  } on DioException catch (e) {
    debugPrint('Error searching shop items: $e');
    return const ShopSearchResult();
  }
});

/// Детали товара
final shopItemDetailProvider = FutureProvider.family<ShopItemDetail?, String>((ref, itemId) async {
  final apiClient = ref.read(apiClientProvider);

  try {
    final response = await apiClient.get('/shop/item/$itemId');

    if (response.statusCode == 200 && response.data != null) {
      final data = response.data as Map<String, dynamic>;
      final itemJson = data['item'] as Map<String, dynamic>?;
      if (itemJson != null) {
        return ShopItemDetail.fromJson(itemJson);
      }
    }
    return null;
  } on DioException catch (e) {
    debugPrint('Error loading shop item detail: $e');
    return null;
  }
});

/// Параметры запроса категорий
class ShopCategoryParams {
  final Marketplace marketplace;
  final String? parentId;

  const ShopCategoryParams({
    required this.marketplace,
    this.parentId,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ShopCategoryParams &&
          marketplace == other.marketplace &&
          parentId == other.parentId;

  @override
  int get hashCode => Object.hash(marketplace, parentId);
}

/// Категории
final shopCategoriesProvider = FutureProvider.family<List<ShopCategory>, ShopCategoryParams>((ref, params) async {
  final apiClient = ref.read(apiClientProvider);

  try {
    final queryParameters = <String, dynamic>{
      'provider': params.marketplace.apiKey,
    };
    if (params.parentId != null && params.parentId!.isNotEmpty) {
      queryParameters['parentId'] = params.parentId;
    }

    final response = await apiClient.get(
      '/shop/categories',
      queryParameters: queryParameters,
    );

    if (response.statusCode == 200 && response.data != null) {
      final data = response.data as Map<String, dynamic>;
      final categoriesJson = data['categories'] as List<dynamic>? ?? [];

      return categoriesJson
          .map((json) => ShopCategory.fromJson(json as Map<String, dynamic>))
          .toList();
    }
    return [];
  } on DioException catch (e) {
    debugPrint('Error loading shop categories: $e');
    return [];
  }
});
