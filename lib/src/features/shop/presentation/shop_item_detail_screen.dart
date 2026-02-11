import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/ui/app_colors.dart';
import '../../../core/ui/app_layout.dart';
import '../data/purchase_provider.dart';
import '../data/shop_provider.dart';
import '../domain/purchase_list.dart' show SkuProperty;
import '../domain/shop_item_detail.dart';

class ShopItemDetailScreen extends ConsumerStatefulWidget {
  final String itemId;

  const ShopItemDetailScreen({super.key, required this.itemId});

  @override
  ConsumerState<ShopItemDetailScreen> createState() =>
      _ShopItemDetailScreenState();
}

class _ShopItemDetailScreenState extends ConsumerState<ShopItemDetailScreen> {
  int _currentImageIndex = 0;
  // pid -> vid
  final Map<String, String> _selectedConfigs = {};
  bool _initialized = false;
  int _quantity = 1;
  bool _isAddingToList = false;

  void _initDefaults(ShopItemDetail item) {
    if (_initialized) return;
    _initialized = true;

    // Select first option for each configurator group
    for (final entry in item.configuratorGroups.entries) {
      if (entry.value.isNotEmpty) {
        final first = entry.value.first;
        _selectedConfigs[first.pid] = first.vid;
      }
    }
  }

