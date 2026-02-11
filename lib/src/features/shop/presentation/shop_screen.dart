import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import '../../../core/ui/app_colors.dart';
import '../../shell/presentation/app_shell.dart';
import '../data/purchase_provider.dart';
import '../data/shop_provider.dart';
import '../domain/marketplace.dart';
import '../domain/shop_category.dart';
import 'shop_search_results.dart';
import 'widgets/marketplace_selector.dart';
import 'widgets/shop_search_bar.dart';

/// Sort options supported by OT API
const _sortOptions = <(String, String)>[
  ('Default', 'По умолчанию'),
  ('TotalSales:Desc', 'По продажам'),
  ('Price:Asc', 'Цена ↑'),
  ('Price:Desc', 'Цена ↓'),
  ('Volume:Desc', 'По популярности'),
];

class ShopScreen extends ConsumerStatefulWidget {
  const ShopScreen({super.key});

  @override
  ConsumerState<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends ConsumerState<ShopScreen> {
  String _searchQuery = '';
  String? _searchCategoryId;
  String? _searchCategoryName;
  String _orderBy = 'Default';
  double? _minPrice;
  double? _maxPrice;

  void _onSearch(String query) {
    setState(() {
      _searchQuery = query;
      _searchCategoryId = null;
      _searchCategoryName = null;
    });
  }

  void _onMarketplaceChanged(Marketplace mp) {
    setState(() {
      _searchCategoryId = null;
      _searchCategoryName = null;
    });
  }

  void _onCategorySearch(ShopCategory category) {
    setState(() {
      _searchQuery = '';
      _searchCategoryId = category.id;
      _searchCategoryName = category.name;
    });
  }

  void _clearCategorySearch() {
    setState(() {
      _searchCategoryId = null;
      _searchCategoryName = null;
    });
  }

  void _showFiltersSheet() {
    final minCtrl = TextEditingController(
      text: _minPrice != null ? _minPrice!.toStringAsFixed(0) : '',
    );
    final maxCtrl = TextEditingController(
      text: _maxPrice != null ? _maxPrice!.toStringAsFixed(0) : '',
    );

    ref.read(bottomNavVisibleProvider.notifier).hide();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            20 + MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Фильтр по цене (¥)',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: minCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'От',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: maxCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'До',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _minPrice = null;
                          _maxPrice = null;
                        });
                        Navigator.pop(ctx);
                      },
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Сбросить'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        setState(() {
                          final minVal = double.tryParse(minCtrl.text);
                          final maxVal = double.tryParse(maxCtrl.text);
                          _minPrice = minVal;
                          _maxPrice = maxVal;
                        });
                        Navigator.pop(ctx);
                      },
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Применить'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    ).whenComplete(() {
      ref.read(bottomNavVisibleProvider.notifier).show();
    });
  }

  @override
  Widget build(BuildContext context) {
    final marketplace = ref.watch(selectedMarketplaceProvider);

    final showSearchResults =
        _searchQuery.isNotEmpty || _searchCategoryId != null;

    final cartCount = ref.watch(cartItemCountProvider);

    return Stack(
      children: [
        Column(
          children: [
            const SizedBox(height: 60),

            // Marketplace selector
            MarketplaceSelector(onChanged: _onMarketplaceChanged),
            const SizedBox(height: 12),

            // Search bar
            ShopSearchBar(
              onSearch: _onSearch,
              initialQuery: _searchQuery.isNotEmpty ? _searchQuery : null,
            ),
            const SizedBox(height: 8),

            // Sort + Filter row (only when results are shown)
            if (showSearchResults)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    // Sort dropdown
                    Expanded(
                      child: Container(
                        height: 36,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _orderBy,
                            isExpanded: true,
                            icon: Icon(Icons.sort,
                                size: 18, color: Colors.grey.shade600),
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade800,
                            ),
                            items: _sortOptions
                                .map(
                                  (opt) => DropdownMenuItem(
                                    value: opt.$1,
                                    child: Text(opt.$2),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _orderBy = value);
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Filter button
                    GestureDetector(
                      onTap: _showFiltersSheet,
                      child: Container(
                        height: 36,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: (_minPrice != null || _maxPrice != null)
                              ? context.brandPrimary.withValues(alpha: 0.1)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(10),
                          border: (_minPrice != null || _maxPrice != null)
                              ? Border.all(color: context.brandPrimary, width: 1)
                              : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.tune,
                              size: 18,
                              color: (_minPrice != null || _maxPrice != null)
                                  ? context.brandPrimary
                                  : Colors.grey.shade600,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _buildFilterLabel(),
                              style: TextStyle(
                                fontSize: 13,
                                color: (_minPrice != null || _maxPrice != null)
                                    ? context.brandPrimary
                                    : Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            if (showSearchResults) const SizedBox(height: 8),

            // Category filter chip
            if (_searchCategoryId != null)
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
                child: Row(
                  children: [
                    Flexible(
                      child: Chip(
                        label: Text(
                          _searchCategoryName ?? 'Категория',
                          style: TextStyle(
                            fontSize: 13,
                            color: context.brandPrimary,
                          ),
                        ),
                        deleteIcon: const Icon(Icons.close, size: 16),
                        onDeleted: _clearCategorySearch,
                        backgroundColor:
                            context.brandPrimary.withValues(alpha: 0.1),
                        side: BorderSide.none,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Content
            Expanded(
              child: showSearchResults
                  ? ShopSearchResults(
                      params: ShopSearchParams(
                        query: _searchQuery,
                        marketplace: marketplace,
                        categoryId: _searchCategoryId,
                        orderBy: _orderBy,
                        minPrice: _minPrice,
                        maxPrice: _maxPrice,
                      ),
                    )
                  : _CategoriesView(
                      marketplace: marketplace,
                      onCategorySearch: _onCategorySearch,
                    ),
            ),
          ],
        ),

        // Floating history button
        Positioned(
          right: 16,
          bottom: cartCount > 0 ? 181 : 115,
          child: GestureDetector(
            onTap: () => context.push('/shop/purchases'),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                Icons.receipt_long_rounded,
                color: context.brandPrimary,
                size: 22,
              ),
            ),
          ),
        ),

        // Floating cart button
        if (cartCount > 0)
          Positioned(
            right: 16,
            bottom: 115,
            child: GestureDetector(
              onTap: () => context.push('/shop/cart'),
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [context.brandPrimary, context.brandSecondary],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: context.brandPrimary.withValues(alpha: 0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Icon(
                      Icons.shopping_cart_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),
                        child: Text(
                          '$cartCount',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  String _buildFilterLabel() {
    if (_minPrice != null && _maxPrice != null) {
      return '¥${_minPrice!.toStringAsFixed(0)}–${_maxPrice!.toStringAsFixed(0)}';
    }
    if (_minPrice != null) {
      return 'от ¥${_minPrice!.toStringAsFixed(0)}';
    }
    if (_maxPrice != null) {
      return 'до ¥${_maxPrice!.toStringAsFixed(0)}';
    }
    return 'Цена';
  }
}

class _CategoriesView extends ConsumerStatefulWidget {
  final Marketplace marketplace;
  final ValueChanged<ShopCategory> onCategorySearch;

  const _CategoriesView({
    required this.marketplace,
    required this.onCategorySearch,
  });

  @override
  ConsumerState<_CategoriesView> createState() => _CategoriesViewState();
}

class _CategoriesViewState extends ConsumerState<_CategoriesView> {
  /// Stack of (parentId, title) — for navigation breadcrumbs
  final List<({String? parentId, String title})> _stack = [];

  String? get _currentParentId =>
      _stack.isNotEmpty ? _stack.last.parentId : null;

  @override
  void didUpdateWidget(_CategoriesView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.marketplace != widget.marketplace) {
      _stack.clear();
    }
  }

  void _onCategoryTap(ShopCategory cat) {
    if (cat.isParent) {
      setState(() {
        _stack.add((parentId: cat.id, title: cat.name));
      });
    } else {
      // Leaf category — search by categoryId
      widget.onCategorySearch(cat);
    }
  }

  void _goBack() {
    if (_stack.isNotEmpty) {
      setState(() {
        _stack.removeLast();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final params = ShopCategoryParams(
      marketplace: widget.marketplace,
      parentId: _currentParentId,
    );
    final categoriesAsync = ref.watch(shopCategoriesProvider(params));

    return Column(
      children: [
        // Back button + breadcrumb
        if (_stack.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                GestureDetector(
                  onTap: _goBack,
                  child: Row(
                    children: [
                      Icon(CupertinoIcons.chevron_left,
                          size: 18, color: context.brandPrimary),
                      const SizedBox(width: 4),
                      Text(
                        _stack.last.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: context.brandPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // "Show items" button for parent categories
                GestureDetector(
                  onTap: () {
                    // Search items in current parent category
                    final cat = ShopCategory(
                      id: _currentParentId!,
                      name: _stack.last.title,
                      isParent: true,
                    );
                    widget.onCategorySearch(cat);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: context.brandPrimary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.grid_view,
                            size: 14, color: context.brandPrimary),
                        const SizedBox(width: 4),
                        Text(
                          'Товары',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: context.brandPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

        if (_stack.isNotEmpty) const SizedBox(height: 8),

        // List
        Expanded(
          child: categoriesAsync.when(
            data: (categories) {
              if (categories.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.category_outlined,
                          size: 56, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Text(
                        'Введите запрос для поиска товаров',
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final cat = categories[index];
                  return _CategoryTile(
                    category: cat,
                    onTap: () => _onCategoryTap(cat),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline,
                      size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  Text(
                    'Не удалось загрузить категории',
                    style:
                        TextStyle(fontSize: 15, color: Colors.grey.shade500),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () =>
                        ref.invalidate(shopCategoriesProvider(params)),
                    child: const Text('Повторить'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final ShopCategory category;
  final VoidCallback onTap;

  const _CategoryTile({required this.category, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: Text(
          category.name,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
        trailing: category.isParent
            ? Icon(Icons.chevron_right, color: Colors.grey.shade400)
            : Icon(Icons.search, size: 20, color: Colors.grey.shade400),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        onTap: onTap,
      ),
    );
  }
}
