import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/china_marketplace_models.dart';
import 'china_marketplace_repository.dart';

class ChinaMarketplacesState {
  final ChinaMarketplace marketplace;
  final String query;
  final bool isSearching;
  final List<MarketplaceProduct> products;
  final List<MarketplaceCartItem> cart;
  final String? selectedCategory;
  final MarketplaceCatalogFilter filter;
  final MarketplaceSortOption sort;
  final bool isImageSearchMode;
  final String? imageSearchFileName;
  final Uint8List? imageSearchPreviewBytes;
  final double markupPercent;
  final double yuanRateRub;

  const ChinaMarketplacesState({
    this.marketplace = ChinaMarketplace.alibaba1688,
    this.query = '',
    this.isSearching = false,
    this.products = const [],
    this.cart = const [],
    this.selectedCategory,
    this.filter = MarketplaceCatalogFilter.all,
    this.sort = MarketplaceSortOption.popular,
    this.isImageSearchMode = false,
    this.imageSearchFileName,
    this.imageSearchPreviewBytes,
    this.markupPercent = 12,
    this.yuanRateRub = 12.8,
  });

  int get cartQuantity => cart.fold<int>(0, (sum, item) => sum + item.quantity);

  double get cartBaseCny =>
      cart.fold<double>(0, (sum, item) => sum + item.totalCny);

  /// Клиенту показываем только итоговую клиентскую стоимость без раскрытия
  /// внутренней наценки. Позже это значение должен возвращать backend.
  double get cartClientCny => cartBaseCny * (1 + markupPercent / 100);

  double get cartClientRub => cartClientCny * yuanRateRub;

  ChinaMarketplacesState copyWith({
    ChinaMarketplace? marketplace,
    String? query,
    bool? isSearching,
    List<MarketplaceProduct>? products,
    List<MarketplaceCartItem>? cart,
    String? selectedCategory,
    bool resetCategory = false,
    MarketplaceCatalogFilter? filter,
    MarketplaceSortOption? sort,
    bool? isImageSearchMode,
    String? imageSearchFileName,
    Uint8List? imageSearchPreviewBytes,
    bool resetImageSearch = false,
    double? markupPercent,
    double? yuanRateRub,
  }) {
    return ChinaMarketplacesState(
      marketplace: marketplace ?? this.marketplace,
      query: query ?? this.query,
      isSearching: isSearching ?? this.isSearching,
      products: products ?? this.products,
      cart: cart ?? this.cart,
      selectedCategory: resetCategory
          ? null
          : selectedCategory ?? this.selectedCategory,
      filter: filter ?? this.filter,
      sort: sort ?? this.sort,
      isImageSearchMode: resetImageSearch
          ? false
          : isImageSearchMode ?? this.isImageSearchMode,
      imageSearchFileName: resetImageSearch
          ? null
          : imageSearchFileName ?? this.imageSearchFileName,
      imageSearchPreviewBytes: resetImageSearch
          ? null
          : imageSearchPreviewBytes ?? this.imageSearchPreviewBytes,
      markupPercent: markupPercent ?? this.markupPercent,
      yuanRateRub: yuanRateRub ?? this.yuanRateRub,
    );
  }
}

final chinaMarketplaceRepositoryProvider = Provider<ChinaMarketplaceRepository>(
  (_) => ChinaMarketplaceRepository(),
);

final chinaMarketplaceCategoriesProvider =
    Provider.family<List<String>, ChinaMarketplace>((ref, marketplace) {
      return ref
          .read(chinaMarketplaceRepositoryProvider)
          .categoriesFor(marketplace);
    });

final chinaMarketplacesControllerProvider =
    NotifierProvider<ChinaMarketplacesController, ChinaMarketplacesState>(
      ChinaMarketplacesController.new,
    );

final chinaMarketplaceProductProvider =
    FutureProvider.family<MarketplaceProduct?, String>((ref, productId) {
      return ref.read(chinaMarketplaceRepositoryProvider).getById(productId);
    });

class ChinaMarketplacesController extends Notifier<ChinaMarketplacesState> {
  ChinaMarketplaceRepository get _repository =>
      ref.read(chinaMarketplaceRepositoryProvider);

  @override
  ChinaMarketplacesState build() {
    Future.microtask(() => search(''));
    return const ChinaMarketplacesState();
  }

  Future<void> selectMarketplace(ChinaMarketplace marketplace) async {
    if (state.marketplace == marketplace) return;
    final imageFileName = state.imageSearchFileName;
    final imagePreviewBytes = state.imageSearchPreviewBytes;
    final shouldKeepImageSearch =
        state.isImageSearchMode &&
        imageFileName != null &&
        imagePreviewBytes != null;
    state = state.copyWith(
      marketplace: marketplace,
      query: '',
      products: [],
      resetCategory: true,
      filter: MarketplaceCatalogFilter.all,
      sort: MarketplaceSortOption.popular,
      isSearching: true,
    );
    if (shouldKeepImageSearch) {
      await _runImageSearch(imageFileName, imagePreviewBytes);
    } else {
      await search('');
    }
  }