  ConfiguredItem? _getSelectedConfiguredItem(ShopItemDetail item) {
    return item.findConfiguredItem(_selectedConfigs);
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(shopItemDetailProvider(widget.itemId));

    return detailAsync.when(
      data: (item) {
        if (item == null) {
          return const Center(child: Text('Товар не найден'));
        }
        _initDefaults(item);
        return Stack(
          children: [
            _buildContent(context, item),
            _buildBottomBar(context, item),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
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
              onPressed: () =>
                  ref.invalidate(shopItemDetailProvider(widget.itemId)),
              child: const Text('Повторить'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, ShopItemDetail item) {
    final selectedSku = _getSelectedConfiguredItem(item);
    final displayPrice = selectedSku?.priceDisplay ?? item.priceDisplay;
    final strippedDescription = _stripHtml(item.description);
    final isPoizon = item.provider.toLowerCase() == 'poizon';
    final topPad = AppLayout.topBarTotalHeight(context);
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return ListView(
      padding: EdgeInsets.fromLTRB(0, topPad * 0.7 + 6, 0, 100 + bottomPad),
      children: [
        // Page title (like other screens)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Text(
            item.title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
        ),

        // 1. Image carousel
        _buildImageCarousel(context, item),

        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Original title (if different)
              if (item.originalTitle.isNotEmpty &&
                  item.originalTitle != item.title) ...[
                Text(
                  item.originalTitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade500,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // 3. Configurator (variations)
              if (item.configuratorGroups.isNotEmpty)
                ...item.configuratorGroups.entries.map(
                  (entry) => _buildConfigSection(
                    context,
                    entry.key,
                    entry.value,
                  ),
                ),

              // 4. Price (of selected SKU)
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    displayPrice,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: context.brandPrimary,
                    ),
                  ),
                  if (selectedSku != null && selectedSku.quantity > 0) ...[
                    const SizedBox(width: 12),
                    Text(
                      'В наличии: ${selectedSku.quantity} шт.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ],
              ),

              // 5 & 6. Sales + Vendor rating / Volume
              const SizedBox(height: 16),
              _buildRatingsBlock(context, item),

              // 7. Info attributes (characteristics)
              if (item.infoAttributes.isNotEmpty) ...[
                const SizedBox(height: 24),
                _buildDivider(),
                const SizedBox(height: 16),
                const Text(
                  'Характеристики',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                ...item.infoAttributes.map(_buildAttributeRow),
              ],

              // Description — hide for Poizon (always empty)
              if (!isPoizon && strippedDescription.isNotEmpty) ...[
                const SizedBox(height: 24),
                _buildDivider(),
                const SizedBox(height: 16),
                const Text(
                  'Описание',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  strippedDescription,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                    height: 1.5,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar(BuildContext context, ShopItemDetail item) {
    final selectedSku = _getSelectedConfiguredItem(item);
    final displayPrice = selectedSku?.priceDisplay ?? item.priceDisplay;
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottomPad),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Price
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    displayPrice,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: context.brandPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  // Quantity selector
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: _quantity > 1
                            ? () => setState(() => _quantity--)
                            : null,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: _quantity > 1
                                ? Colors.grey.shade200
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.remove,
                            size: 16,
                            color: _quantity > 1
                                ? AppColors.textPrimary
                                : Colors.grey.shade400,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          '$_quantity',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setState(() => _quantity++),
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.add,
                            size: 16,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Add to list button
            FilledButton.icon(
              onPressed: _isAddingToList ? null : () => _addToList(item),
              icon: _isAddingToList
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.add_shopping_cart, size: 20),
              label: Text(
                _isAddingToList ? 'Добавляем...' : 'В список выкупа',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: FilledButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addToList(ShopItemDetail item) async {
    if (_isAddingToList) return;

    setState(() => _isAddingToList = true);

    try {
      final apiClient = ref.read(apiClientProvider);

      // 1. Get or create draft list
      int listId;
      final activeList = ref.read(activePurchaseListProvider).value;
      if (activeList != null) {
        listId = activeList.id;
      } else {
        final createResp = await apiClient.post('/shop/purchase-lists');
        if (createResp.statusCode != 200 || createResp.data == null) {
          throw Exception('Failed to create purchase list');
        }
        final data = createResp.data as Map<String, dynamic>;
        listId = (data['list'] as Map<String, dynamic>)['id'] as int;
      }

      // 2. Build sku properties from selected configurators
      final skuProps = <Map<String, String>>[];
      for (final entry in item.configuratorGroups.entries) {
        for (final attr in entry.value) {
          if (_selectedConfigs[attr.pid] == attr.vid) {
            skuProps.add(
                SkuProperty(name: entry.key, value: attr.value).toJson().map(
                      (k, v) => MapEntry(k, v.toString()),
                    ));
          }
        }
      }

      final selectedSku = _getSelectedConfiguredItem(item);

      // 3. Add item
      await apiClient.post('/shop/purchase-lists/$listId/items', data: {
        'externalItemId': item.id,
        'provider': item.provider,
        'title': item.title,
        'imageUrl': item.mainImage,
        'price': selectedSku?.price ?? item.price,
        'currency': item.currency,
        'quantity': _quantity,
        'skuId': selectedSku?.id,
        'skuProperties': skuProps,
        'externalUrl': item.externalUrl,
      });

      // 4. Refresh providers
      ref.invalidate(activePurchaseListProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Добавлено в список выкупа'),
            backgroundColor: context.brandPrimary,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isAddingToList = false);
      }
    }
  }

  Widget _buildImageCarousel(BuildContext context, ShopItemDetail item) {
    final images = item.images.isNotEmpty
        ? item.images.map((img) => img.url).toList()
        : (item.mainImage.isNotEmpty ? [item.mainImage] : <String>[]);

    if (images.isEmpty) {
      return Container(
        height: 300,
        color: Colors.grey.shade100,
        child: Center(
          child: Icon(Icons.image_outlined, size: 64, color: Colors.grey.shade300),
        ),
      );
    }

    return SizedBox(
      height: 360,
      child: Stack(
        children: [
          PageView.builder(
            itemCount: images.length,
            onPageChanged: (index) {
              setState(() => _currentImageIndex = index);
            },
            itemBuilder: (context, index) {
              return CachedNetworkImage(
                imageUrl: images[index],
                fit: BoxFit.contain,
                placeholder: (_, _) => Container(
                  color: Colors.grey.shade50,
                  child: const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                errorWidget: (_, _, _) => Container(
                  color: Colors.grey.shade50,
                  child: const Icon(Icons.broken_image, size: 48),
                ),
              );
            },
          ),
          // Counter
          if (images.length > 1)
            Positioned(
              bottom: 12,
              right: 16,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_currentImageIndex + 1}/${images.length}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          // Dots
          if (images.length > 1 && images.length <= 10)
            Positioned(
              bottom: 12,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  images.length,
                  (i) => Container(
                    width: i == _currentImageIndex ? 20 : 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: i == _currentImageIndex
                          ? context.brandPrimary
                          : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRatingsBlock(BuildContext context, ShopItemDetail item) {
    final isPoizon = item.provider.toLowerCase() == 'poizon';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Sales
          if (item.totalSales != null && item.totalSales! > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(Icons.shopping_bag_outlined,
                      size: 18, color: context.brandPrimary),
                  const SizedBox(width: 8),
                  Text(
                    '${item.totalSales} продаж',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),

          // Volume (purchase count) — shown for Poizon if no totalSales
          if (isPoizon &&
              (item.totalSales == null || item.totalSales == 0) &&
              item.volume != null &&
              item.volume! > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(Icons.shopping_bag_outlined,
                      size: 18, color: context.brandPrimary),
                  const SizedBox(width: 8),
                  Text(
                    '${item.volume} покупок',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),

          // Vendor
          if (item.vendorName.isNotEmpty)
            Row(
              children: [
                Icon(CupertinoIcons.building_2_fill,
                    size: 18, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.vendorName,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
                if (item.vendorScore != null && item.vendorScore! > 0) ...[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star_rounded,
                            size: 15, color: Colors.amber.shade700),
                        const SizedBox(width: 3),
                        Text(
                          '${item.vendorScore}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.amber.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildConfigSection(
    BuildContext context,
    String propertyName,
    List<ItemAttribute> options,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            propertyName,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options.map((attr) {
              final isSelected = _selectedConfigs[attr.pid] == attr.vid;
              final hasImage = attr.imageUrl.isNotEmpty;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedConfigs[attr.pid] = attr.vid;
                  });
                },
                child: Container(
                  constraints: const BoxConstraints(minWidth: 44),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? context.brandPrimary.withValues(alpha: 0.1)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected
                          ? context.brandPrimary
                          : Colors.grey.shade300,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (hasImage) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: CachedNetworkImage(
                            imageUrl: attr.imageUrl,
                            width: 28,
                            height: 28,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Flexible(
                        child: Text(
                          attr.value,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight:
                                isSelected ? FontWeight.w600 : FontWeight.w400,
                            color: isSelected
                                ? context.brandPrimary
                                : AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAttributeRow(ItemAttribute attr) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              attr.propertyName,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              attr.value,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(color: Colors.grey.shade200, height: 1);
  }

  /// Strip HTML tags for plain text display
  static String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<br\s*/?>'), '\n')
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .trim();
  }
}
