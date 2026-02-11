import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/shop_provider.dart';
import '../domain/shop_item.dart';
import 'widgets/shop_item_card.dart';

class ShopSearchResults extends ConsumerStatefulWidget {
  final ShopSearchParams params;

  const ShopSearchResults({super.key, required this.params});

  @override
  ConsumerState<ShopSearchResults> createState() => _ShopSearchResultsState();
}

class _ShopSearchResultsState extends ConsumerState<ShopSearchResults> {
  final List<ShopItem> _allItems = [];
  int _currentPage = 0;
  int _total = 0;
  bool _isLoadingMore = false;

  /// The base params (without page) — used to detect when search changes
  ShopSearchParams get _baseParams => widget.params.copyWith(page: 0);

  ShopSearchParams? _lastBaseParams;

  @override
  void initState() {
    super.initState();
    _lastBaseParams = _baseParams;
  }

  @override
  void didUpdateWidget(ShopSearchResults oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If base search params changed (query, marketplace, filters, sort) — reset
    if (_lastBaseParams != _baseParams) {
      _lastBaseParams = _baseParams;
      _allItems.clear();
      _currentPage = 0;
      _total = 0;
      _isLoadingMore = false;

    }
  }

  void _onPageLoaded(ShopSearchResult result, int page) {
    if (!mounted) return;
    // Avoid duplicates: only add if this page's items aren't already in the list
    final expectedStart = page * (widget.params.pageSize);
    if (_allItems.length <= expectedStart) {
      _allItems.addAll(result.items);
    }
    _total = result.total;
    _currentPage = page;
    _isLoadingMore = false;
  }

  void _loadNextPage() {
    if (_isLoadingMore) return;
    if (_allItems.length >= _total) return;
    setState(() {
      _isLoadingMore = true;
      _currentPage++;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Always watch the current page
    final params = widget.params.copyWith(page: _currentPage);
    final searchAsync = ref.watch(shopSearchProvider(params));

    return searchAsync.when(
      data: (result) {
        _onPageLoaded(result, _currentPage);

        if (_allItems.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.search_off, size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text(
                  'Ничего не найдено',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Попробуйте изменить запрос',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade400),
                ),
              ],
            ),
          );
        }

        final hasMore = _allItems.length < _total;

        return NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification is ScrollEndNotification &&
                notification.metrics.extentAfter < 300 &&
                hasMore &&
                !_isLoadingMore) {
              _loadNextPage();
            }
            return false;
          },
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.54,
            ),
            itemCount: _allItems.length + (hasMore ? 2 : 0),
            itemBuilder: (context, index) {
              if (index >= _allItems.length) {
                // Loading indicator at the bottom
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              }
              final item = _allItems[index];
              return ShopItemCard(
                item: item,
                onTap: () {
                  context.push('/shop/item/${item.id}');
                },
              );
            },
          ),
        );
      },
      loading: () {
        if (_allItems.isNotEmpty) {
          // Already have items, show them + loading at bottom
          final hasMore = _allItems.length < _total;
          return NotificationListener<ScrollNotification>(
            onNotification: (notification) => false,
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.54,
              ),
              itemCount: _allItems.length + (hasMore ? 2 : 0),
              itemBuilder: (context, index) {
                if (index >= _allItems.length) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                }
                final item = _allItems[index];
                return ShopItemCard(
                  item: item,
                  onTap: () {
                    context.push('/shop/item/${item.id}');
                  },
                );
              },
            ),
          );
        }
        return const Center(child: CircularProgressIndicator());
      },
      error: (error, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              'Ошибка загрузки',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                ref.invalidate(shopSearchProvider(params));
              },
              child: const Text('Повторить'),
            ),
          ],
        ),
      ),
    );
  }
}