  Future<void> selectCategory(String? category) async {
    final normalized = category?.trim().isEmpty == true ? null : category;
    if (state.selectedCategory == normalized) return;
    state = normalized == null
        ? state.copyWith(resetCategory: true, isSearching: true)
        : state.copyWith(selectedCategory: normalized, isSearching: true);
    await _refreshCurrentSearch();
  }

  Future<void> selectFilter(MarketplaceCatalogFilter filter) async {
    if (state.filter == filter) return;
    state = state.copyWith(filter: filter, isSearching: true);
    await _refreshCurrentSearch();
  }

  Future<void> selectSort(MarketplaceSortOption sort) async {
    if (state.sort == sort) return;
    state = state.copyWith(sort: sort, isSearching: true);
    await _refreshCurrentSearch();
  }

  Future<void> search(String query) async {
    final trimmed = query.trim();
    state = state.copyWith(
      query: trimmed,
      isSearching: true,
      resetImageSearch: true,
    );
    final marketplace = state.marketplace;
    final category = state.selectedCategory;
    final filter = state.filter;
    final sort = state.sort;
    final products = await _repository.search(
      ChinaMarketplaceSearchRequest(
        marketplace: marketplace,
        query: trimmed,
        category: category,
        filter: filter,
        sort: sort,
      ),
    );
    if (state.marketplace != marketplace ||
        state.query != trimmed ||
        state.selectedCategory != category ||
        state.filter != filter ||
        state.sort != sort) {
      return;
    }
    state = state.copyWith(products: products, isSearching: false);
  }

  Future<void> searchByImage({
    required String fileName,
    required Uint8List previewBytes,
  }) async {
    final normalizedFileName = fileName.trim().isEmpty
        ? 'image_search.jpg'
        : fileName.trim();
    state = state.copyWith(
      query: '',
      isSearching: true,
      isImageSearchMode: true,
      imageSearchFileName: normalizedFileName,
      imageSearchPreviewBytes: previewBytes,
    );
    await _runImageSearch(normalizedFileName, previewBytes);
  }

  Future<void> clearImageSearch() async {
    state = state.copyWith(resetImageSearch: true, isSearching: true);
    await search('');
  }

  Future<void> refreshCurrentSearch() => _refreshCurrentSearch();

  Future<void> _refreshCurrentSearch() async {
    if (state.isImageSearchMode &&
        state.imageSearchFileName != null &&
        state.imageSearchPreviewBytes != null) {
      await _runImageSearch(
        state.imageSearchFileName!,
        state.imageSearchPreviewBytes!,
      );
    } else {
      await search(state.query);
    }
  }

  Future<void> _runImageSearch(String fileName, Uint8List previewBytes) async {
    final marketplace = state.marketplace;
    final category = state.selectedCategory;
    final filter = state.filter;
    final sort = state.sort;
    final products = await _repository.searchByImage(
      ChinaMarketplaceImageSearchRequest(
        marketplace: marketplace,
        imageFileName: fileName,
        imageSizeBytes: previewBytes.length,
        category: category,
        filter: filter,
        sort: sort,
      ),
    );
    if (state.marketplace != marketplace ||
        !state.isImageSearchMode ||
        state.imageSearchFileName != fileName ||
        state.selectedCategory != category ||
        state.filter != filter ||
        state.sort != sort) {
      return;
    }
    state = state.copyWith(products: products, isSearching: false);
  }

  void addToCart(
    MarketplaceProduct product, {
    MarketplaceSkuOption? sku,
    int quantity = 1,
    String note = '',
  }) {
    final safeQuantity = quantity < product.minOrderQuantity
        ? product.minOrderQuantity
        : quantity;
    final draft = MarketplaceCartItem(
      product: product,
      sku: sku,
      quantity: safeQuantity,
      note: note.trim(),
    );
    final cart = [...state.cart];
    final index = cart.indexWhere((item) => item.key == draft.key);
    if (index >= 0) {
      final existing = cart[index];
      cart[index] = existing.copyWith(
        quantity: existing.quantity + safeQuantity,
        note: draft.note.isEmpty ? existing.note : draft.note,
      );
    } else {
      cart.add(draft);
    }
    state = state.copyWith(cart: cart);
  }

  void changeCartQuantity(String key, int quantity) {
    final cart = state.cart
        .map((item) {
          if (item.key != key) return item;
          final minQuantity = item.product.minOrderQuantity;
          return item.copyWith(
            quantity: quantity < minQuantity ? minQuantity : quantity,
          );
        })
        .toList(growable: false);
    state = state.copyWith(cart: cart);
  }

  void removeFromCart(String key) {
    state = state.copyWith(
      cart: state.cart.where((item) => item.key != key).toList(growable: false),
    );
  }

  void clearCart() {
    state = state.copyWith(cart: []);
  }
}
