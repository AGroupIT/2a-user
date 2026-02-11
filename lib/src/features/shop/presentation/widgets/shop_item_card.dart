import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/ui/app_colors.dart';
import '../../domain/shop_item.dart';

class ShopItemCard extends StatelessWidget {
  final ShopItem item;
  final VoidCallback? onTap;

  const ShopItemCard({super.key, required this.item, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            AspectRatio(
              aspectRatio: 1,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  item.mainImage.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: item.mainImage,
                          fit: BoxFit.cover,
                          placeholder: (_, _) => Container(
                            color: Colors.grey.shade100,
                            child: const Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          ),
                          errorWidget: (_, _, _) => Container(
                            color: Colors.grey.shade100,
                            child: Icon(
                              Icons.image_not_supported_outlined,
                              color: Colors.grey.shade400,
                              size: 32,
                            ),
                          ),
                        )
                      : Container(
                          color: Colors.grey.shade100,
                          child: Icon(
                            Icons.image_outlined,
                            color: Colors.grey.shade400,
                            size: 32,
                          ),
                        ),
                  // Image count badge
                  if (item.images.length > 1)
                    Positioned(
                      right: 6,
                      bottom: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.photo_library,
                                size: 12, color: Colors.white),
                            const SizedBox(width: 3),
                            Text(
                              '${item.images.length}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Info
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Price
                  Text(
                    item.priceDisplay,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: context.brandPrimary,
                    ),
                  ),

                  // Quantity / Sales row
                  if (item.quantity != null || item.totalSales != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (item.quantity != null) ...[
                          Icon(Icons.inventory_2_outlined,
                              size: 12, color: Colors.grey.shade500),
                          const SizedBox(width: 3),
                          Text(
                            '${item.quantity}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                        if (item.quantity != null && item.totalSales != null)
                          const SizedBox(width: 8),
                        if (item.totalSales != null &&
                            item.totalSales! > 0) ...[
                          Icon(Icons.shopping_bag_outlined,
                              size: 12, color: Colors.grey.shade500),
                          const SizedBox(width: 3),
                          Text(
                            '${item.totalSales} продаж',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],

                  // Vendor + score
                  if (item.vendorName.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.vendorName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                        if (item.vendorScore != null &&
                            item.vendorScore! > 0) ...[
                          const SizedBox(width: 4),
                          Icon(Icons.star_rounded,
                              size: 13, color: Colors.amber.shade600),
                          const SizedBox(width: 1),
                          Text(
                            '${item.vendorScore}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.amber.shade700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
